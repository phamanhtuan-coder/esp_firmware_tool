import 'dart:async';
import 'package:smart_net_firmware_loader/data/models/batch.dart';
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
  bool _localFileWarning = false;
  bool _isSearching = false;
  final TextEditingController _serialInputController = TextEditingController();
  int _selectedBaudRate = 115200;
  final List<int> _baudRates = [
    300, 600, 1200, 2400, 4800, 9600, 19200,
    38400, 57600, 115200, 230400, 460800, 921600
  ];
  final LogService _logService = serviceLocator<LogService>();
  final UsbService _usbService = serviceLocator<UsbService>();
  final ArduinoCliService _arduinoCliService = serviceLocator<ArduinoCliService>();
  final QrCodeService _qrCodeService = serviceLocator<QrCodeService>();

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
  }

  Future<void> _initializeServices() async {
    await _logService.initialize();
    _usbService.deviceStream.listen((event) {
      context.read<LogBloc>().add(ScanUsbPortsEvent());

      context.read<LogBloc>().add(
        AddLogEvent(
          LogEntry(
            message: event.connected
                ? '🔌 USB device connected: ${event.deviceId} on port ${event.port}'
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
      final cliSuccess = await logService.startSerialMonitor(port, _selectedBaudRate, serialNumber);

      if (!cliSuccess) {
        final nativeSuccess = await logService.startNativeSerialMonitor(port, _selectedBaudRate, serialNumber);

        if (!nativeSuccess) {
          await logService.startAlternativeSerialMonitor(port, _selectedBaudRate, serialNumber);
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

  Future<void> _flashFirmware() async {
    if (_selectedPort == null || _selectedPort!.isEmpty) {
      _logService.addLog(
        message: 'No COM port selected. Please select a COM port first.',
        level: LogLevel.warning,
        step: ProcessStep.flash,
        origin: 'system',
      );
      return;
    }

    if (_selectedFirmwareVersion == null && _serialController.text.isEmpty) {
      _logService.addLog(
        message: 'No firmware version or serial number provided.',
        level: LogLevel.warning,
        step: ProcessStep.flash,
        origin: 'system',
      );
      return;
    }

    final deviceId = _selectedDevice ?? '';
    final deviceSerial = _serialController.text;

    // Get the device type from the device ID
    String deviceType = 'esp32'; // Default to ESP32
    if (deviceId.toLowerCase().contains('esp8266')) {
      deviceType = 'esp8266';
    } else if (deviceId.toLowerCase().contains('arduino')) {
      deviceType = 'arduino_uno';
    }

    // Start the flashing process
    context.read<LogBloc>().add(InitiateFlashEvent(
      deviceId: deviceId,
      firmwareVersion: _selectedFirmwareVersion ?? '',
      deviceSerial: deviceSerial,
      deviceType: deviceType,
    ));

    // Get the board type
    final boardFqbn = _arduinoCliService.getBoardFqbn(deviceType);

    // First try to compile
    _logService.addLog(
      message: 'Starting compilation...',
      level: LogLevel.info,
      step: ProcessStep.firmwareCompile,
      origin: 'system',
      deviceId: deviceSerial,
    );

    // Try to compile the sketch
    final compileSuccess = await _arduinoCliService.compileSketch(
      _selectedFirmwareVersion ?? '',
      boardFqbn,
      onLog: (log) => _logService.addLog(
        message: log.message,
        level: log.level,
        step: log.step,
        deviceId: deviceSerial,
        origin: log.origin,
        rawOutput: log.rawOutput,
      ),
    );

    if (!compileSuccess) {
      _logService.addLog(
        message: 'Compilation failed',
        level: LogLevel.error,
        step: ProcessStep.firmwareCompile,
        deviceId: deviceSerial,
        origin: 'system',
      );
      return;
    }

    // If compilation succeeded, start upload
    _logService.addLog(
      message: 'Starting upload...',
      level: LogLevel.info,
      step: ProcessStep.flash,
      deviceId: deviceSerial,
      origin: 'system',
    );

    final uploadSuccess = await _arduinoCliService.uploadSketch(
      _selectedFirmwareVersion ?? '',
      _selectedPort!,
      boardFqbn,
      onLog: (log) => _logService.addLog(
        message: log.message,
        level: log.level,
        step: log.step,
        deviceId: deviceSerial,
        origin: log.origin,
        rawOutput: log.rawOutput,
      ),
    );

    if (uploadSuccess) {
      _logService.addLog(
        message: 'Firmware upload completed successfully',
        level: LogLevel.success,
        step: ProcessStep.flash,
        deviceId: deviceSerial,
        origin: 'system',
      );

      // Start serial monitor after successful upload
      _startSerialMonitor(deviceSerial);
    } else {
      _logService.addLog(
        message: 'Firmware upload failed',
        level: LogLevel.error,
        step: ProcessStep.flash,
        deviceId: deviceSerial,
        origin: 'system',
      );
    }

    // Reset flashing state
    context.read<LogBloc>().add(StopProcessEvent());
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
                            context.read<LogBloc>().add(SelectBatchEvent(value!));
                          },
                          onDeviceSelected: (value) {
                            setState(() => _selectedDevice = value);
                            context.read<LogBloc>().add(SelectDeviceEvent(value!));
                          },
                          onPlanningSelected: (value) {
                            setState(() {
                              _selectedPlanning = value;
                              _selectedBatch = null;
                            });
                            context.read<LogBloc>().add(LoadBatchesForPlanningEvent(value!));
                          },
                          onDeviceMarkDefective: (device) {
                            context.read<LogBloc>().add(
                                MarkDeviceDefectiveEvent(device.id.toString(), reason: ''));
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
                              onLocalFileSearch: () => setState(() => _localFileWarning = true),
                              onUsbPortRefresh: () {
                                context.read<LogBloc>().add(ScanUsbPortsEvent());
                                _usbService.getAvailablePorts();
                              },
                              onSerialSubmitted: (value) {
                                if (value.isNotEmpty) {
                                  context.read<LogBloc>().add(SelectSerialEvent(value));
                                  _serialController.text = value;

                                  if (_selectedBatch != null) {
                                    final matchingDevice = state.devices.firstWhere(
                                      (device) {
                                        return device.serial.trim().toLowerCase() == value.trim().toLowerCase();
                                      },
                                      orElse: () => Device(id: '', batchId: '', serial: ''),
                                    );

                                    if (matchingDevice.id.isNotEmpty) {
                                      if (matchingDevice.status == 'firmware_uploading') {
                                        setState(() => _selectedDevice = matchingDevice.id);
                                        context.read<LogBloc>().add(SelectDeviceEvent(matchingDevice.id));

                                        _startSerialMonitor(value);
                                      } else if (matchingDevice.status == 'firmware_upload') {
                                        _logService.addLog(
                                          message: 'Serial $value chưa được kích hoạt để nạp firmware',
                                          level: LogLevel.warning,
                                          step: ProcessStep.deviceSelection,
                                          origin: 'system',
                                        );
                                      } else if (matchingDevice.status == 'in_progress') {
                                        _logService.addLog(
                                          message: 'Serial $value còn trong giai đoạn lắp ráp',
                                          level: LogLevel.warning,
                                          step: ProcessStep.deviceSelection,
                                          origin: 'system',
                                        );
                                      } else if (matchingDevice.status == 'firmware_failed') {
                                        _logService.addLog(
                                          message: 'Serial $value đã được đánh dấu lỗi firmware trước đó',
                                          level: LogLevel.error,
                                          step: ProcessStep.deviceSelection,
                                          origin: 'system',
                                        );
                                      } else {
                                        _logService.addLog(
                                          message: 'Serial $value có trạng thái không hợp lệ: ${matchingDevice.status}',
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
                                      message: 'Vui lòng chọn lô sản xuất trước khi nhập serial',
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
                                    message: 'Vui lòng chọn lô sản xuất trước khi quét QR code',
                                    level: LogLevel.warning,
                                    step: ProcessStep.scanQrCode,
                                    origin: 'system',
                                  );
                                  return;
                                }

                                final completer = Completer<String?>();

                                final scannedSerial = await _qrCodeService.scanQrCode(
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
                                    message: 'Đã nhận và xác thực serial từ QR code: $scannedSerial',
                                    level: LogLevel.debug,
                                    step: ProcessStep.scanQrCode,
                                    origin: 'system',
                                  );
                                }
                              },
                              availablePorts: _usbService.getAvailablePorts(),
                              firmwares: state.firmwares,
                              defaultFirmwareId: state.selectedBatchId != null
                                  ? state.batches.firstWhere(
                                      (batch) => batch.id == state.selectedBatchId,
                                      orElse: () => Batch(
                                        id: '',
                                        name: '',
                                        planningId: '',
                                        templateId: '',
                                      ),
                                    ).firmwareId
                                  : null,
                            ),
                            ActionButtons(
                              isDarkTheme: _isDarkTheme,
                              onClearLogs: () {
                                context.read<LogBloc>().add(ClearLogsEvent());
                              },
                              onInitiateFlash: (deviceId, firmwareVersion, deviceSerial, deviceType) {
                                _flashFirmware();
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
                                    color: _isDarkTheme ? AppColors.darkTabBackground : Colors.grey[200],
                                    child: TabBar(
                                      controller: _tabController,
                                      tabs: const [
                                        Tab(text: 'Console Log'),
                                        Tab(text: 'Serial Monitor'),
                                      ],
                                      labelColor: _isDarkTheme ? AppColors.accent : Colors.blue,
                                      unselectedLabelColor: _isDarkTheme ? AppColors.darkTextSecondary : Colors.grey,
                                      indicatorColor: _isDarkTheme ? AppColors.accent : Colors.blue,
                                    ),
                                  ),
                                  Expanded(
                                    child: TabBarView(
                                      controller: _tabController,
                                      children: [
                                        StreamBuilder<List<LogEntry>>(
                                          stream: _logService.logStream.transform(
                                            StreamTransformer<LogEntry, List<LogEntry>>.fromHandlers(
                                              handleData: (log, sink) {
                                                final currentLogs = state.filteredLogs.toList();
                                                currentLogs.add(log);
                                                sink.add(currentLogs);
                                              },
                                            ),
                                          ),
                                          builder: (context, snapshot) {
                                            final logs = snapshot.data ?? state.filteredLogs;
                                            return Container(
                                              padding: const EdgeInsets.all(8.0),
                                              child: ConsoleTerminalWidget(
                                                logs: logs,
                                                scrollController: _scrollController,
                                                isActiveTab: _tabController.index == 0,
                                              ),
                                            );
                                          },
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
                                        context.read<LogBloc>().add(const FilterLogEvent());
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
                  if (_localFileWarning)
                    WarningDialog(
                      isDarkTheme: _isDarkTheme,
                      onCancel: () => setState(() => _localFileWarning = false),
                      onContinue: () {
                        setState(() => _localFileWarning = false);
                        _handleFilePick(context);
                      },
                      title: 'Cảnh báo',
                      message: 'Tính năng chọn file local có thể gây ra lỗi không mong muốn. Bạn có chắc chắn muốn tiếp tục?',
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSerialMonitorTab(BuildContext context, LogState state) {
    final bool hasPortSelected = _selectedPort != null && _selectedPort!.isNotEmpty;

    return Column(
      children: [
        // Status bar for selected port and baud rate
        Container(
          color: _isDarkTheme ? AppColors.darkPanelBackground : Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // COM Port Status
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 12,
                    color: hasPortSelected ? AppColors.connected : AppColors.idle,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasPortSelected ? 'Connected to: $_selectedPort' : 'Not connected - Select a COM port',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: hasPortSelected ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              // Baud Rate Selector
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'Tốc độ Baud:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedBaudRate != 0 ? _selectedBaudRate : null,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          fillColor: _isDarkTheme ? AppColors.idle : AppColors.cardBackground,
                          filled: true,
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('Chọn tốc độ Baud'),
                          ),
                          ..._baudRates.map((baud) => DropdownMenuItem(
                            value: baud,
                            child: Text(baud.toString()),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedBaudRate = value ?? 0);
                          // Chỉ khởi động lại monitor khi tab đang active
                          if (_selectedPort != null && _selectedPort!.isNotEmpty && value != null && _tabController.index == 1) {
                            _startSerialMonitor(_serialController.text);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Terminal Widget fills remaining space
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SerialMonitorTerminalWidget(
              initialPort: _selectedPort,
              initialBaudRate: _selectedBaudRate,
              autoStart: hasPortSelected && _selectedBaudRate != 0,
              isActiveTab: _tabController.index == 1,  // Truyền trạng thái tab active
            ),
          ),
        ),
      ],
    );
  }
}

