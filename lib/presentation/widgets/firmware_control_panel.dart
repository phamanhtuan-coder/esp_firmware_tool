import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';
import 'package:smart_net_firmware_loader/core/config/app_config.dart';
import 'package:smart_net_firmware_loader/data/models/device.dart';
import 'package:smart_net_firmware_loader/data/models/firmware.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/domain/blocs/home_bloc.dart';
import 'package:smart_net_firmware_loader/domain/blocs/logging_bloc.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/manual_serial_input_dialog.dart';

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
  bool _canFlash = false;
  String? _selectedFirmwareVersion;

  final List<bool> _selections = [true, false]; // [Version mode, File mode]


  Timer? _portCheckTimer;
  final Set<String> _previousPorts = {};
  String? _pendingPort;

  // Thêm biến flag để theo dõi nguồn của serial (QR code hay thủ công)
  bool _isFromQrScan = false;

  void _handleModeToggle(int index) {
    setState(() {
      for (int i = 0; i < _selections.length; i++) {
        _selections[i] = i == index;
      }
    });

    if (index == 0) {
      // Version mode
      widget.onWarningRequested('switch_to_version');
    } else {
      // File mode
      widget.onWarningRequested('switch_to_local');
    }
  }

  void _handleFirmwareVersionChange(String? value) {
    if (value != widget.selectedFirmwareVersion) {
      _selectedFirmwareVersion = value;
      widget.onWarningRequested('version_change', value: value);
      widget.onFirmwareVersionSelected(value);

      if (mounted) {
        setState(() {}); // Trigger UI update
      }
    }
  }

  void _validateSerial(String value) {
    // Nếu đang ����ược gọi từ QR code scan, không hiển thị warning
    final isManualInput = !_isFromQrScan;

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
        orElse: () => Device(id: '', batchId: '', serial: '', status: ''),
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

        // Chỉ hiển thị dialog cảnh báo nếu là nhập thủ công
        if (isManualInput) {
          widget.onWarningRequested('manual_serial');
        }
      } else {
        _serialErrorText = 'Thiết bị không ở trạng thái cho phép nạp firmware';
        _serialSuccessText = null;
        _isSerialValid = false;
      }

      // Reset flag sau khi đã xử lý
      _isFromQrScan = false;
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

    // Hiển thị dialog mới với 3 tùy chọn nhập liệu
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ManualSerialInputDialog(
          isDarkTheme: widget.isDarkTheme,
          onDataReceived: (String serialNumber) {
            // Cập nhật serial number vào text field
            widget.serialController.text = serialNumber;

            // Log thành công
            context.read<LoggingBloc>().add(
              AddLogEvent(
                LogEntry(
                  message: 'QR Code đã được quét thành công: $serialNumber',
                  timestamp: DateTime.now(),
                  level: LogLevel.success,
                  step: ProcessStep.scanQrCode,
                  origin: 'system',
                ),
              ),
            );

            // Đánh dấu là từ QR scan để không hiển thị warning
            _isFromQrScan = true;

            // Validate serial number
            _validateSerial(serialNumber);
          },
        );
      },
    );
  }


  void _handlePortSelection(String? value) {
    if (value == _pendingPort) return;

    _pendingPort = value;
    if (value != null) {
      _validateAndSelectPort(value);
    }
    widget.onUsbPortSelected(value);
  }

  void _validateAndSelectPort(String port) {
    try {
      // Kiểm tra cổng bằng flutter_libserialport
      if (!SerialPort.availablePorts.contains(port)) {
        context.read<LoggingBloc>().add(
          AddLogEvent(
            LogEntry(
              message: 'Port $port not found',
              timestamp: DateTime.now(),
              level: LogLevel.error,
              step: ProcessStep.usbCheck,
              origin: 'system',
            ),
          ),
        );
        return;
      }

      // Thử mở cổng để kiểm tra quyền truy cập
      final testPort = SerialPort(port);
      if (!testPort.openReadWrite()) {
        context.read<LoggingBloc>().add(
          AddLogEvent(
            LogEntry(
              message: 'Cannot access port $port. Port may be in use.',
              timestamp: DateTime.now(),
              level: LogLevel.error,
              step: ProcessStep.usbCheck,
              origin: 'system',
            ),
          ),
        );
        return;
      }
      testPort.close();

      // Cổng hợp lệ, cập nhật selection
      widget.onUsbPortSelected(port);

      context.read<LoggingBloc>().add(
        AddLogEvent(
          LogEntry(
            message: 'Selected port $port',
            timestamp: DateTime.now(),
            level: LogLevel.success,
            step: ProcessStep.usbCheck,
            origin: 'system',
          ),
        ),
      );

    } catch (e) {
      context.read<LoggingBloc>().add(
        AddLogEvent(
          LogEntry(
            message: 'Error accessing port $port: $e',
            timestamp: DateTime.now(),
            level: LogLevel.error,
            step: ProcessStep.usbCheck,
            origin: 'system',
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _startPortChecking();
    _previousPorts.addAll(widget.availablePorts);
    _pendingPort = widget.selectedPort;

    // Add listener to detect serial controller changes from QR code
    widget.serialController.addListener(_onSerialControllerChanged);
  }

  void _onSerialControllerChanged() {
    // If the serial text changes from outside (like QR scan),
    // mark it as from QR scan and validate
    if (mounted) {
      _isFromQrScan = true;
      _validateSerial(widget.serialController.text);
    }
  }

  void _startPortChecking() {
    _portCheckTimer?.cancel();
    _portCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      // Kiểm tra port c��� bị ngắt kết nối không
      final currentPorts = Set<String>.from(widget.availablePorts);
      final disconnectedPorts = _previousPorts.difference(currentPorts);
      final newPorts = currentPorts.difference(_previousPorts);

      if (disconnectedPorts.isNotEmpty) {
        // Có port bị ngắt kết nối
        for (final port in disconnectedPorts) {
          if (port == widget.selectedPort) {
            // Port đang chọn bị ngắt kết nối
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cổng $port đã bị ngắt kết nối'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
            // Cập nhật UI
            widget.onUsbPortSelected(null);
          }
        }
      }

      if (newPorts.isNotEmpty) {
        // Có port mới được kết nối
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã phát hiện cổng mới: ${newPorts.join(", ")}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      _previousPorts.clear();
      _previousPorts.addAll(currentPorts);
    });
  }

  @override
  void dispose() {
    widget.serialController.removeListener(_onSerialControllerChanged);
    _portCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConfig.defaultPadding),
      child: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: Toggle Buttons
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      ToggleButtons(
                        isSelected: _selections,
                        onPressed: _handleModeToggle,
                        borderRadius: BorderRadius.circular(8),
                        selectedBorderColor: AppColors.primary,
                        borderColor: Colors.transparent,
                        fillColor: widget.isDarkTheme ? AppColors.primary : AppColors.componentBackground,
                        selectedColor: AppColors.primary,
                        color: widget.isDarkTheme ? AppColors.darkTextPrimary : AppColors.text,
                        constraints: const BoxConstraints(minWidth: 120, minHeight: 40),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.storage,
                                  color:
                                      widget.isDarkTheme
                                          ? AppColors.darkTextPrimary
                                          : AppColors.text,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Chọn Version',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        widget.isDarkTheme
                                            ? AppColors.darkTextPrimary
                                            : AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.upload_file,
                                  color:
                                      widget.isDarkTheme
                                          ? AppColors.darkTextPrimary
                                          : AppColors.text,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Upload File',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        widget.isDarkTheme
                                            ? AppColors.darkTextPrimary
                                            : AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Row 2: Version Selection and File Selection (2 columns)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Column 1: Firmware Version Selection
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 8, bottom: 16),
                        decoration: BoxDecoration(
                          color: widget.isDarkTheme ? AppColors.darkPanelBackground : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Phiên bản Firmware',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: widget.isDarkTheme ? AppColors.darkTextPrimary : AppColors.text
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: DropdownButtonFormField<String>(
                                value: widget.selectedFirmwareVersion,
                                onChanged: _selections[0] ? _handleFirmwareVersionChange : null,
                                items: widget.firmwares.map((firmware) {
                                  return DropdownMenuItem(
                                    value: firmware.firmwareId.toString(),
                                    child: Text(firmware.version,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  );
                                }).toList(),
                                decoration: InputDecoration(
                                  enabled: _selections[0],
                                  hintText: 'Chọn phiên bản',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppColors.borderColor,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppColors.borderColor,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  fillColor: AppColors.componentBackground,
                                  filled: true,
                                ),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.black87,
                                ),
                                dropdownColor: AppColors.componentBackground,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                                hint: Text(
                                  'Chọn phiên bản',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Column 2: File Selection
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(left: 8, bottom: 16),
                        decoration: BoxDecoration(
                          color: widget.isDarkTheme ? AppColors.darkPanelBackground : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'File Firmware',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: widget.isDarkTheme ? AppColors.darkTextPrimary : AppColors.text
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: TextEditingController(
                                        text: state.localFilePath != null
                                            ? state.localFilePath!.split(Platform.pathSeparator).last
                                            : '',
                                      ),
                                      enabled: false,
                                      readOnly: true,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                            color: AppColors.borderColor,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                            color: AppColors.borderColor,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                            color: AppColors.primary,
                                            width: 1.5,
                                          ),
                                        ),
                                        hintText: 'Chưa có file nào được chọn',
                                        hintStyle: TextStyle(
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w400,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        fillColor: AppColors.componentBackground,
                                        filled: true,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _selections[1] ? widget.onLocalFileSearch : null,
                                    icon: const Icon(Icons.upload_file),
                                    label: const Text('Chọn file'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Row 3: Serial Input and Port Selection (2 columns)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Column 1: Serial Input
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 8, bottom: 16),
                        decoration: BoxDecoration(
                          color: widget.isDarkTheme ? AppColors.darkPanelBackground : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Số Serial',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: widget.isDarkTheme ? AppColors.darkTextPrimary : AppColors.text
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        TextField(
                                          controller: widget.serialController,
                                          decoration: InputDecoration(
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                color: AppColors.borderColor,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                color: AppColors.borderColor,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                color: AppColors.primary,
                                                width: 1.5,
                                              ),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            fillColor: AppColors.componentBackground,
                                            filled: true,
                                            errorText: _serialErrorText,
                                            suffixIcon:
                                                _serialSuccessText != null
                                                    ? const Icon(
                                                      Icons.check_circle,
                                                      color: AppColors.success,
                                                    )
                                                    : null,
                                            hintText: 'Nhập số serial...',
                                            hintStyle: TextStyle(
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          onChanged: _validateSerial,
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
                                  const SizedBox(width: 8),
                                  Column(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _handleQrScan,
                                        icon: const Icon(Icons.edit),
                                        label: const Text('Nhập Serial'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.scanQr,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                      // Dynamic spacing for error/success messages
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        height: _serialErrorText != null || _serialSuccessText != null ? 20 : 0,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Column 2: Port Selection
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(left: 8, bottom: 16),
                        decoration: BoxDecoration(
                          color: widget.isDarkTheme ? AppColors.darkPanelBackground : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Cổng USB',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: widget.isDarkTheme ? AppColors.darkTextPrimary : AppColors.text
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildPortDropdown(context),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: widget.onUsbPortRefresh,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Làm mới'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: widget.isDarkTheme ? AppColors.accent : AppColors.secondary,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Row 4: Flash Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Builder(
                      builder: (context) {
                        final canFlash = widget.selectedPort != null &&
                            _isSerialValid &&
                            ((state.isLocalFileMode && state.localFilePath != null) ||
                             (!state.isLocalFileMode && widget.selectedFirmwareVersion != null));

                        if (canFlash != _canFlash) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              widget.onFlashStatusChanged(canFlash);
                            }
                          });
                        }

                        return Stack(
                          children: [
                            ElevatedButton(
                              key: ValueKey<bool>(canFlash),
                              onPressed: canFlash
                                ? () => widget.onWarningRequested('flash_firmware')
                                : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.flash,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                disabledBackgroundColor: Colors.grey[300],
                                disabledForegroundColor: Colors.grey[600],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.flash_on),
                                  SizedBox(width: 8),
                                  Text(
                                    'Nạp Firmware',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!canFlash)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Tooltip(
                                  message: _getDisabledReason(),
                                  child: const Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPortDropdown(BuildContext context) {
    final hasAvailablePorts = widget.availablePorts.isNotEmpty;

    final defaultItem = DropdownMenuItem<String>(
      value: null,
      child: Text(
        hasAvailablePorts ? 'Chọn cổng COM' : 'Không tìm thấy cổng COM',
        style: TextStyle(
          color: Colors.grey[600],
          fontWeight: FontWeight.w400,
        ),
      ),
    );

    final items = [
      defaultItem,
      if (hasAvailablePorts)
        ...widget.availablePorts.map((port) {
          return DropdownMenuItem<String>(
            value: port,
            child: Text(port),
          );
        }).toList(),
    ];

    return DropdownButtonFormField<String>(
      value: widget.availablePorts.contains(_pendingPort) ? _pendingPort : null,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.borderColor,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.borderColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        fillColor: AppColors.componentBackground,
        filled: true,
        hintText: hasAvailablePorts ? 'Chọn cổng COM' : 'Không tìm thấy cổng COM',
      ),
      icon: const Icon(
        Icons.arrow_drop_down,
        color: Colors.black87,
      ),
      dropdownColor: AppColors.componentBackground,
      style: const TextStyle(
        fontSize: 14,
        color: Colors.black87,
        fontWeight: FontWeight.w500,
      ),
      items: items,
      onChanged: _handlePortSelection,
    );
  }

  String _getDisabledReason() {
    final state = context.read<HomeBloc>().state;
    if (widget.selectedPort == null) {
      return 'Cổng USB chưa được chọn';
    }
    if (!_isSerialValid) {
      return 'Số serial không hợp lệ';
    }
    if (widget.isLocalFileMode && state.localFilePath == null) {
      return 'Chưa chọn file firmware';
    }
    if (!widget.isLocalFileMode && widget.selectedFirmwareVersion == null) {
      return 'Chưa chọn phiên bản firmware';
    }
    return '';
  }
}

