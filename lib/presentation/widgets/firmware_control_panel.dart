import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:esp_firmware_tool/data/models/log_entry.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';
import 'package:esp_firmware_tool/presentation/widgets/warning_dialog.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';

class FirmwareControlPanel extends StatelessWidget {
  final bool isDarkTheme;
  final String? selectedFirmwareVersion;
  final String? selectedPort;
  final TextEditingController serialController;
  final Function(String?) onFirmwareVersionSelected;
  final Function(String?) onUsbPortSelected;
  final VoidCallback onLocalFileSearch;
  final VoidCallback onUsbPortRefresh;
  final Function(String) onSerialSubmitted;
  final VoidCallback onQrCodeScan;
  final List<String> availablePorts;

  const FirmwareControlPanel({
    super.key,
    required this.isDarkTheme,
    required this.selectedFirmwareVersion,
    required this.selectedPort,
    required this.serialController,
    required this.onFirmwareVersionSelected,
    required this.onUsbPortSelected,
    required this.onLocalFileSearch,
    required this.onUsbPortRefresh,
    required this.onSerialSubmitted,
    required this.onQrCodeScan,
    required this.availablePorts,
  });

  void _handleFilePick(BuildContext context) async {
    final logBloc = context.read<LogBloc>(); // Lưu tham chiếu đến LogBloc
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ino', 'cpp'],
      );

      if (!context.mounted) return; // Kiểm tra widget còn tồn tại

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final extension = filePath.split('.').last.toLowerCase();

        if (extension == 'ino' || extension == 'cpp') {
          logBloc.add(SelectLocalFileEvent(filePath));
        } else {
          logBloc.add(AddLogEvent(LogEntry(
            message: 'Invalid file type. Only .ino or .cpp allowed',
            timestamp: DateTime.now(),
            level: LogLevel.error,
            step: ProcessStep.firmwareDownload,
            origin: 'system',
          )));
        }
      } else {
        logBloc.add(AddLogEvent(LogEntry(
          message: 'No file selected',
          timestamp: DateTime.now(),
          level: LogLevel.warning,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        )));
      }
    } catch (e) {
      if (!context.mounted) return; // Kiểm tra widget còn tồn tại
      logBloc.add(AddLogEvent(LogEntry(
        message: 'Error picking file: $e',
        timestamp: DateTime.now(),
        level: LogLevel.error,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      )));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Phiên bản Firmware', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: selectedFirmwareVersion,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        fillColor: isDarkTheme ? AppColors.idle : AppColors.cardBackground,
                        filled: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'v1.0.0', child: Text('v1.0.0')),
                        DropdownMenuItem(value: 'v1.1.0', child: Text('v1.1.0')),
                        DropdownMenuItem(value: 'v2.0.0-beta', child: Text('v2.0.0-beta')),
                      ],
                      onChanged: onFirmwareVersionSelected,
                      hint: const Text('-- Chọn phiên bản --'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.search, size: 20),
                  label: const Text('Find in file'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.connected,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => WarningDialog(
                        isDarkTheme: isDarkTheme,
                        title: 'Cảnh báo',
                        message: 'Tính năng chọn file local có thể gây ra lỗi không mong muốn. Bạn có chắc chắn muốn tiếp tục?',
                        onCancel: () => Navigator.pop(context),
                        onContinue: () {
                          Navigator.pop(context);
                          _handleFilePick(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Serial Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: serialController,
                      decoration: InputDecoration(
                        hintText: 'Nhập hoặc quét mã serial',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        fillColor: isDarkTheme ? AppColors.idle : AppColors.cardBackground,
                        filled: true,
                      ),
                      onSubmitted: onSerialSubmitted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code, size: 16),
                  label: const Text('Quét QR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.connected,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: onQrCodeScan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cổng COM (USB)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: selectedPort,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        fillColor: isDarkTheme ? AppColors.idle : AppColors.cardBackground,
                        filled: true,
                      ),
                      items: availablePorts.map((port) => DropdownMenuItem(
                        value: port,
                        child: Text(port),
                      )).toList(),
                      onChanged: onUsbPortSelected,
                      hint: const Text('-- Chọn cổng --'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.connected,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  onPressed: onUsbPortRefresh,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}