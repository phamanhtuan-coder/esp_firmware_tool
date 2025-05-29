import 'dart:async';

import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/data/models/device.dart';
import 'package:esp_firmware_tool/data/models/batch.dart';
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
import 'package:esp_firmware_tool/presentation/widgets/warning_dialog.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';
import 'package:window_manager/window_manager.dart';

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

  // Dịch vụ từ service locator
  final LogService _logService = serviceLocator<LogService>();
  final UsbService _usbService = serviceLocator<UsbService>();
  final ArduinoCliService _arduinoCliService = serviceLocator<
      ArduinoCliService>();
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

  // Khởi tạo các dịch vụ
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
      context.read<LogBloc>().add(
          FilterLogEvent(filter: _searchController.text));
    });
  }

  @override
  void dispose() {
    _serialController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    _usbService.dispose();
    _logService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
      LogBloc()
        ..add(LoadInitialDataEvent()),
      child: BlocBuilder<LogBloc, LogState>(
        builder: (context, state) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _isDarkTheme ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
              backgroundColor: _isDarkTheme ? Colors.grey[900] : Colors
                  .grey[50],
              appBar: AppHeader(
                isDarkTheme: _isDarkTheme,
                onThemeToggled: () =>
                    setState(() => _isDarkTheme = !_isDarkTheme),
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
                            context.read<LogBloc>().add(
                                SelectBatchEvent(value!));
                          },
                          onDeviceSelected: (value) {
                            setState(() => _selectedDevice = value);
                            context.read<LogBloc>().add(
                                SelectDeviceEvent(value!));
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
                              onFirmwareVersionSelected: (value) =>
                                  setState(() =>
                                  _selectedFirmwareVersion = value),
                              onUsbPortSelected: (value) {
                                setState(() => _selectedPort = value);
                                context.read<LogBloc>().add(
                                    SelectUsbPortEvent(value!));
                              },
                              onLocalFileSearch: () =>
                                  setState(() => _localFileWarning = true),
                              onUsbPortRefresh: () {
                                context.read<LogBloc>().add(
                                    ScanUsbPortsEvent());
                                _usbService.getAvailablePorts();
                              },
                              onSerialSubmitted: (value) {
                                if (value.isNotEmpty) {
                                  context.read<LogBloc>().add(
                                      SelectSerialEvent(value));
                                  _startSerialMonitor(value);
                                }
                              },
                              onQrCodeScan: () {
                                final scannedSerial = 'SN-${DateTime
                                    .now()
                                    .millisecondsSinceEpoch
                                    .toString()
                                    .substring(6)}';
                                _serialController.text = scannedSerial;
                                context.read<LogBloc>().add(
                                    SelectSerialEvent(scannedSerial));
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
                                    color: _isDarkTheme
                                        ? Colors.grey[700]
                                        : Colors.grey[200],
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
                                        // Console Log
                                        StreamBuilder<List<LogEntry>>(
                                          stream: _logService.logStream
                                              .transform(
                                            StreamTransformer<LogEntry,
                                                List<LogEntry>>.fromHandlers(
                                              handleData: (log, sink) {
                                                final currentLogs = state
                                                    .filteredLogs.toList();
                                                currentLogs.add(log);
                                                sink.add(currentLogs
                                                    .where((l) =>
                                                l.deviceId ==
                                                    state.serialNumber ||
                                                    l.deviceId.isEmpty)
                                                    .toList());
                                              },
                                            ),
                                          ),
                                          builder: (context, snapshot) {
                                            final logs = snapshot.data ??
                                                state.filteredLogs
                                                    .where((log) =>
                                                log.deviceId ==
                                                    state.serialNumber ||
                                                    log.deviceId.isEmpty)
                                                    .toList();
                                            return ConsoleLogView(
                                              logs: logs,
                                              scrollController: _scrollController,
                                            );
                                          },
                                        ),
                                        // Serial Monitor
                                        StreamBuilder<List<LogEntry>>(
                                          stream: _logService.logStream
                                              .transform(
                                            StreamTransformer<LogEntry,
                                                List<LogEntry>>.fromHandlers(
                                              handleData: (log, sink) {
                                                final currentLogs = state
                                                    .filteredLogs.toList();
                                                currentLogs.add(log);
                                                sink.add(currentLogs
                                                    .where((l) =>
                                                l.step ==
                                                    ProcessStep.serialMonitor &&
                                                    l.deviceId ==
                                                        state.serialNumber)
                                                    .toList());
                                              },
                                            ),
                                          ),
                                          builder: (context, snapshot) {
                                            final serialLogs = snapshot.data ??
                                                state.filteredLogs
                                                    .where((log) =>
                                                log.step ==
                                                    ProcessStep.serialMonitor &&
                                                    log.deviceId ==
                                                        state.serialNumber)
                                                    .toList();
                                            return ConsoleLogView(
                                              logs: serialLogs,
                                              scrollController: _scrollController,
                                            );
                                          },
                                        ),
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
                                            FilterLogEvent());
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
                      onContinue: () =>
                          setState(() => _localFileWarning = false),
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

  // Khởi động serial monitor
  void _startSerialMonitor(String serialNumber) async {
    final port = await _arduinoCliService.getPortForDevice(serialNumber);
    if (port != null) {
      await _logService.startSerialMonitor(port, 115200, serialNumber);
    } else {
      _logService.addLog(
        message: 'No port found for device $serialNumber',
        level: LogLevel.error,
        step: ProcessStep.serialMonitor,
        deviceId: serialNumber,
        origin: 'system',
      );
    }
  }

  // Xử lý flash firmware
  void _flashFirmware(String deviceId, String firmwareVersion,
      String serialNumber, String deviceType) async {
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
    final logState = context
        .read<LogBloc>()
        .state;

    // Kiểm tra nếu có localFilePath
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
    } else {
      // Kiểm tra firmwareVersion chỉ khi không có local file
      if (firmwareVersion.isEmpty) {
        _logService.addLog(
          message: 'No firmware version selected',
          level: LogLevel.error,
          step: ProcessStep.firmwareDownload,
          deviceId: serialNumber,
          origin: 'system',
        );
        return;
      }

      // Lấy firmware template từ batch
      final firmwareData = await _batchService.fetchBatchFirmware(
          _selectedBatch ?? '');
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
    }

    // Biên dịch và flash firmware
    final fqbn = _arduinoCliService.getBoardFqbn(deviceType);
    final success = await _batchService.compileAndFlash(
        preparedPath, port, fqbn, serialNumber);

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