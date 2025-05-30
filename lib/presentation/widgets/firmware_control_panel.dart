import 'dart:io';

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
    final logBloc = context.read<LogBloc>();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ino', 'cpp'],
        allowMultiple: false,
        dialogTitle: 'Chọn file firmware',
      );

      if (!context.mounted) return;

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        logBloc.add(SelectLocalFileEvent(filePath));
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
      logBloc.add(AddLogEvent(LogEntry(
        message: 'Error picking file: $e',
        timestamp: DateTime.now(),
        level: LogLevel.error,
        step: ProcessStep.firmwareDownload,
        origin: 'system',
      )));
    }
  }

  void _clearLocalFile(BuildContext context) {
    context.read<LogBloc>().add(ClearLocalFileEvent()); // Xóa file cục bộ
    onFirmwareVersionSelected(null); // Reset phiên bản firmware
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LogBloc, LogState>(
      builder: (context, state) {
        final hasLocalFile = state.localFilePath != null;
        final fileName = state.localFilePath != null
            ? state.localFilePath!.split(Platform.pathSeparator).last
            : '';

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Row 1: Phiên bản Firmware
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
                          onChanged: hasLocalFile ? null : onFirmwareVersionSelected, // Vô hiệu hóa nếu có file cục bộ
                          hint: const Text('-- Chọn phiên bản --'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.list, size: 20),
                      label: const Text('Select Version'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.connected,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onPressed: () => _clearLocalFile(context), // Xóa file cục bộ, enable dropdown
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Row 2: Local Firmware File
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Local Firmware File',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          readOnly: true,
                          controller: TextEditingController(
                              text: hasLocalFile ? fileName : 'No file selected'),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            fillColor:
                                isDarkTheme
                                    ? AppColors.idle
                                    : AppColors.cardBackground,
                            filled: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.search, size: 20),
                      label: const Text('Find in File'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.connected,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onPressed: () => _handleFilePick(context),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Row 3: Serial Number
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
                          onSubmitted: onSerialSubmitted, // Gửi serial number từ TextField
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
                      onPressed: onQrCodeScan, // Gửi serial number từ QR code
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Row 4: Cổng COM (USB)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cổng COM (USB)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: selectedPort,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            fillColor:
                                isDarkTheme
                                    ? AppColors.idle
                                    : AppColors.cardBackground,
                            filled: true,
                          ),
                          items:
                              availablePorts
                                  .map(
                                    (port) => DropdownMenuItem(
                                      value: port,
                                      child: Text(port),
                                    ),
                                  )
                                  .toList(),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onPressed: onUsbPortRefresh,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}