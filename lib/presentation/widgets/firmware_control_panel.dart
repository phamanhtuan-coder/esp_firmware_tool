import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/presentation/blocs/log/log_bloc.dart';
import 'package:smart_net_firmware_loader/utils/app_colors.dart';

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

  // Add validation state variables
  String? _serialErrorText;
  String? _serialSuccessText;
  bool _isSerialValid = false;

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
        logBloc.add(
          AddLogEvent(
            LogEntry(
              message: 'Không có file nào được chọn',
              timestamp: DateTime.now(),
              level: LogLevel.warning,
              step: ProcessStep.firmwareDownload,
              origin: 'system',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        logBloc.add(
          AddLogEvent(
            LogEntry(
              message: 'Lỗi khi chọn file: $e',
              timestamp: DateTime.now(),
              level: LogLevel.error,
              step: ProcessStep.firmwareDownload,
              origin: 'system',
            ),
          ),
        );
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
      // Clear any existing validation messages
      _serialErrorText = null;
      _serialSuccessText = null;
    });

    try {
      // Store previous value to check if it changed
      final previousValue = widget.serialController.text;
      widget.onQrCodeScan();

      // After onQrCodeScan completes, check if serial value changed
      // and validate the new value
      final newValue = widget.serialController.text;
      if (newValue != previousValue) {
        // Check if the scanned serial exists in the batch using BLoC state
        final state = context.read<LogBloc>().state;
        final deviceExists = state.devices.any(
          (device) =>
              device.serial == newValue &&
              (state.selectedBatchId == null ||
                  device.batchId.toString() == state.selectedBatchId),
        );

        setState(() {
          if (deviceExists) {
            _serialSuccessText = 'Serial hợp lệ: $newValue';
            _serialErrorText = null;
            _isSerialValid = true;
          } else {
            _serialErrorText = 'Serial không tồn tại trong lô hiện tại';
            _serialSuccessText = null;
            _isSerialValid = false;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isQrCodeButtonLoading = false;
        });
      }
    }
  }

  // New method to validate serial input on change
  void _validateSerial(String value) {
    if (value.isEmpty) {
      setState(() {
        _serialErrorText = 'Số serial không được để trống';
        _serialSuccessText = null;
        _isSerialValid = false;
      });
      return;
    }

    // Check if serial exists in current batch
    final state = context.read<LogBloc>().state;
    final deviceExists = state.devices.any(
      (device) =>
          device.serial == value &&
          (state.selectedBatchId == null ||
              device.batchId.toString() == state.selectedBatchId),
    );

    setState(() {
      if (deviceExists) {
        _serialSuccessText = 'Serial hợp lệ';
        _serialErrorText = null;
        _isSerialValid = true;
      } else {
        _serialErrorText = 'Serial không tồn tại trong lô hiện tại';
        _serialSuccessText = null;
        _isSerialValid = false;
      }
    });
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
        icon:
            isLoading
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
        final fileName =
            state.localFilePath != null
                ? state.localFilePath!.split(Platform.pathSeparator).last
                : '';

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Hàng 1: Phiên bản Firmware
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Phiên bản Firmware',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: widget.selectedFirmwareVersion,
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
                                    ? hasLocalFile
                                        ? AppColors.darkCardBackground
                                            .withOpacity(
                                              0.5,
                                            ) // Dimmed when disabled
                                        : AppColors.darkCardBackground
                                    : hasLocalFile
                                    ? AppColors.cardBackground.withOpacity(
                                      0.5,
                                    ) // Dimmed when disabled
                                    : AppColors.cardBackground,
                            filled: true,
                            enabled:
                                !hasLocalFile, // Disable when local file is selected
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: '1.0.0',
                              child: Text('1.0.0'),
                            ),
                            DropdownMenuItem(
                              value: '1.1.0',
                              child: Text('1.1.0'),
                            ),
                            DropdownMenuItem(
                              value: '2.0.0',
                              child: Text('2.0.0'),
                            ),
                          ],
                          onChanged:
                              hasLocalFile
                                  ? null
                                  : widget.onFirmwareVersionSelected,
                          hint: Text(
                            hasLocalFile
                                ? 'Không khả dụng khi chọn file local'
                                : '-- Chọn phiên bản --',
                          ),
                        ),
                        // Error message if neither firmware version nor local file is selected
                        if (!hasLocalFile &&
                            widget.selectedFirmwareVersion == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Cần chọn phiên bản firmware hoặc file local',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      // Height of label + some spacing
                      _buildLoadingButton(
                        isLoading: _isVersionButtonLoading,
                        onPressed: () => _clearLocalFile(context),
                        text: 'Chọn Phiên Bản',
                        icon: Icons.list,
                        backgroundColor: AppColors.selectVersion,
                      ),
                    ],
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
                            text: hasLocalFile ? fileName : 'Chưa chọn file',
                          ),
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
                                    ? AppColors.darkCardBackground
                                    : AppColors.cardBackground,
                            filled: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    // Add top padding to align with input field
                    child: _buildLoadingButton(
                      isLoading: _isFileButtonLoading,
                      onPressed: widget.onLocalFileSearch,
                      // Call onLocalFileSearch to show warning dialog first
                      text: 'Tìm File',
                      icon: Icons.search,
                      backgroundColor: AppColors.findFile,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Hàng 3: Số Serial
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Số Serial',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: widget.serialController,
                          decoration: InputDecoration(
                            hintText: 'Nhập hoặc quét mã serial',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color:
                                    _serialErrorText != null
                                        ? Colors.red
                                        : _serialSuccessText != null
                                        ? Colors.green
                                        : widget.isDarkTheme
                                        ? Colors.grey
                                        : Colors.black12,
                                width: 1.0,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color:
                                    _serialErrorText != null
                                        ? Colors.red
                                        : _serialSuccessText != null
                                        ? Colors.green
                                        : widget.isDarkTheme
                                        ? Colors.grey
                                        : Colors.black12,
                                width: 1.0,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color:
                                    _serialErrorText != null
                                        ? Colors.red
                                        : _serialSuccessText != null
                                        ? Colors.green
                                        : Colors.blue,
                                width: 2.0,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            fillColor:
                                widget.isDarkTheme
                                    ? AppColors.darkCardBackground
                                    : AppColors.cardBackground,
                            filled: true,
                            errorText: _serialErrorText,
                            errorStyle: const TextStyle(color: Colors.red),
                            // Add suffix for success message
                            suffixIcon:
                                _serialSuccessText != null
                                    ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                    : null,
                          ),
                          onSubmitted: widget.onSerialSubmitted,
                          onChanged: _validateSerial,
                        ),
                        // Display success message if present
                        if (_serialSuccessText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _serialSuccessText!,
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Invisible text to match height of label
                      const SizedBox(height: 18),
                      _buildLoadingButton(
                        isLoading: _isQrCodeButtonLoading,
                        onPressed: _handleQrScan,
                        text: 'Quét QR',
                        icon: Icons.qr_code,
                        backgroundColor: AppColors.scanQr,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Hàng 4: Cổng COM (USB)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                                    ? AppColors.darkCardBackground
                                    : AppColors.cardBackground,
                            filled: true,
                            errorText:
                                widget.availablePorts.isEmpty
                                    ? 'Không tìm thấy cổng COM nào'
                                    : widget.selectedPort == null
                                    ? 'Cần chọn cổng COM để nạp firmware'
                                    : null,
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
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    // Add top padding to align with input field
                    child: _buildLoadingButton(
                      isLoading: _isRefreshButtonLoading,
                      onPressed: _handleRefreshPorts,
                      text: 'Làm Mới',
                      icon: Icons.refresh,
                      backgroundColor: AppColors.refresh,
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