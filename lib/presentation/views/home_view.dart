import 'dart:async';
import 'package:smart_net_firmware_loader/data/services/firmware_flash_service.dart';
import 'package:smart_net_firmware_loader/data/services/qr_code_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/arduino_cli_service.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:smart_net_firmware_loader/data/services/usb_service.dart';
import 'package:smart_net_firmware_loader/di/service_locator.dart';
import 'package:smart_net_firmware_loader/presentation/blocs/log/log_bloc.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/action_buttons.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/app_header.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/batch_selection_panel.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/console_terminal_widget.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/firmware_control_panel.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/search_bar.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/serial_monitor_terminal_widget.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/warning_dialog.dart';
import 'package:smart_net_firmware_loader/utils/app_colors.dart';

import '../../data/models/device.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with SingleTickerProviderStateMixin {
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  String? _selectedPlanning;
  String? _selectedBatch;
  String? _selectedDevice;
  String? _selectedFirmwareVersion;
  String? _selectedPort;
  bool _isDarkTheme = false;
  bool _isSearching = false;
  final TextEditingController _serialInputController = TextEditingController();
  final int _selectedBaudRate = 115200;
  final List<int> _baudRates = [
    300, 600, 1200, 2400, 4800, 9600, 19200,
    38400, 57600, 115200, 230400, 460800, 921600
  ];
  final LogService _logService = serviceLocator<LogService>();
  final UsbService _usbService = serviceLocator<UsbService>();
  final ArduinoCliService _arduinoCliService = serviceLocator<
      ArduinoCliService>();
  final QrCodeService _qrCodeService = serviceLocator<QrCodeService>();

  bool _showWarningDialog = false;
  String _warningType = '';
  bool _isLocalFileMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<LogBloc>().add(LoadInitialDataEvent());
    _initializeServices();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50) {
        context.read<LogBloc>().add(AutoScrollEvent());
      }
    });

    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!mounted) return;
    setState(() {});
    _logService.addLog(
      message: 'Đã chuyển sang tab ${_tabController.index == 0 ? "Console Log" : "Serial Monitor"}',
      level: LogLevel.debug,
      step: _tabController.index == 0 ? ProcessStep.consoleLog : ProcessStep.serialMonitor,
      origin: 'system',
    );
    print('DEBUG: Tab changed to ${_tabController.index}');
  }

  Future<void> _initializeServices() async {
    await _logService.initialize();
    _usbService.deviceStream.listen((event) {
      context.read<LogBloc>().add(ScanUsbPortsEvent());

      context.read<LogBloc>().add(
        AddLogEvent(
          LogEntry(
            message: event.connected
                ? '🔌 USB device connected: ${event.deviceId} on port ${event
                .port}'
                : '❌ USB device disconnected: ${event.deviceId}',
            timestamp: DateTime.now(),
            level: LogLevel.info,
            step: ProcessStep.systemEvent,
            origin: 'system',
            deviceId: event.deviceId,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _qrCodeService.stopScanning();
    _serialInputController.dispose();
    _serialController.dispose();
    _scrollController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _usbService.dispose();
    _logService.dispose();
    super.dispose();
  }

  void _startSerialMonitor(String serialNumber) async {
    final logService = serviceLocator<LogService>();

    if (_selectedPort == null || _selectedPort!.isEmpty) {
      logService.addLog(
        message: 'No COM port selected. Please select a COM port first.',
        level: LogLevel.warning,
        step: ProcessStep.serialMonitor,
        deviceId: serialNumber,
        origin: 'system',
      );
      return;
    }

    logService.addLog(
      message: 'Starting serial monitor for port $_selectedPort at $_selectedBaudRate baud',
      level: LogLevel.info,
      step: ProcessStep.serialMonitor,
      deviceId: serialNumber,
      origin: 'system',
    );

    final port = _selectedPort;

    if (port != null) {
      final cliSuccess = await logService.startSerialMonitor(
          port, _selectedBaudRate, serialNumber);

      if (!cliSuccess) {
        final nativeSuccess = await logService.startNativeSerialMonitor(
            port, _selectedBaudRate, serialNumber);

        if (!nativeSuccess) {
          await logService.startAlternativeSerialMonitor(
              port, _selectedBaudRate, serialNumber);
        }
      }

      setState(() {
        _tabController.animateTo(1);
      });

      logService.autoScroll = true;

      logService.addLog(
        message: 'Serial monitor connection established',
        level: LogLevel.serialOutput,
        step: ProcessStep.serialMonitor,
        deviceId: serialNumber,
        origin: 'serial-monitor',
        rawOutput: 'Serial monitor connection established',
      );
    } else {
      logService.addLog(
        message: 'No port found for device $serialNumber',
        level: LogLevel.error,
        step: ProcessStep.serialMonitor,
        deviceId: serialNumber,
        origin: 'system',
      );
    }
  }

  void _handleFilePick(BuildContext context) async {
    final FilePicker filePicker = FilePicker.platform;

    try {
      final result = await filePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ino', 'cpp'],
        allowMultiple: false,
        dialogTitle: 'Chọn file firmware',
      );

      if (!mounted) return;

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;

        setState(() => _selectedFirmwareVersion = null);

        context.read<LogBloc>().add(SelectLocalFileEvent(filePath));

        _logService.addLog(
          message: 'File firmware đã được chọn: ${result.files.single.name}',
          level: LogLevel.info,
          step: ProcessStep.selectFirmware,
          origin: 'system',
        );
      }
    } catch (e) {
      _logService.addLog(
        message: 'Lỗi khi chọn file: $e',
        level: LogLevel.error,
        step: ProcessStep.selectFirmware,
        origin: 'system',
      );
    }
  }

  Future<void> _flashFirmware(
      String deviceId,
      String firmwareVersion,
      String deviceSerial,
      String deviceType,
      String? localFilePath
    ) async {
    final firmwareFlashService = serviceLocator<FirmwareFlashService>();
    localFilePath ??= context.read<LogBloc>().state.localFilePath;

    print('DEBUG: _flashFirmware called with:');
    print('DEBUG: deviceId: $deviceId');
    print('DEBUG: firmwareVersion: $firmwareVersion');
    print('DEBUG: deviceSerial: $deviceSerial');
    print('DEBUG: deviceType: $deviceType');
    print('DEBUG: localFilePath: $localFilePath');

    if (_selectedPort == null || _selectedPort!.isEmpty) {
      _logService.addLog(
        message: 'No COM port selected. Please select a COM port first.',
        level: LogLevel.warning,
        step: ProcessStep.flash,
        origin: 'system',
      );
      return;
    }

    // When using local file, we don't need to pass firmware version or batch ID
    final success = await firmwareFlashService.flash(
      serialNumber: deviceSerial,
      deviceType: deviceType,
      firmwareVersion: localFilePath != null ? '' : firmwareVersion,
      localFilePath: localFilePath,
      selectedBatch: localFilePath != null ? null : _selectedBatch,
      selectedPort: _selectedPort,
      onLog: (log) => _logService.addLog(
        message: log.message,
        level: log.level,
        step: log.step,
        origin: log.origin,
        deviceId: deviceSerial,
        rawOutput: log.rawOutput,
      ),
    );

    if (success) {
      _startSerialMonitor(deviceSerial);
    }

    // Reset flashing state
    context.read<LogBloc>().add(StopProcessEvent());
  }

  Widget _buildSerialMonitorTab(BuildContext context, LogState state) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      child: SerialMonitorTerminalWidget(
        initialPort: _selectedPort,
        initialBaudRate: _selectedBaudRate,
        autoStart: true,
        isActiveTab: _tabController.index == 1,
      ),
    );
  }

  void _handleWarningAction(String type, {String? value}) {
    setState(() {
      _showWarningDialog = true;
      _warningType = type;
    });
  }

  void _validateSerial(String value) {
    if (value.isEmpty) {
      return;
    }

    final state = context.read<LogBloc>().state;
    if (_selectedBatch != null) {
      final matchingDevice = state.devices.firstWhere(
        (device) => device.serial.trim().toLowerCase() == value.trim().toLowerCase(),
        orElse: () => Device(id: '', batchId: '', serial: ''),
      );

      if (matchingDevice.id.isNotEmpty) {
        if (matchingDevice.status == 'firmware_uploading') {
          setState(() => _selectedDevice = matchingDevice.id);
          context.read<LogBloc>().add(SelectDeviceEvent(matchingDevice.id));
        }
      }
    }
  }

  void _handleWarningContinue() {
    setState(() {
      _showWarningDialog = false;
    });

    switch (_warningType) {
      case 'switch_to_local':
        setState(() {
          _isLocalFileMode = true;
          _selectedFirmwareVersion = null;
          context.read<LogBloc>().add(ClearLocalFileEvent());
        });
        break;

      case 'switch_to_version':
        setState(() {
          _isLocalFileMode = false;
          context.read<LogBloc>().add(ClearLocalFileEvent());
        });
        break;

      case 'select_local_file':
        if (_isLocalFileMode) {
          _handleFilePick(context);
        }
        break;

      case 'version_change':
        if (!_isLocalFileMode) {
          // Don't clear the selectedFirmwareVersion since we're just changing it
          final value = context.read<LogBloc>().state.selectedFirmwareVersion;
          if (value != null) {
            setState(() {
              _selectedFirmwareVersion = value;
            });
          }
        }
        break;

      case 'manual_serial':
        if (_serialController.text.startsWith('QR_SCAN_')) {
          _validateSerial(_serialController.text);
        }
        break;
    }
  }

  String _getWarningTitle() {
    switch (_warningType) {
      case 'switch_to_local':
        return 'Chuyển sang chế độ Upload File';
      case 'switch_to_version':
        return 'Chuyển sang chế độ Chọn Version';
      case 'select_local_file':
        return 'Cảnh báo: Sử dụng File Cục Bộ';
      case 'version_change':
        return 'Cảnh báo: Thay đổi Phiên bản Firmware';
      case 'manual_serial':
        return 'Cảnh báo: Nhập Serial Thủ Công';
      default:
        return 'Cảnh báo';
    }
  }

  String _getWarningMessage() {
    switch (_warningType) {
      case 'switch_to_local':
        return 'Bạn đang chuyển sang ch�� độ upload file firmware cục bộ. Việc này có thể gây ra rủi ro nếu file không được kiểm tra. Bạn chịu hoàn toàn trách nhiệm với mọi vấn đề phát sinh. Tiếp tục?';
      case 'switch_to_version':
        return 'Bạn đang chuyển sang chế độ chọn version từ server. Mọi file firmware cục bộ sẽ bị xóa. Tiếp tục?';
      case 'select_local_file':
        return 'Bạn đang sử dụng file firmware cục bộ. Việc này có thể gây ra rủi ro nếu file không được kiểm tra. Bạn chịu hoàn toàn trách nhiệm với mọi vấn đề phát sinh. Tiếp tục?';
      case 'version_change':
        return 'Bạn đang thay đổi phiên bản firmware so với mặc định. Việc này có thể gây ra rủi ro nếu phiên bản không tương thích. Bạn chịu hoàn toàn trách nhiệm với mọi vấn đề phát sinh. Tiếp tục?';
      case 'manual_serial':
        return 'Bạn đang nhập serial thủ công thay vì quét QR code. Việc này có thể gây ra rủi ro nếu serial không chính xác. Bạn chịu hoàn toàn trách nhiệm với mọi vấn đề phát sinh. Tiếp tục?';
      default:
        return 'Hành động này có thể gây ra rủi ro. Bạn có chắc muốn tiếp tục?';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LogBloc()..add(LoadInitialDataEvent()),
      child: BlocBuilder<LogBloc, LogState>(
        builder: (context, state) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _isDarkTheme ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
              backgroundColor: _isDarkTheme ? AppColors.darkBackground : Colors.grey[50],
              appBar: AppHeader(
                isDarkTheme: _isDarkTheme,
                onThemeToggled: () => setState(() => _isDarkTheme = !_isDarkTheme),
              ),
              body: Stack(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: BatchSelectionPanel(
                          batches: state.batches,
                          devices: state.devices,
                          selectedBatch: _selectedBatch,
                          selectedDevice: _selectedDevice,
                          selectedPlanning: _selectedPlanning,
                          onBatchSelected: (value) {
                            setState(() => _selectedBatch = value);
                            context.read<LogBloc>().add(
                                SelectBatchEvent(value!));
                          },
                          onDeviceSelected: (value) {
                            setState(() => _selectedDevice = value);
                            context.read<LogBloc>().add(
                                SelectDeviceEvent(value!));
                          },
                          onPlanningSelected: (value) {
                            setState(() {
                              _selectedPlanning = value;
                              _selectedBatch = null;
                            });
                            context.read<LogBloc>().add(
                                LoadBatchesForPlanningEvent(value!));
                          },
                          onDeviceMarkDefective: (device) {
                            context.read<LogBloc>().add(
                                MarkDeviceDefectiveEvent(
                                    device.id.toString(), reason: ''));
                          },
                          isDarkTheme: _isDarkTheme,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            FirmwareControlPanel(
                              isDarkTheme: _isDarkTheme,
                              selectedFirmwareVersion: _selectedFirmwareVersion,
                              selectedPort: _selectedPort,
                              serialController: _serialController,
                              onFirmwareVersionSelected: (value) {
                                setState(() => _selectedFirmwareVersion = value);
                              },
                              onUsbPortSelected: (value) {
                                setState(() => _selectedPort = value);
                                context.read<LogBloc>().add(SelectUsbPortEvent(value!));
                              },
                              onLocalFileSearch: () => _handleFilePick(context),
                              onUsbPortRefresh: () {
                                context.read<LogBloc>().add(ScanUsbPortsEvent());
                                _usbService.getAvailablePorts();
                              },
                              onSerialSubmitted: (value) {
                                if (value.isNotEmpty) {
                                  context.read<LogBloc>().add(SelectSerialEvent(value));
                                  _serialController.text = value;

                                  if (_selectedBatch != null) {
                                    final matchingDevice = state.devices
                                        .firstWhere(
                                          (device) {
                                        return device.serial
                                            .trim()
                                            .toLowerCase() ==
                                            value.trim().toLowerCase();
                                      },
                                      orElse: () =>
                                          Device(
                                              id: '', batchId: '', serial: ''),
                                    );

                                    if (matchingDevice.id.isNotEmpty) {
                                      if (matchingDevice.status ==
                                          'firmware_uploading') {
                                        setState(() =>
                                        _selectedDevice = matchingDevice.id);
                                        context.read<LogBloc>().add(
                                            SelectDeviceEvent(
                                                matchingDevice.id));

                                        _startSerialMonitor(value);
                                      } else if (matchingDevice.status ==
                                          'firmware_upload') {
                                        _logService.addLog(
                                          message: 'Serial $value chưa được kích hoạt để nạp firmware',
                                          level: LogLevel.warning,
                                          step: ProcessStep.deviceSelection,
                                          origin: 'system',
                                        );
                                      } else if (matchingDevice.status ==
                                          'in_progress') {
                                        _logService.addLog(
                                          message: 'Serial $value còn trong giai đoạn lắp ráp',
                                          level: LogLevel.warning,
                                          step: ProcessStep.deviceSelection,
                                          origin: 'system',
                                        );
                                      } else if (matchingDevice.status ==
                                          'firmware_failed') {
                                        _logService.addLog(
                                          message: 'Serial $value đã được đánh dấu lỗi firmware trước đó',
                                          level: LogLevel.error,
                                          step: ProcessStep.deviceSelection,
                                          origin: 'system',
                                        );
                                      } else {
                                        _logService.addLog(
                                          message: 'Serial $value c�� trạng thái không hợp lệ: ${matchingDevice
                                              .status}',
                                          level: LogLevel.warning,
                                          step: ProcessStep.deviceSelection,
                                          origin: 'system',
                                        );
                                      }
                                    } else {
                                      _logService.addLog(
                                        message: 'Serial $value không tồn tại trong lô $_selectedBatch',
                                        level: LogLevel.warning,
                                        step: ProcessStep.deviceSelection,
                                        origin: 'system',
                                      );
                                    }
                                  } else {
                                    _logService.addLog(
                                      message: 'Vui lòng chọn lô sản xuất tr��ớc khi nhập serial',
                                      level: LogLevel.warning,
                                      step: ProcessStep.deviceSelection,
                                      origin: 'system',
                                    );
                                  }
                                }
                              },
                              onQrCodeScan: () async {
                                if (_selectedBatch == null) {
                                  _logService.addLog(
                                    message: 'Vui lòng chọn lô sản xu���t trước khi quét QR code',
                                    level: LogLevel.warning,
                                    step: ProcessStep.scanQrCode,
                                    origin: 'system',
                                  );
                                  return;
                                }

                                final completer = Completer<String?>();

                                final scannedSerial = await _qrCodeService
                                    .scanQrCode(
                                    onStatusChanged: (status) {
                                      if (status == QrScanStatus.success ||
                                          status == QrScanStatus.timeout ||
                                          status == QrScanStatus.error) {
                                        if (!completer.isCompleted) {
                                          if (status == QrScanStatus.success) {
                                            completer.complete("");
                                          } else {
                                            completer.complete(null);
                                          }
                                        }
                                      }
                                    }
                                );

                                await completer.future;

                                if (scannedSerial != null) {
                                  _serialController.text = scannedSerial;

                                  _logService.addLog(
                                    message: 'Đã nhận và xác th���c serial từ QR code: $scannedSerial',
                                    level: LogLevel.debug,
                                    step: ProcessStep.scanQrCode,
                                    origin: 'system',
                                  );
                                }
                              },
                              availablePorts: _usbService.getAvailablePorts(),
                              firmwares: state.firmwares,
                              isLocalFileMode: _isLocalFileMode,
                              onWarningRequested: _handleWarningAction,
                            ),
                            ActionButtons(
                              isDarkTheme: _isDarkTheme,
                              onClearLogs: () {
                                context.read<LogBloc>().add(ClearLogsEvent());
                              },
                              onInitiateFlash: (deviceId, firmwareVersion,
                                  deviceSerial, deviceType, localFilePath) {
                                _flashFirmware(
                                    deviceId, firmwareVersion, deviceSerial,
                                    deviceType, localFilePath);
                              },
                              isFlashing: state.isFlashing,
                              selectedPort: _selectedPort,
                              selectedFirmwareVersion: _selectedFirmwareVersion,
                              selectedDevice: _selectedDevice,
                              deviceSerial: _serialController.text,
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    color: _isDarkTheme ? AppColors
                                        .darkTabBackground : Colors.grey[200],
                                    child: TabBar(
                                      controller: _tabController,
                                      tabs: const [
                                        Tab(text: 'Console Log'),
                                        Tab(text: 'Serial Monitor'),
                                      ],
                                      labelColor: _isDarkTheme ? AppColors
                                          .accent : Colors.blue,
                                      unselectedLabelColor: _isDarkTheme
                                          ? AppColors.darkTextSecondary
                                          : Colors.grey,
                                      indicatorColor: _isDarkTheme ? AppColors
                                          .accent : Colors.blue,
                                    ),
                                  ),
                                  Expanded(
                                    child: TabBarView(
                                      controller: _tabController,
                                      children: [
                                        // Let ConsoleTerminalWidget handle the stream transformation internally
                                        Container(
                                          padding: const EdgeInsets.all(8.0),
                                          child: ConsoleTerminalWidget(
                                            logs: state.filteredLogs,
                                            scrollController: _scrollController,
                                            isActiveTab: _tabController.index == 0,
                                          ),
                                        ),
                                        _buildSerialMonitorTab(context, state),
                                      ],
                                    ),
                                  ),
                                  if (_isSearching)
                                    SearchBar(
                                      controller: _searchController,
                                      isDarkTheme: _isDarkTheme,
                                      onClose: () {
                                        setState(() => _isSearching = false);
                                        _searchController.clear();
                                        context.read<LogBloc>().add(
                                            const FilterLogEvent());
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_showWarningDialog)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: WarningDialog(
                          isDarkTheme: _isDarkTheme,
                          onCancel: () {
                            setState(() {
                              _showWarningDialog = false;
                            });
                          },
                          onContinue: _handleWarningContinue,
                          title: _getWarningTitle(),
                          message: _getWarningMessage(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

}
