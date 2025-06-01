import 'dart:async';
import 'package:smart_net_firmware_loader/data/services/bluetooth_server.dart';
import 'package:smart_net_firmware_loader/data/services/firmware_flash_service.dart';
import 'package:smart_net_firmware_loader/data/services/qr_code_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/arduino_cli_service.dart';
import 'package:smart_net_firmware_loader/data/services/batch_service.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:smart_net_firmware_loader/data/services/template_service.dart';
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
  final BluetoothServer _bluetoothServer = serviceLocator<BluetoothServer>();
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

    // Lắng nghe sự kiện thay đổi tab để theo dõi tab nào đang active
    _tabController.addListener(_handleTabChange);
  }

  // Theo dõi khi tab thay đổi
  void _handleTabChange() {
    // Đảm bảo không render lại UI khi tab index không thay đổi
    if (!mounted) return;
    setState(() {
      // Kích hoạt render lại để các tab biết trạng thái active của chúng
    });

    // Ghi log để debug
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

  // Helper method to log messages
  void _log(String message, {LogLevel level = LogLevel.info, String origin = 'system'}) {
    _logService.addLog(
      message: message,
      level: level,
      step: ProcessStep.scanQrCode,
      origin: origin,
    );
  }

  @override
  void dispose() {
    _qrCodeService.stopScanning();
    _serialInputController.dispose();
    _serialController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.removeListener(_handleTabChange);
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

        // When selecting a local file, clear any version selection
        setState(() => _selectedFirmwareVersion = null);

        // Add the file path to the bloc state
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
                              // Reset batch selection when planning changes
                              _selectedBatch = null;
                            });
                            // Load batches for the selected planning
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

                                  // Check if the entered serial exists in current batch
                                  if (_selectedBatch != null) {
                                    final matchingDevice = state.devices.firstWhere(
                                      (device) => device.serial == value,
                                      orElse: () => Device(id: -1, batchId: -1, serial: ''),
                                    );

                                    if (matchingDevice.id != -1) {
                                      // Serial found in the batch, select the device
                                      setState(() => _selectedDevice = matchingDevice.id.toString());
                                      context.read<LogBloc>().add(SelectDeviceEvent(matchingDevice.id.toString()));
                                    } else {
                                      // Serial not found in current batch
                                      _logService.addLog(
                                        message: 'Serial $value không tồn tại trong lô $_selectedBatch',
                                        level: LogLevel.warning,
                                        step: ProcessStep.deviceSelection,
                                        origin: 'system',
                                      );
                                    }
                                  }

                                  _startSerialMonitor(value);
                                }
                              },
                              onQrCodeScan: () async {
                                final scannedSerial = await _qrCodeService.scanQrCode();
                                if (scannedSerial != null) {
                                  _serialController.text = scannedSerial;

                                  // Check if the scanned serial exists in current batch
                                  if (_selectedBatch != null) {
                                    final matchingDevice = state.devices.firstWhere(
                                      (device) => device.serial == scannedSerial,
                                      orElse: () => Device(id: -1, batchId: -1, serial: ''),
                                    );

                                    if (matchingDevice.id != -1) {
                                      // Serial found in the batch, select the device
                                      setState(() => _selectedDevice = matchingDevice.id.toString());
                                      context.read<LogBloc>().add(SelectDeviceEvent(matchingDevice.id.toString()));
                                      context.read<LogBloc>().add(SelectSerialEvent(scannedSerial));
                                    } else {
                                      // Serial not found in current batch
                                      _logService.addLog(
                                        message: 'Serial $scannedSerial không tồn tại trong lô $_selectedBatch',
                                        level: LogLevel.warning,
                                        step: ProcessStep.scanQrCode,
                                        origin: 'system',
                                      );
                                    }
                                  }
                                }
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
                                                isActiveTab: _tabController.index == 0,  // Thêm dòng này
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

  void _flashFirmware(
      String deviceId,
      String firmwareVersion,
      String serialNumber,
      String deviceType,
      ) async {
    final logBloc = context.read<LogBloc>();
    log(LogEntry entry) => logBloc.add(AddLogEvent(entry));

    final flashService = FirmwareFlashService(
      _arduinoCliService,
      _templateService,
      _batchService,
      _usbService,
    );

    // Use a default firmware version if none is selected (to avoid empty string issues)
    final effectiveFirmwareVersion = firmwareVersion.isEmpty ? "default" : firmwareVersion;

    await flashService.flash(
      serialNumber: serialNumber,
      deviceType: deviceType,
      firmwareVersion: effectiveFirmwareVersion,
      localFilePath: logBloc.state.localFilePath,
      selectedBatch: _selectedBatch,
      selectedPort: _selectedPort,
      useQuotesForDefines: false, // Do not use quotes around serial numbers in #define
      onLog: log,
    );
  }

}



