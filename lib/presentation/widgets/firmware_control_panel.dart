import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/data/models/device.dart';
import 'package:smart_net_firmware_loader/data/models/firmware.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/presentation/blocs/log/log_bloc.dart';
import 'package:smart_net_firmware_loader/utils/app_colors.dart';
import 'package:smart_net_firmware_loader/utils/app_config.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/rounded_button.dart';

class FirmwareControlPanel extends StatefulWidget {
  final List<Firmware> firmwares;
  final String? selectedFirmwareVersion;
  final TextEditingController serialController;
  final List<String> availablePorts;
  final String? selectedPort;
  final bool isDarkTheme;
  final VoidCallback onLocalFileSearch;
  final Function(String?) onFirmwareVersionSelected;
  final Function(String) onSerialSubmitted;
  final VoidCallback onQrCodeScan;
  final VoidCallback onUsbPortRefresh;
  final Function(String?) onUsbPortSelected;
  final Function(String, {String? value}) onWarningRequested;
  final bool isLocalFileMode;
  final Function(bool) onQrCodeAvailabilityChanged;  // Add new callback

  const FirmwareControlPanel({
    super.key,
    required this.firmwares,
    required this.selectedFirmwareVersion,
    required this.serialController,
    required this.availablePorts,
    required this.selectedPort,
    required this.isDarkTheme,
    required this.onLocalFileSearch,
    required this.onFirmwareVersionSelected,
    required this.onSerialSubmitted,
    required this.onQrCodeScan,
    required this.onUsbPortRefresh,
    required this.onUsbPortSelected,
    required this.onWarningRequested,
    required this.isLocalFileMode,
    required this.onQrCodeAvailabilityChanged,  // Add to constructor
  });

  @override
  State<FirmwareControlPanel> createState() => _FirmwareControlPanelState();
}

class _FirmwareControlPanelState extends State<FirmwareControlPanel> {
  final bool _isFileButtonLoading = false;
  bool _isVersionButtonLoading = false;
  bool _isQrCodeButtonLoading = false;
  bool _isRefreshButtonLoading = false;
  String? _serialErrorText;
  String? _serialSuccessText;
  bool _isSerialValid = false;

  void _handleModeToggle() {
    widget.onWarningRequested(
      widget.isLocalFileMode ? 'switch_to_version' : 'switch_to_local'
    );
  }

  void _handleFirmwareVersionChange(String? value) {
    if (value != widget.selectedFirmwareVersion) {
      widget.onWarningRequested('version_change', value: value);
    }
  }

  void _validateAndSubmitSerial(String value) {
    // Cập nhật controller với giá trị mới
    final currentPosition = widget.serialController.selection;
    widget.serialController.value = TextEditingValue(
      text: value,
      selection: currentPosition,
    );

    setState(() {
      if (value.isEmpty) {
        _serialErrorText = 'Số serial không được để trống';
        _serialSuccessText = null;
        _isSerialValid = false;
      } else {
        _serialErrorText = null;
        _serialSuccessText = null;
        _isSerialValid = true;
      }
    });

    _validateSerial(value);
  }

  void _validateSerial(String value) {
    setState(() {
      if (value.isEmpty) {
        _serialErrorText = 'Số serial không được để trống';
        _serialSuccessText = null;
        _isSerialValid = false;
        return;
      }

      final state = context.read<LogBloc>().state;
      if (state.selectedBatchId == null) {
        _serialErrorText = 'Cần chọn lô sản xuất để xác thực serial';
        _serialSuccessText = null;
        _isSerialValid = false;
        return;
      }

      final matchingDevice = state.devices.firstWhere(
            (device) => device.serial.trim().toLowerCase() == value.trim().toLowerCase(),
        orElse: () => Device(id: '', batchId: '', serial: ''),
      );

      if (matchingDevice.id.isEmpty) {
        _serialErrorText = 'Serial không tồn tại trong lô ${state.selectedBatchId}';
        _serialSuccessText = null;
        _isSerialValid = false;
        return;
      }

      if (matchingDevice.status == 'firmware_uploading') {
        _serialErrorText = null;
        _serialSuccessText = '✅ Serial hợp lệ - Thiết bị sẵn sàng cho nạp firmware';
        _isSerialValid = true;
        widget.onSerialSubmitted(value);
      } else {
        _serialErrorText = 'Thiết bị không ở trạng thái cho phép nạp firmware';
        _serialSuccessText = null;
        _isSerialValid = false;
      }
    });
  }

  void _handleQrScan() {
    final state = context.read<LogBloc>().state;
    if (state.selectedBatchId == null) {
      setState(() {
        _serialErrorText = 'Vui lòng chọn lô sản xuất trước khi quét QR';
        _serialSuccessText = null;
        _isSerialValid = false;
      });

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
      widget.onQrCodeAvailabilityChanged(false);  // Notify QR not available
      return;
    }

    // Enable QR scanning
    widget.onQrCodeAvailabilityChanged(true);

    setState(() {
      _isQrCodeButtonLoading = true;
      _serialErrorText = null;
      _serialSuccessText = null;
    });

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
      duration: const Duration(days: 1),
      backgroundColor: AppColors.scanQr,
    );

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(snackBar);

    final previousValue = widget.serialController.text;
    final startTime = DateTime.now();
    const timeoutDuration = Duration(seconds: 62);

    widget.onQrCodeScan();

    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        scaffoldMessenger.hideCurrentSnackBar();
        return;
      }

      final newValue = widget.serialController.text;

      if (newValue != previousValue && newValue.isNotEmpty) {
        timer.cancel();

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

        if (state.selectedBatchId != null) {
          context.read<LogBloc>().add(RefreshBatchDevicesEvent(state.selectedBatchId!));

          Future.delayed(const Duration(milliseconds: 800), () {
            if (!mounted) return;

            _validateReceivedSerial(newValue);

            setState(() {
              _isQrCodeButtonLoading = false;
            });
            scaffoldMessenger.hideCurrentSnackBar();
          });
        } else {
          _validateReceivedSerial(newValue);
          setState(() {
            _isQrCodeButtonLoading = false;
          });
          scaffoldMessenger.hideCurrentSnackBar();
        }
      }

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

  void _validateReceivedSerial(String value) {
    if (!mounted) return;

    _validateSerial(value);

    if (_isQrCodeButtonLoading) {
      setState(() {
        _isQrCodeButtonLoading = false;
      });
    }
  }


  void _handleRefreshPorts() async {
    setState(() {
      _isRefreshButtonLoading = true;
    });

    try {
      widget.onUsbPortRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã làm mới danh sách cổng COM'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
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
    bool enabled = true,
  }) {
    return SizedBox(
      height: 48,
      child: RoundedButton(
        label: isLoading ? 'Đang xử lý...' : text,
        icon: isLoading ? null : icon,
        onPressed: enabled ? onPressed : () {},
        color: enabled ? backgroundColor : AppColors.buttonDisabled,
        isLoading: isLoading,
        enabled: enabled,
      ),
    );
  }

  @override
  void didUpdateWidget(FirmwareControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLocalFileMode != widget.isLocalFileMode) {
      setState(() {});  // Trigger rebuild on mode change
    }
  }

  void _handleLocalFileSearch() {
    widget.onWarningRequested('select_local_file');
  }

  bool _canFlash() {
    if (widget.isLocalFileMode) {
      final state = context.read<LogBloc>().state;
      return state.localFilePath != null && widget.selectedPort != null && _isSerialValid;
    } else {
      return widget.selectedFirmwareVersion != null && widget.selectedPort != null && _isSerialValid;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LogBloc, LogState>(
      builder: (context, state) {
        final hasLocalFile = state.localFilePath != null;
        final fileName = hasLocalFile
            ? state.localFilePath!.split(Platform.pathSeparator).last
            : 'Chưa chọn file';

        // Add rebuild trigger when mode changes
        final isReadyToFlash = _canFlash();

        // Modify conditions to allow input before batch selection
        final bool _ = true; // Always allow serial input
        final bool canScanQR = state.selectedBatchId != null; // QR requires batch selection

        return Padding(
          padding: const EdgeInsets.all(AppConfig.defaultPadding),
          child: Column(
            children: [
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
                              borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            fillColor: widget.isDarkTheme
                                ? widget.isLocalFileMode
                                    ? AppColors.darkCardBackground.withAlpha(128)
                                    : AppColors.darkCardBackground
                                : widget.isLocalFileMode
                                    ? AppColors.cardBackground.withAlpha(128)
                                    : AppColors.cardBackground,
                            filled: true,
                            enabled: !widget.isLocalFileMode,
                          ),
                          items: widget.firmwares.map((firmware) {
                            return DropdownMenuItem(
                              value: firmware.firmwareId.toString(),
                              child: Text(
                                '${firmware.name} (${firmware.version})${firmware.isMandatory ? " - Bắt buộc" : ""}',
                              ),
                            );
                          }).toList(),
                          onChanged: widget.isLocalFileMode ? null : _handleFirmwareVersionChange,
                          hint: Text(
                            widget.isLocalFileMode
                                ? 'Không khả dụng trong chế độ file local'
                                : widget.firmwares.isEmpty
                                ? 'Không có firmware khả dụng'
                                : '-- Chọn phiên bản --',
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
                      _buildLoadingButton(
                        isLoading: _isVersionButtonLoading,
                        onPressed: _handleModeToggle,
                        text: widget.isLocalFileMode ? 'Chọn Version' : 'Upload File',
                        icon: widget.isLocalFileMode ? Icons.cloud_download : Icons.upload_file,
                        backgroundColor: widget.isLocalFileMode ? AppColors.selectVersion : AppColors.findFile,
                      ),
                    ],
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
                              borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            fillColor: widget.isDarkTheme
                                ? widget.isLocalFileMode
                                    ? AppColors.darkCardBackground
                                    : AppColors.darkCardBackground.withAlpha(128)
                                : widget.isLocalFileMode
                                    ? AppColors.cardBackground
                                    : AppColors.cardBackground.withAlpha(128),
                            filled: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: _buildLoadingButton(
                      isLoading: _isFileButtonLoading,
                      onPressed: _handleLocalFileSearch,
                      text: 'Tìm File',
                      icon: Icons.search,
                      backgroundColor: AppColors.findFile,
                      enabled: widget.isLocalFileMode && !hasLocalFile,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                              borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                              borderSide: BorderSide(
                                color: _serialErrorText != null
                                    ? AppColors.error
                                    : _serialSuccessText != null
                                    ? AppColors.success
                                    : widget.isDarkTheme
                                    ? AppColors.darkDivider
                                    : AppColors.dividerColor,
                                width: 1.0,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                              borderSide: BorderSide(
                                color: _serialErrorText != null
                                    ? AppColors.error
                                    : _serialSuccessText != null
                                    ? AppColors.success
                                    : widget.isDarkTheme
                                    ? AppColors.darkDivider
                                    : AppColors.dividerColor,
                                width: 1.0,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                              borderSide: BorderSide(
                                color: _serialErrorText != null
                                    ? AppColors.error
                                    : _serialSuccessText != null
                                    ? AppColors.success
                                    : AppColors.primary,
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
                            errorStyle: const TextStyle(color: AppColors.error),
                            suffixIcon: _serialSuccessText != null
                                ? const Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                            )
                                : null,
                          ),
                          onChanged: _validateAndSubmitSerial,
                          onSubmitted: (value) => _validateSerial(value),
                          enabled: true,
                        ),
                        if (_serialSuccessText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _serialSuccessText!,
                              style: const TextStyle(
                                color: AppColors.success,
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
                      const SizedBox(height: 18),
                      _buildLoadingButton(
                        isLoading: _isQrCodeButtonLoading,
                        onPressed: _handleQrScan,
                        text: 'Quét QR',
                        icon: Icons.qr_code,
                        backgroundColor: AppColors.scanQr,
                        enabled: canScanQR, // QR scan still requires batch selection
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                              borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
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
                            errorStyle: const TextStyle(color: AppColors.error),
                          ),
                          items: widget.availablePorts
                              .map(
                                (port) => DropdownMenuItem(
                              value: port,
                              child: Text(port),
                            ),
                          )
                              .toList(),
                          onChanged: (value) {
                            widget.onUsbPortSelected(value);
                            if (value != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Đã chọn cổng COM: $value'),
                                  backgroundColor: AppColors.success,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          hint: const Text('-- Chọn cổng --'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
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

