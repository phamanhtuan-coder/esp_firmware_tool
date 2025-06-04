import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:smart_net_firmware_loader/data/models/device.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/models/firmware.dart';
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
  final List<Firmware> firmwares;
  final int? defaultFirmwareId;

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
    required this.firmwares,
    this.defaultFirmwareId,
  });

  @override
  State<FirmwareControlPanel> createState() => _FirmwareControlPanelState();
}

class _FirmwareControlPanelState extends State<FirmwareControlPanel> {
  bool _isVersionButtonLoading = false;
  bool _isFileButtonLoading = false;
  bool _isQrCodeButtonLoading = false;
  bool _isRefreshButtonLoading = false;

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
        widget.onFirmwareVersionSelected(null); // Đặt selectedFirmwareVersion về null
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
      // Xử lý lỗi...
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
      return;
    }

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
      backgroundColor: Colors.blue.shade700,
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

  void _validateAndSubmitSerial(String value) {
    _validateSerial(value);
    if (_isSerialValid) {
      widget.onSerialSubmitted(value);
    }
  }

  void _validateSerial(String value) {
    if (value.isEmpty) {
      setState(() {
        _serialErrorText = 'Số serial không được để trống';
        _serialSuccessText = null;
      });
      return;
    }

    final state = context.read<LogBloc>().state;

    if (state.selectedBatchId == null) {
      setState(() {
        _serialErrorText = 'Vui lòng chọn lô sản xuất trước khi nhập serial';
        _serialSuccessText = null;
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

    final matchingDevice = state.devices.firstWhere(
      (device) => device.serial.trim().toLowerCase() == value.trim().toLowerCase(),
      orElse: () => Device(id: '', batchId: '', serial: ''),
    );

    if (matchingDevice.id.isEmpty) {
      setState(() {
        _serialErrorText = 'Serial $value không tồn tại trong lô ${state.selectedBatchId}';
        _serialSuccessText = null;
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

    switch (matchingDevice.status) {
      case 'firmware_uploading':
        setState(() {
          _serialSuccessText = '✅ Serial hợp lệ - Thiết bị sẵn sàng cho nạp firmware và Serial Monitor';
          _serialErrorText = null;
          _isSerialValid = true;
        });
        context.read<LogBloc>().add(SelectDeviceEvent(matchingDevice.id));
        break;

      case 'firmware_uploaded':
        setState(() {
          _serialSuccessText = '✅ Serial hợp lệ - Thiết bị đã hoàn thành nạp firmware';
          _serialErrorText = null;
        });
        context.read<LogBloc>().add(SelectDeviceEvent(matchingDevice.id));
        break;

      case 'firmware_upload':
        setState(() {
          _serialErrorText = '🔒 Serial chờ kích hoạt - Quét QR trên app mobile để kích hoạt';
          _serialSuccessText = null;
        });
        break;

      case 'pending':
        setState(() {
          _serialErrorText = '⚠️ Serial chờ kích hoạt - Quét QR trên app mobile để kích hoạt';
          _serialSuccessText = null;
        });
        break;

      case 'firmware_failed':
        setState(() {
          _serialErrorText = '❌ Thiết bị đã được đánh dấu lỗi firmware';
          _serialSuccessText = null;
        });
        break;

      case 'defective':
        setState(() {
          _serialErrorText = '❌ Thiết bị đã được đánh dấu lỗi';
          _serialSuccessText = null;
        });
        break;

      case 'in_progress':
        setState(() {
          _serialErrorText = '⚠️ Thiết bị còn trong giai đoạn lắp ráp';
          _serialSuccessText = null;
        });
        break;

      default:
        setState(() {
          _serialErrorText = '⚠️ Trạng thái thiết bị không hợp lệ: ${matchingDevice.status}';
          _serialSuccessText = null;
        });
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
                                      )
                                    : AppColors.darkCardBackground
                                : hasLocalFile
                                    ? AppColors.cardBackground.withOpacity(
                                        0.5,
                                      )
                                    : AppColors.cardBackground,
                            filled: true,
                            enabled:
                                !hasLocalFile && widget.firmwares.isNotEmpty,
                          ),
                          items: widget.firmwares.map((firmware) {
                            return DropdownMenuItem(
                              value: firmware.firmwareId.toString(),
                              child: Text(
                                '${firmware.name} (${firmware.version})${firmware.isMandatory ? " - Bắt buộc" : ""}',
                              ),
                            );
                          }).toList(),
                          onChanged: hasLocalFile
                              ? null
                              : (value) {
                                  if (value != null) {
                                    widget.onFirmwareVersionSelected(value);
                                  }
                                },
                          hint: Text(
                            hasLocalFile
                                ? 'Không khả dụng khi chọn file local'
                                : widget.firmwares.isEmpty
                                    ? 'Không có firmware khả dụng'
                                    : '-- Chọn phiên bản --',
                          ),
                        ),
                        if (!hasLocalFile &&
                            widget.selectedFirmwareVersion == null &&
                            widget.firmwares.isNotEmpty)
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
                    child: _buildLoadingButton(
                      isLoading: _isFileButtonLoading,
                      onPressed: widget.onLocalFileSearch,
                      text: 'Tìm File',
                      icon: Icons.search,
                      backgroundColor: AppColors.findFile,
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
                            suffixIcon: _serialSuccessText != null
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : null,
                          ),
                          onSubmitted: widget.onSerialSubmitted,
                          onChanged: _validateAndSubmitSerial,
                        ),
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

