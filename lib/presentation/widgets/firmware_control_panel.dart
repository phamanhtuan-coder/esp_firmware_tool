import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:smart_net_firmware_loader/data/models/device.dart';
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

  void _handleQrScan() {
    // Check if batch is selected first
    final state = context.read<LogBloc>().state;
    if (state.selectedBatchId == null) {
      setState(() {
        _serialErrorText = 'Vui lòng chọn lô sản xuất trước khi quét QR';
        _serialSuccessText = null;
        _isSerialValid = false;
      });

      // Add a log entry to notify the user
      context.read<LogBloc>().add(
        AddLogEvent(
          LogEntry(
            message: 'Vui lòng chọn lô sản xuất trước khi quét QR code',
            timestamp: DateTime.now(),
            level: LogLevel.warning,
            step: ProcessStep.scanQrCode,
            origin: 'system',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isQrCodeButtonLoading = true;
      // Clear any existing validation messages
      _serialErrorText = null;
      _serialSuccessText = null;
    });

    // Show a SnackBar to inform the user what to do while scanning is in progress
    final snackBar = SnackBar(
      content: Row(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 2,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Đã bật chế độ nhận thông tin. Hãy dùng app mobile và quét mã sản phẩm muốn nạp firmware trong lô ${state.selectedBatchId}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      duration: const Duration(days: 1), // Very long duration - will be dismissed manually when scan completes
      backgroundColor: Colors.blue.shade700,
    );

    // Show the snackbar
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(snackBar);

    // Store previous value to check if it changed after scan
    final previousValue = widget.serialController.text;

    // Start time to track timeout
    final startTime = DateTime.now();
    const timeoutDuration = Duration(seconds: 62); // 62 seconds timeout

    // Invoke the QR scan callback, which will update the controller text if scan succeeds
    widget.onQrCodeScan();

    // Create a timer to periodically check if the serial value has changed
    // This solves the async issue without needing to modify the parent widget's callback type
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      // Stop checking if widget is no longer mounted
      if (!mounted) {
        timer.cancel();
        scaffoldMessenger.hideCurrentSnackBar(); // Hide snackbar if not mounted
        return;
      }

      final newValue = widget.serialController.text;

      // If the value has changed, the scan was successful
      if (newValue != previousValue && newValue.isNotEmpty) {
        timer.cancel();

        // Keep loading state active a bit longer while we refresh data
        context.read<LogBloc>().add(
          AddLogEvent(
            LogEntry(
              message: 'Đang làm mới dữ liệu thiết bị từ server...',
              timestamp: DateTime.now(),
              level: LogLevel.info,
              step: ProcessStep.deviceSelection,
              origin: 'system',
            ),
          ),
        );

        // Fetch fresh data from the server before validating
        if (state.selectedBatchId != null) {
          context.read<LogBloc>().add(RefreshBatchDevicesEvent(state.selectedBatchId!));

          // Add a small delay to allow time for data refresh and to keep loading indicator visible
          Future.delayed(const Duration(milliseconds: 800), () {
            if (!mounted) return;

            // Now validate the serial with fresh data
            _validateReceivedSerial(newValue);

            // End loading state and hide snackbar
            setState(() {
              _isQrCodeButtonLoading = false;
            });
            scaffoldMessenger.hideCurrentSnackBar();
          });
        } else {
          // If no batch selected (shouldn't happen due to earlier check), validate immediately
          _validateReceivedSerial(newValue);
          setState(() {
            _isQrCodeButtonLoading = false;
          });
          scaffoldMessenger.hideCurrentSnackBar();
        }
      }

      // Add a timeout to eventually cancel the loading state after 62 seconds
      if (DateTime.now().difference(startTime) > timeoutDuration) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isQrCodeButtonLoading = false;
          });
          scaffoldMessenger.hideCurrentSnackBar();
        }
      }
    });
  }

  // New method to validate a received serial number
  void _validateReceivedSerial(String value) {
    if (!mounted) return;

    // Use the more comprehensive validation method for consistency
    _validateSerial(value);

    // End QR code loading status if it's still active
    if (_isQrCodeButtonLoading) {
      setState(() {
        _isQrCodeButtonLoading = false;
      });
    }
  }

  // Enhanced method to validate serial input with detailed status messages
  void _validateSerial(String value) {
    if (value.isEmpty) {
      setState(() {
        _serialErrorText = 'Số serial không được để trống';
        _serialSuccessText = null;
        _isSerialValid = false;
      });
      return;
    }

    // Check if batch is selected
    final state = context.read<LogBloc>().state;

    if (state.selectedBatchId == null) {
      setState(() {
        _serialErrorText = 'Vui lòng chọn lô sản xuất trước khi nhập serial';
        _serialSuccessText = null;
        _isSerialValid = false;
      });
      context.read<LogBloc>().add(
        AddLogEvent(
          LogEntry(
            message: 'Vui lòng chọn lô sản xuất trước khi nhập serial: $value',
            timestamp: DateTime.now(),
            level: LogLevel.warning,
            step: ProcessStep.deviceSelection,
            origin: 'system',
          ),
        ),
      );
      return;
    }

    // Find device with matching serial
    final matchingDevice = state.devices.firstWhere(
      (device) => device.serial.trim().toLowerCase() == value.trim().toLowerCase(),
      orElse: () => Device(id: '', batchId: '', serial: ''),
    );

    if (matchingDevice.id.isEmpty) {
      // No matching device found
      setState(() {
        _serialErrorText = 'Serial $value không tồn tại trong lô ${state.selectedBatchId}';
        _serialSuccessText = null;
        _isSerialValid = false;
      });

      context.read<LogBloc>().add(
        AddLogEvent(
          LogEntry(
            message: 'Serial $value không tồn tại trong lô ${state.selectedBatchId}',
            timestamp: DateTime.now(),
            level: LogLevel.warning,
            step: ProcessStep.deviceSelection,
            origin: 'system',
          ),
        ),
      );
      return;
    }

    // Check device status and provide appropriate feedback
    switch (matchingDevice.status) {
      case 'firmware_uploading':
        // Only firmware_uploading status is valid for selection
        setState(() {
          _serialSuccessText = '✅ Serial hợp lệ - Thiết bị sẵn sàng cho nạp firmware và Serial Monitor';
          _serialErrorText = null;
          _isSerialValid = true;
        });
        // Select the device in global state
        context.read<LogBloc>().add(SelectDeviceEvent(matchingDevice.id));
        break;

      case 'firmware_uploaded':
        // Device already has firmware uploaded
        setState(() {
          _serialSuccessText = '✅ Serial hợp lệ - Thiết bị đã hoàn thành nạp firmware';
          _serialErrorText = null;
          _isSerialValid = true;
        });
        // Select the device in global state
        context.read<LogBloc>().add(SelectDeviceEvent(matchingDevice.id));
        break;

      case 'firmware_upload':
        // Requires the mobile app to activate first
        setState(() {
          _serialErrorText = '🔒 Serial chờ kích hoạt - Quét QR trên app mobile để kích hoạt';
          _serialSuccessText = null;
          _isSerialValid = false;
        });
        context.read<LogBloc>().add(
          AddLogEvent(
            LogEntry(
              message: 'Serial $value chưa được kích hoạt để nạp firmware. Vui lòng quét QR trên app mobile',
              timestamp: DateTime.now(),
              level: LogLevel.warning,
              step: ProcessStep.deviceSelection,
              origin: 'system',
            ),
          ),
        );
        break;

      case 'pending':
        // Requires the mobile app to activate first
        setState(() {
          _serialErrorText = '⚠️ Serial chờ kích hoạt - Quét QR trên app mobile để kích hoạt';
          _serialSuccessText = null;
          _isSerialValid = false;
        });
        context.read<LogBloc>().add(
          AddLogEvent(
            LogEntry(
              message: 'Serial $value đang ở trạng thái chờ, chưa được kích hoạt. Vui lòng quét QR trên app mobile',
              timestamp: DateTime.now(),
              level: LogLevel.warning,
              step: ProcessStep.deviceSelection,
              origin: 'system',
            ),
          ),
        );
        break;

      case 'firmware_failed':
        setState(() {
          _serialErrorText = '❌ Thiết bị đã được đánh dấu lỗi firmware';
          _serialSuccessText = null;
          _isSerialValid = false;
        });
        context.read<LogBloc>().add(
          AddLogEvent(
            LogEntry(
              message: 'Serial $value đã được đánh dấu lỗi firmware trước đó',
              timestamp: DateTime.now(),
              level: LogLevel.error,
              step: ProcessStep.deviceSelection,
              origin: 'system',
              deviceId: value,
            ),
          ),
        );
        break;

      case 'defective':
        setState(() {
          _serialErrorText = '❌ Thiết bị đã được đánh dấu lỗi';
          _serialSuccessText = null;
          _isSerialValid = false;
        });
        context.read<LogBloc>().add(
          AddLogEvent(
            LogEntry(
              message: 'Serial $value đã được đánh dấu lỗi',
              timestamp: DateTime.now(),
              level: LogLevel.error,
              step: ProcessStep.deviceSelection,
              origin: 'system',
              deviceId: value,
            ),
          ),
        );
        break;

      case 'in_progress':
        setState(() {
          _serialErrorText = '⚠️ Thiết bị còn trong giai đoạn lắp ráp';
          _serialSuccessText = null;
          _isSerialValid = false;
        });
        context.read<LogBloc>().add(
          AddLogEvent(
            LogEntry(
              message: 'Serial $value còn trong giai đoạn lắp ráp',
              timestamp: DateTime.now(),
              level: LogLevel.warning,
              step: ProcessStep.deviceSelection,
              origin: 'system',
              deviceId: value,
            ),
          ),
        );
        break;

      default:
        setState(() {
          _serialErrorText = '⚠️ Trạng thái thiết bị không hợp lệ: ${matchingDevice.status}';
          _serialSuccessText = null;
          _isSerialValid = false;
        });
        context.read<LogBloc>().add(
          AddLogEvent(
            LogEntry(
              message: 'Serial $value có trạng thái không hỗ trợ: ${matchingDevice.status}',
              timestamp: DateTime.now(),
              level: LogLevel.warning,
              step: ProcessStep.deviceSelection,
              origin: 'system',
              deviceId: value,
            ),
          ),
        );
        break;
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
            ? const SizedBox(
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
                            fillColor: widget.isDarkTheme
                                ? hasLocalFile
                                    ? AppColors.darkCardBackground.withOpacity(
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
                          onChanged: hasLocalFile
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
                            fillColor: widget.isDarkTheme
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
                                color: _serialErrorText != null
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
                                color: _serialErrorText != null
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
                                color: _serialErrorText != null
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
                            fillColor: widget.isDarkTheme
                                ? AppColors.darkCardBackground
                                : AppColors.cardBackground,
                            filled: true,
                            errorText: _serialErrorText,
                            errorStyle: const TextStyle(color: Colors.red),
                            // Add suffix for success message
                            suffixIcon: _serialSuccessText != null
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
                            fillColor: widget.isDarkTheme
                                ? AppColors.darkCardBackground
                                : AppColors.cardBackground,
                            filled: true,
                            errorText: widget.availablePorts.isEmpty
                                ? 'Không tìm thấy cổng COM nào'
                                : widget.selectedPort == null
                                    ? 'Cần chọn cổng COM để nạp firmware'
                                    : null,
                          ),
                          items: widget.availablePorts
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

