import 'package:esp_firmware_tool/data/models/device.dart';
import 'package:esp_firmware_tool/data/models/batch.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';
import 'package:esp_firmware_tool/presentation/widgets/action_buttons.dart';
import 'package:esp_firmware_tool/presentation/widgets/app_header.dart';
import 'package:esp_firmware_tool/presentation/widgets/batch_selection_panel.dart';
import 'package:esp_firmware_tool/presentation/widgets/console_log_view.dart';
import 'package:esp_firmware_tool/presentation/widgets/firmware_control_panel.dart';
import 'package:esp_firmware_tool/presentation/widgets/search_bar.dart';
import 'package:esp_firmware_tool/presentation/widgets/warning_dialog.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';
import 'package:esp_firmware_tool/utils/app_config.dart';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

class LogView extends StatefulWidget {
  const LogView({super.key});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<LogBloc>().add(LoadInitialDataEvent());
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
        context.read<LogBloc>().add(AutoScrollEvent());
      }
    });
  }

  @override
  void dispose() {
    _serialController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
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
                            context.read<LogBloc>().add(MarkDeviceDefectiveEvent(device.id.toString(), reason: ''));
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
                              onFirmwareVersionSelected: (value) => setState(() => _selectedFirmwareVersion = value),
                              onUsbPortSelected: (value) {
                                setState(() => _selectedPort = value);
                                context.read<LogBloc>().add(SelectUsbPortEvent(value!));
                              },
                              onLocalFileSearch: () => setState(() => _localFileWarning = true),
                              onUsbPortRefresh: () => context.read<LogBloc>().add(ScanUsbPortsEvent()),
                              onSerialSubmitted: (value) {
                                if (value.isNotEmpty) context.read<LogBloc>().add(SelectSerialEvent(value));
                              },
                              onQrCodeScan: () {
                                final scannedSerial = 'SN-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
                                _serialController.text = scannedSerial;
                                context.read<LogBloc>().add(SelectSerialEvent(scannedSerial));
                              },
                              availablePorts: state.availablePorts,
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
                                        Column(
                                          children: [
                                            Expanded(
                                              child: ConsoleLogView(
                                                logs: state.filteredLogs.where((log) => log.deviceId == state.serialNumber || log.deviceId.isEmpty).toList(),
                                                scrollController: _scrollController,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.only(bottom: 8.0), // Add padding to avoid overlap
                                              color: _isDarkTheme ? Colors.grey[900] : Colors.grey[50],
                                              child: ActionButtons(
                                                isDarkTheme: _isDarkTheme,
                                                onClearLogs: () => context.read<LogBloc>().add(ClearLogsEvent()),
                                                onInitiateFlash: (device, version, serial, type) {
                                                  context.read<LogBloc>().add(InitiateFlashEvent(
                                                    deviceId: device,
                                                    firmwareVersion: version,
                                                    deviceSerial: serial,
                                                    deviceType: type,
                                                  ));
                                                },
                                                isFlashing: state.isFlashing,
                                                selectedPort: _selectedPort,
                                                selectedFirmwareVersion: _selectedFirmwareVersion,
                                                selectedDevice: _selectedDevice,
                                                deviceSerial: _serialController.text,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Center(child: Text('No serial data to display', style: TextStyle(color: Colors.grey))),
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
}