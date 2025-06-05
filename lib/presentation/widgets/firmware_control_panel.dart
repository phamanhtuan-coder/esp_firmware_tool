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
  final Function(bool) onFlashStatusChanged;

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
    required this.onFlashStatusChanged,
  });

  @override
  State<FirmwareControlPanel> createState() => _FirmwareControlPanelState();
}

class _FirmwareControlPanelState extends State<FirmwareControlPanel> {
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

            _validateSerial(newValue);

            setState(() {});
            scaffoldMessenger.hideCurrentSnackBar();
          });
        } else {
          _validateSerial(newValue);
          setState(() {});
          scaffoldMessenger.hideCurrentSnackBar();
        }
      }

      if (DateTime.now().difference(startTime) > timeoutDuration) {
        timer.cancel();
        if (mounted) {
          setState(() {});
          scaffoldMessenger.hideCurrentSnackBar();
        }
      }
    });
  }

  @override
  void didUpdateWidget(FirmwareControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLocalFileMode != widget.isLocalFileMode ||
        oldWidget.selectedPort != widget.selectedPort ||
        oldWidget.selectedFirmwareVersion != widget.selectedFirmwareVersion) {
      _canFlash();
      setState(() {});
    }
  }

  bool _canFlash() {
    if (widget.isLocalFileMode) {
      final state = context.read<HomeBloc>().state;
      final canFlash = state.localFilePath != null && widget.selectedPort != null && _isSerialValid;
      widget.onFlashStatusChanged(canFlash);
      return canFlash;
    } else {
      final canFlash = widget.selectedFirmwareVersion != null && widget.selectedPort != null && _isSerialValid;
      widget.onFlashStatusChanged(canFlash);
      return canFlash;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConfig.defaultPadding),
      child: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Firmware version selection and mode toggle button
              Column(
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: widget.selectedFirmwareVersion,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                              borderSide: BorderSide(
                                width: 2,
                                color: widget.isDarkTheme ? Colors.grey[600]! : Colors.grey[400]!,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            fillColor: widget.isDarkTheme
                                ? widget.isLocalFileMode
                                    ? AppColors.darkCardBackground.withAlpha(128)
                                    : AppColors.darkPanelBackground
                                : widget.isLocalFileMode
                                    ? AppColors.cardBackground.withAlpha(200)
                                    : Colors.white,
                            filled: true,
                            enabled: !widget.isLocalFileMode,
                          ),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: widget.isDarkTheme ? Colors.white70 : Colors.black87,
                          ),
                          isExpanded: true,
                          dropdownColor: widget.isDarkTheme ? AppColors.darkPanelBackground : Colors.white,
                          style: TextStyle(
                            fontSize: 15,
                            color: widget.isDarkTheme ? Colors.white : Colors.black87,
                          ),
                          items: widget.firmwares.map((firmware) {
                            return DropdownMenuItem(
                              value: firmware.firmwareId.toString(),
                              child: Text(firmware.version),
                            );
                          }).toList(),
                          onChanged: widget.isLocalFileMode ? null : _handleFirmwareVersionChange,
                          hint: Text(
                            'Chọn phiên bản',
                            style: TextStyle(
                              color: widget.isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _handleModeToggle,
                        icon: Icon(widget.isLocalFileMode ? Icons.storage : Icons.upload_file),
                        label: Text(
                          widget.isLocalFileMode ? 'Chọn version' : 'Upload file',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isDarkTheme ? AppColors.accent : AppColors.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Row 2: Local file selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'File Firmware',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(
                            text: state.localFilePath != null
                                ? state.localFilePath!.split(Platform.pathSeparator).last
                                : '',
                          ),
                          decoration: InputDecoration(
                            labelText: 'File firmware được chọn',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            fillColor: widget.isDarkTheme ? AppColors.darkCardBackground : AppColors.cardBackground,
                            filled: true,
                            enabled: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: widget.isLocalFileMode ? widget.onLocalFileSearch : null,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Chọn file'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isDarkTheme ? AppColors.accent : AppColors.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Row 3: Serial input and QR scan
              Column(
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
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: widget.serialController,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                fillColor: widget.isDarkTheme ? AppColors.darkCardBackground : AppColors.cardBackground,
                                filled: true,
                                errorText: _serialErrorText,
                                suffixIcon: _serialSuccessText != null
                                    ? const Icon(Icons.check_circle, color: AppColors.success)
                                    : null,
                              ),
                              onChanged: _validateSerial,
                            ),
                            if (_serialSuccessText != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  _serialSuccessText!,
                                  style: const TextStyle(color: AppColors.success, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _handleQrScan,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Quét QR Code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.scanQr,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Row 4: USB port selection and refresh
              Column(
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
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: widget.selectedPort,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                              borderSide: BorderSide(
                                width: 2,
                                color: widget.isDarkTheme ? Colors.grey[600]! : Colors.grey[400]!,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            fillColor: widget.isDarkTheme ? AppColors.darkPanelBackground : Colors.white,
                            filled: true,
                          ),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: widget.isDarkTheme ? Colors.white70 : Colors.black87,
                          ),
                          isExpanded: true,
                          dropdownColor: widget.isDarkTheme ? AppColors.darkPanelBackground : Colors.white,
                          style: TextStyle(
                            fontSize: 15,
                            color: widget.isDarkTheme ? Colors.white : Colors.black87,
                          ),
                          items: widget.availablePorts.map((port) {
                            return DropdownMenuItem(
                              value: port,
                              child: Text(port),
                            );
                          }).toList(),
                          onChanged: widget.onUsbPortSelected,
                          hint: Text(
                            'Chọn cổng COM',
                            style: TextStyle(
                              color: widget.isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: widget.onUsbPortRefresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Làm mới cổng'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isDarkTheme ? AppColors.accent : AppColors.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Row 5: Flash firmware button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Builder(builder: (context) {
                    final canFlash = _isSerialValid &&
                      widget.selectedPort != null &&
                      (widget.isLocalFileMode
                        ? state.localFilePath != null
                        : widget.selectedFirmwareVersion != null);

                    return ElevatedButton.icon(
                      onPressed: canFlash ? () {
                        if (widget.isLocalFileMode && state.localFilePath == null) {
                          widget.onWarningRequested('select_local_file');
                          return;
                        }

                        widget.onWarningRequested('flash_firmware');
                      } : null,
                      icon: const Icon(Icons.flash_on),
                      label: const Text('Nạp Firmware'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.flash,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        disabledBackgroundColor: Colors.grey[400],
                      ),
                    );
                  }),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
