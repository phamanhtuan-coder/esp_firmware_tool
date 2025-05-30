import 'dart:async';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/data/models/log_entry.dart';
import 'package:esp_firmware_tool/data/services/arduino_cli_service.dart';
import 'package:esp_firmware_tool/data/services/batch_service.dart';
import 'package:esp_firmware_tool/data/services/log_service.dart';
import 'package:esp_firmware_tool/data/services/template_service.dart';
import 'package:esp_firmware_tool/data/services/usb_service.dart';
import 'package:esp_firmware_tool/di/service_locator.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';
import 'package:esp_firmware_tool/presentation/widgets/action_buttons.dart';
import 'package:esp_firmware_tool/presentation/widgets/app_header.dart';
import 'package:esp_firmware_tool/presentation/widgets/batch_selection_panel.dart';
import 'package:esp_firmware_tool/presentation/widgets/console_log_view.dart';
import 'package:esp_firmware_tool/presentation/widgets/firmware_control_panel.dart';
import 'package:esp_firmware_tool/presentation/widgets/search_bar.dart';
import 'package:esp_firmware_tool/presentation/widgets/serial_monitor_terminal_widget.dart';
import 'package:esp_firmware_tool/presentation/widgets/warning_dialog.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';

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
  String? _selectedBatch;
  String? _selectedDevice;
  String? _selectedFirmwareVersion;
  String? _selectedPort;
  bool _isDarkTheme = false;
  bool _isSearching = false;
  bool _localFileWarning = false;
  final TextEditingController _serialInputController = TextEditingController();
  int _selectedBaudRate = 115200;
  final List<int> _baudRates = [
    300, 600, 1200, 2400, 4800, 9600, 19200,
    38400, 57600, 115200, 230400, 460800, 921600
  ];
  final LogService _logService = serviceLocator<LogService>();
  final UsbService _usbService = serviceLocator<UsbService>();
  final ArduinoCliService _arduinoCliService = serviceLocator<ArduinoCliService>();
  final TemplateService _templateService = serviceLocator<TemplateService>();
  final BatchService _batchService = serviceLocator<BatchService>();

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
  }

  Future<void> _initializeServices() async {
    await _logService.initialize();
    _usbService.deviceStream.listen((event) {
      context.read<LogBloc>().add(ScanUsbPortsEvent());
      if (event.connected) {
        _batchService.registerUsbConnection(event.deviceId, event.port);
      } else {
        _batchService.registerUsbDisconnection(event.deviceId);
      }
    });
    _logService.logStream.listen((log) {
      context.read<LogBloc>().add(FilterLogEvent(filter: _searchController.text));
    });
  }

  @override
  void dispose() {
    _serialInputController.dispose();
    _serialController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    _usbService.dispose();
    _logService.dispose();
    super.dispose();
  }

  void _startSerialMonitor(String serialNumber) async {
    final logService = serviceLocator<LogService>();

    // Check if a port is selected
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

    // Log that we're starting the serial monitor with specific parameters
    logService.addLog(
      message: 'Starting serial monitor for port $_selectedPort at $_selectedBaudRate baud',
      level: LogLevel.info,
      step: ProcessStep.serialMonitor,
      deviceId: serialNumber,
      origin: 'system',
    );

    final port = _selectedPort;

    if (port != null) {
      // Try the arduino-cli monitor first as it's more reliable
      final cliSuccess = await logService.startSerialMonitor(port, _selectedBaudRate, serialNumber);

      if (!cliSuccess) {
        // If arduino-cli fails, try the native serial port monitor
        final nativeSuccess = await logService.startNativeSerialMonitor(port, _selectedBaudRate, serialNumber);

        if (!nativeSuccess) {
          // If both methods fail, try alternative methods as a last resort
          await logService.startAlternativeSerialMonitor(port, _selectedBaudRate, serialNumber);
        }
      }

      // Force the UI to refresh and show the tab with serial monitor
      setState(() {
        _tabController.animateTo(1); // Switch to the Serial Monitor tab (index 1)
      });

      // Set auto-scroll to true when starting a new monitor
      logService.autoScroll = true;

      // Add a test message to verify the stream is working
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
              backgroundColor: _isDarkTheme ? Colors.grey[900] : Colors.grey[50],
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
                          onBatchSelected: (value) {
                            setState(() => _selectedBatch = value);
                            context.read<LogBloc>().add(SelectBatchEvent(value!));
                          },
                          onDeviceSelected: (value) {
                            setState(() => _selectedDevice = value);
                            context.read<LogBloc>().add(SelectDeviceEvent(value!));
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
                              onFirmwareVersionSelected: (value) =>
                                  setState(() => _selectedFirmwareVersion = value),
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
                                  _startSerialMonitor(value);
                                }
                              },
                              onQrCodeScan: () {
                                final scannedSerial = 'SN-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
                                _serialController.text = scannedSerial;
                                context.read<LogBloc>().add(SelectSerialEvent(scannedSerial));
                                _startSerialMonitor(scannedSerial);
                              },
                              availablePorts: _usbService.getAvailablePorts(),
                            ),
                            ActionButtons(
                              isDarkTheme: _isDarkTheme,
                              onClearLogs: () {
                                context.read<LogBloc>().add(ClearLogsEvent());
                              },
                              onInitiateFlash: _flashFirmware,
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
                                    color: _isDarkTheme ? Colors.grey[700] : Colors.grey[200],
                                    child: TabBar(
                                      controller: _tabController,
                                      tabs: const [
                                        Tab(text: 'Console Log'),
                                        Tab(text: 'Serial Monitor'),
                                      ],
                                      labelColor: Colors.blue,
                                      unselectedLabelColor: Colors.grey,
                                      indicatorColor: Colors.blue,
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
                                                sink.add(currentLogs
                                                    .where((l) =>
                                                l.deviceId == state.serialNumber ||
                                                    l.deviceId.isEmpty)
                                                    .toList());
                                              },
                                            ),
                                          ),
                                          builder: (context, snapshot) {
                                            final logs = snapshot.data ??
                                                state.filteredLogs
                                                    .where((log) =>
                                                log.deviceId == state.serialNumber ||
                                                    log.deviceId.isEmpty)
                                                    .toList();
                                            return ConsoleLogView(
                                              logs: logs,
                                              scrollController: _scrollController,
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
                                        context.read<LogBloc>().add(FilterLogEvent());
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
                      onContinue: () => setState(() => _localFileWarning = false),
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
          color: _isDarkTheme ? Colors.grey.shade800 : Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.circle,
                size: 12,
                color: hasPortSelected ? AppColors.connected : AppColors.idle,
              ),
              const SizedBox(width: 8),
              Text(
                hasPortSelected
                    ? 'Connected to: $_selectedPort at $_selectedBaudRate baud'
                    : 'Not connected - Select a COM port first',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: hasPortSelected ? AppColors.success : AppColors.warning,
                ),
              ),
              const Spacer(),
              // Add display mode toggle and auto-scroll controls
              if (hasPortSelected) ...[
                ToggleButtons(
                  children: const [
                    Icon(Icons.text_fields, size: 18),
                    Icon(Icons.code, size: 18),
                    Icon(Icons.merge_type, size: 18),
                  ],
                  isSelected: [
                    _logService.serialDisplayMode == DataDisplayMode.ascii,
                    _logService.serialDisplayMode == DataDisplayMode.hex,
                    _logService.serialDisplayMode == DataDisplayMode.mixed,
                  ],
                  onPressed: (index) {
                    setState(() {
                      if (index == 0) {
                        _logService.setDisplayMode(DataDisplayMode.ascii);
                      } else if (index == 1) {
                        _logService.setDisplayMode(DataDisplayMode.hex);
                      } else {
                        _logService.setDisplayMode(DataDisplayMode.mixed);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  color: _isDarkTheme ? Colors.grey.shade400 : Colors.grey.shade600,
                  selectedColor: Colors.blue,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _logService.autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center,
                    color: _logService.autoScroll ? Colors.blue : Colors.grey,
                    size: 20,
                  ),
                  tooltip: _logService.autoScroll ? 'Auto-scroll enabled' : 'Auto-scroll disabled',
                  onPressed: () {
                    setState(() {
                      _logService.autoScroll = !_logService.autoScroll;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  tooltip: 'Clear serial monitor',
                  onPressed: () {
                    _logService.clearSerialBuffer();
                    setState(() {});
                  },
                ),
              ],
            ],
          ),
        ),

        // Controls Row
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<int>(
                  value: _selectedBaudRate,
                  decoration: InputDecoration(
                    labelText: 'Baud Rate',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    fillColor: _isDarkTheme ? AppColors.idle : AppColors.cardBackground,
                    filled: true,
                  ),
                  items: _baudRates.map((baud) => DropdownMenuItem(
                    value: baud,
                    child: Text(baud.toString()),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedBaudRate = value);
                      if (_selectedPort != null && _selectedPort!.isNotEmpty) {
                        _startSerialMonitor(_serialController.text);
                      }
                    }
                  },
                ),
              ),

              // Add Serial Monitor Terminal Widget below the controls
              const SizedBox(height: 8),
            ],
          ),
        ),

        // Terminal Widget Integration
        Expanded(
          child: Row(
            children: [
              // Left side: Standard log display
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: _isDarkTheme ? Colors.grey.shade900 : Colors.grey.shade200,
                      child: const Text("Standard Output", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: state.filteredLogs.where((log) =>
                          log.level == LogLevel.serialOutput &&
                          log.deviceId == state.serialNumber
                        ).length,
                        itemBuilder: (context, index) {
                          final logs = state.filteredLogs.where((log) =>
                            log.level == LogLevel.serialOutput &&
                            log.deviceId == state.serialNumber
                          ).toList();
                          final entry = logs[index];
                          return Text(
                            entry.rawOutput ?? entry.message,
                            style: TextStyle(
                              fontFamily: 'Courier New',
                              fontSize: 13,
                              color: entry.message.contains('Error') ? Colors.red : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Right side: Terminal widget
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: _isDarkTheme ? Colors.grey.shade900 : Colors.grey.shade200,
                      child: const Text("Terminal View", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: SerialMonitorTerminalWidget(
                        initialPort: _selectedPort,
                        initialBaudRate: _selectedBaudRate,
                        autoStart: hasPortSelected,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _flashFirmware(String deviceId, String firmwareVersion, String serialNumber, String deviceType) async {
    final port = await _arduinoCliService.getPortForDevice(serialNumber);
    if (port == null) {
      _logService.addLog(
        message: 'No port found for device $serialNumber',
        level: LogLevel.error,
        step: ProcessStep.flash,
        deviceId: serialNumber,
        origin: 'system',
      );
      return;
    }

    String? preparedPath;
    final logState = context.read<LogBloc>().state;

    if (logState.localFilePath != null) {
      _logService.addLog(
        message: 'Using local firmware file: ${logState.localFilePath}',
        level: LogLevel.info,
        step: ProcessStep.firmwareDownload,
        deviceId: serialNumber,
        origin: 'system',
      );

      preparedPath = await _templateService.prepareFirmwareTemplate(
        logState.localFilePath!,
        serialNumber,
        deviceId,
      );

      if (preparedPath == null) {
        _logService.addLog(
          message: 'Failed to prepare local firmware template for $serialNumber',
          level: LogLevel.error,
          step: ProcessStep.templatePreparation,
          deviceId: serialNumber,
          origin: 'system',
        );
        return;
      }
    } else if (firmwareVersion.isNotEmpty) {
      final firmwareData = await _batchService.fetchBatchFirmware(_selectedBatch ?? '');
      if (firmwareData.isEmpty) {
        _logService.addLog(
          message: 'No firmware data found for batch $_selectedBatch',
          level: LogLevel.error,
          step: ProcessStep.firmwareDownload,
          deviceId: serialNumber,
          origin: 'system',
        );
        return;
      }

      final sourceCode = firmwareData['sourceCode']!;
      final templatePath = await _templateService.getFirmwareTemplate(
        firmwareVersion,
        deviceType,
        sourceCode,
        null,
      );

      if (templatePath == null) {
        _logService.addLog(
          message: 'Failed to get firmware template for $firmwareVersion',
          level: LogLevel.error,
          step: ProcessStep.firmwareDownload,
          deviceId: serialNumber,
          origin: 'system',
        );
        return;
      }

      preparedPath = await _templateService.prepareFirmwareTemplate(
        templatePath,
        serialNumber,
        deviceId,
      );

      if (preparedPath == null) {
        _logService.addLog(
          message: 'Failed to prepare firmware template for $serialNumber',
          level: LogLevel.error,
          step: ProcessStep.templatePreparation,
          deviceId: serialNumber,
          origin: 'system',
        );
        return;
      }
    } else {
      _logService.addLog(
        message: 'No firmware version or local file selected',
        level: LogLevel.error,
        step: ProcessStep.firmwareDownload,
        deviceId: serialNumber,
        origin: 'system',
      );
      return;
    }

    final fqbn = _arduinoCliService.getBoardFqbn(deviceType.toLowerCase() == 'arduino uno r3' ? 'arduino_uno_r3' : deviceType);
    final success = await _batchService.compileAndFlash(preparedPath, port, fqbn, serialNumber);

    if (success) {
      _batchService.markDeviceProcessed(serialNumber, true);
      _logService.addLog(
        message: 'Firmware flashed successfully for $serialNumber',
        level: LogLevel.success,
        step: ProcessStep.flash,
        deviceId: serialNumber,
        origin: 'system',
      );
    } else {
      _batchService.markDeviceProcessed(serialNumber, false);
      _logService.addLog(
        message: 'Failed to flash firmware for $serialNumber',
        level: LogLevel.error,
        step: ProcessStep.flash,
        deviceId: serialNumber,
        origin: 'system',
      );
    }
  }
}