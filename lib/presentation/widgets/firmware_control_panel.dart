import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:esp_firmware_tool/data/models/log_entry.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';
import 'package:esp_firmware_tool/presentation/widgets/warning_dialog.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';

class FirmwareControlPanel extends StatefulWidget {
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

  @override
  State<FirmwareControlPanel> createState() => _FirmwareControlPanelState();
}

class _FirmwareControlPanelState extends State<FirmwareControlPanel> {
  bool _isVersionButtonLoading = false;
  bool _isFileButtonLoading = false;
  bool _isQrCodeButtonLoading = false;
  bool _isRefreshButtonLoading = false;

  void _handleFilePick(BuildContext context) async {
    final logBloc = context.read<LogBloc>();

    setState(() {
      _isFileButtonLoading = true;
    });

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
          message: 'Không có file nào được chọn',
          timestamp: DateTime.now(),
          level: LogLevel.warning,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        )));
      }
    } catch (e) {
      if (mounted) {
        logBloc.add(AddLogEvent(LogEntry(
          message: 'Lỗi khi chọn file: $e',
          timestamp: DateTime.now(),
          level: LogLevel.error,
          step: ProcessStep.firmwareDownload,
          origin: 'system',
        )));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFileButtonLoading = false;
        });
      }
    }
  }

  void _clearLocalFile(BuildContext context) async {
    setState(() {
      _isVersionButtonLoading = true;
    });

    try {
      context.read<LogBloc>().add(ClearLocalFileEvent());
      widget.onFirmwareVersionSelected(null);
    } finally {
      if (mounted) {
        setState(() {
          _isVersionButtonLoading = false;
        });
      }
    }
  }

  void _handleQrScan() async {
    setState(() {
      _isQrCodeButtonLoading = true;
    });

    try {
      widget.onQrCodeScan();
    } finally {
      if (mounted) {
        setState(() {
          _isQrCodeButtonLoading = false;
        });
        // Giả lập delay để người dùng thấy hiệu ứng loading
        Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  void _handleRefreshPorts() async {
    setState(() {
      _isRefreshButtonLoading = true;
    });

    try {
      widget.onUsbPortRefresh();
    } finally {
      if (mounted) {
        // Giả lập delay để hiệu ứng loading hiển thị đủ lâu
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() {
          _isRefreshButtonLoading = false;
        });
      }
    }
  }

  Widget _buildLoadingButton({
    required bool isLoading,
    required VoidCallback onPressed,
    required String text,
    required IconData icon,
    required Color backgroundColor,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        icon: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(icon, size: 20),
        label: Text(isLoading ? 'Đang xử lý...' : text),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onPressed: isLoading ? null : onPressed,
      ),
    );
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
              // Hàng 1: Phiên bản Firmware
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
                          value: widget.selectedFirmwareVersion,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            fillColor: widget.isDarkTheme ? AppColors.idle : AppColors.cardBackground,
                            filled: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'v1.0.0', child: Text('v1.0.0')),
                            DropdownMenuItem(value: 'v1.1.0', child: Text('v1.1.0')),
                            DropdownMenuItem(value: 'v2.0.0-beta', child: Text('v2.0.0-beta')),
                          ],
                          onChanged: hasLocalFile ? null : widget.onFirmwareVersionSelected,
                          hint: const Text('-- Chọn phiên bản --'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildLoadingButton(
                    isLoading: _isVersionButtonLoading,
                    onPressed: () => _clearLocalFile(context),
                    text: 'Chọn Phiên Bản',
                    icon: Icons.list,
                    backgroundColor: AppColors.selectVersion,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Hàng 2: File Firmware Cục Bộ
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'File Firmware Cục Bộ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          readOnly: true,
                          controller: TextEditingController(
                              text: hasLocalFile ? fileName : 'Chưa chọn file'),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            fillColor:
                                widget.isDarkTheme
                                    ? AppColors.idle
                                    : AppColors.cardBackground,
                            filled: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildLoadingButton(
                    isLoading: _isFileButtonLoading,
                    onPressed: () => _handleFilePick(context),
                    text: 'Tìm File',
                    icon: Icons.search,
                    backgroundColor: AppColors.findFile,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Hàng 3: Số Serial
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Số Serial', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: widget.serialController,
                          decoration: InputDecoration(
                            hintText: 'Nhập hoặc quét mã serial',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            fillColor: widget.isDarkTheme ? AppColors.idle : AppColors.cardBackground,
                            filled: true,
                          ),
                          onSubmitted: widget.onSerialSubmitted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildLoadingButton(
                    isLoading: _isQrCodeButtonLoading,
                    onPressed: _handleQrScan,
                    text: 'Quét QR',
                    icon: Icons.qr_code,
                    backgroundColor: AppColors.scanQr,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Hàng 4: Cổng COM (USB)
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
                          value: widget.selectedPort,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            fillColor:
                                widget.isDarkTheme
                                    ? AppColors.idle
                                    : AppColors.cardBackground,
                            filled: true,
                          ),
                          items:
                              widget.availablePorts
                                  .map(
                                    (port) => DropdownMenuItem(
                                      value: port,
                                      child: Text(port),
                                    ),
                                  )
                                  .toList(),
                          onChanged: widget.onUsbPortSelected,
                          hint: const Text('-- Chọn cổng --'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildLoadingButton(
                    isLoading: _isRefreshButtonLoading,
                    onPressed: _handleRefreshPorts,
                    text: 'Làm Mới',
                    icon: Icons.refresh,
                    backgroundColor: AppColors.refresh,
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