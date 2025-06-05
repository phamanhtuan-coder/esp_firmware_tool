import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';
import 'package:smart_net_firmware_loader/core/config/app_config.dart';
import 'package:smart_net_firmware_loader/data/models/device.dart';
import 'package:smart_net_firmware_loader/data/models/firmware.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/domain/blocs/home_bloc.dart';
import 'package:smart_net_firmware_loader/domain/blocs/logging_bloc.dart';
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
  final Function(bool) onQrCodeAvailabilityChanged;

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
    required this.onQrCodeAvailabilityChanged,
  });

  @override
  State<FirmwareControlPanel> createState() => _FirmwareControlPanelState();
}

class _FirmwareControlPanelState extends State<FirmwareControlPanel> {
  bool _isFileButtonLoading = false;
  bool _isQrCodeButtonLoading = false;
  bool _isRefreshButtonLoading = false;
  String? _serialErrorText;
  String? _serialSuccessText;
  bool _isSerialValid = false;

  void _handleModeToggle() {
    widget.onWarningRequested(
      widget.isLocalFileMode ? 'switch_to_version' : 'switch_to_local',
    );
  }

  void _handleFirmwareVersionChange(String? value) {
    if (value != widget.selectedFirmwareVersion) {
      widget.onWarningRequested('version_change', value: value);
    }
  }

  void _validateAndSubmitSerial(String value) {
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

      final state = context.read<HomeBloc>().state;
      if (state.selectedBatchId == null) {
        _serialErrorText = 'Cần chọn lô sản xuất để xác thực serial';
        _serialSuccessText = null;
        _isSerialValid = false;
        return;
      }

      final matchingDevice = state.devices.firstWhere(
        (device) =>
            device.serial.trim().toLowerCase() == value.trim().toLowerCase(),
        orElse: () => Device(id: '', batchId: '', serial: ''),
      );

      if (matchingDevice.id.isEmpty) {
        _serialErrorText =
            'Serial không tồn tại trong lô ${state.selectedBatchId}';
        _serialSuccessText = null;
        _isSerialValid = false;
        return;
      }

      if (matchingDevice.status == 'firmware_uploading') {
        _serialErrorText = null;
        _serialSuccessText =
            '✅ Serial hợp lệ - Thiết bị sẵn sàng cho nạp firmware';
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
    final state = context.read<HomeBloc>().state;
    if (state.selectedBatchId == null) {
      setState(() {
        _serialErrorText = 'Vui lòng chọn lô sản xuất trước khi quét QR';
        _serialSuccessText = null;
        _isSerialValid = false;
      });

      context.read<LoggingBloc>().add(
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
      widget.onQrCodeAvailabilityChanged(false);
      return;
    }

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

        context.read<LoggingBloc>().add(
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
          context.read<HomeBloc>().add(
            RefreshBatchDevicesEvent(state.selectedBatchId!),
          );

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
      setState(() {});
    }
  }

  bool _canFlash() {
    if (widget.isLocalFileMode) {
      final state = context.read<HomeBloc>().state;
      return state.localFilePath != null &&
          widget.selectedPort != null &&
          _isSerialValid;
    } else {
      return widget.selectedFirmwareVersion != null &&
          widget.selectedPort != null &&
          _isSerialValid;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        final hasLocalFile = state.localFilePath != null;
        final fileName =
            hasLocalFile
                ? state.localFilePath!.split(Platform.pathSeparator).last
                : 'Chưa chọn file';

        final _ = _canFlash();
        final bool canScanQR = state.selectedBatchId != null;

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
                              borderRadius: BorderRadius.circular(
                                AppConfig.cardBorderRadius,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            fillColor:
                                widget.isDarkTheme
                                    ? widget.isLocalFileMode
                                        ? AppColors.darkCardBackground
                                            .withAlpha(128)
                                        : AppColors.darkCardBackground
                                    : widget.isLocalFileMode
                                    ? AppColors.cardBackground.withAlpha(128)
                                    : AppColors.cardBackground,
                            filled: true,
                            enabled: !widget.isLocalFileMode,
                          ),
                          items:
                              widget.firmwares.map((firmware) {
                                return DropdownMenuItem(
                                  value: firmware.firmwareId.toString(),
                                  child: Text(firmware.version),
                                );
                              }).toList(),
                          onChanged:
                              widget.isLocalFileMode
                                  ? null
                                  : _handleFirmwareVersionChange,
                          hint: const Text('Chọn phiên bản'),
                        ),
                        const SizedBox(height: 16),
                        _buildLoadingButton(
                          isLoading: _isFileButtonLoading,
                          onPressed: widget.onLocalFileSearch,
                          text: hasLocalFile ? fileName : 'Chọn file cục bộ',
                          icon: Icons.folder_open,
                          backgroundColor: AppColors.primary,
                          enabled: widget.isLocalFileMode,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cổng USB',
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
                              borderRadius: BorderRadius.circular(
                                AppConfig.cardBorderRadius,
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
                          ),
                          items:
                              widget.availablePorts.map((port) {
                                return DropdownMenuItem(
                                  value: port,
                                  child: Text(port),
                                );
                              }).toList(),
                          onChanged: widget.onUsbPortSelected,
                          hint: const Text('Chọn cổng COM'),
                        ),
                        const SizedBox(height: 16),
                        _buildLoadingButton(
                          isLoading: _isRefreshButtonLoading,
                          onPressed: _handleRefreshPorts,
                          text: 'Làm mới cổng',
                          icon: Icons.refresh,
                          backgroundColor: AppColors.secondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
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
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppConfig.cardBorderRadius,
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
                            suffixIcon:
                                _serialSuccessText != null
                                    ? const Icon(
                                      Icons.check_circle,
                                      color: AppColors.success,
                                    )
                                    : null,
                          ),
                          onChanged: _validateAndSubmitSerial,
                        ),
                        if (_serialSuccessText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
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
                  const SizedBox(width: 16),
                  _buildLoadingButton(
                    isLoading: _isQrCodeButtonLoading,
                    onPressed: _handleQrScan,
                    text: 'Quét QR Code',
                    icon: Icons.qr_code_scanner,
                    backgroundColor: AppColors.scanQr,
                    enabled: canScanQR,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _handleModeToggle,
                  child: Text(
                    widget.isLocalFileMode
                        ? 'Chuyển sang chọn phiên bản'
                        : 'Chuyển sang upload file cục bộ',
                    style: TextStyle(
                      color:
                          widget.isDarkTheme
                              ? AppColors.accent
                              : AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
