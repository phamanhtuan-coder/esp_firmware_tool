import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';
import 'package:smart_net_firmware_loader/data/models/device.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/arduino_service.dart';
import 'package:smart_net_firmware_loader/data/services/bluetooth_service.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:smart_net_firmware_loader/data/services/serial_monitor_service.dart';
import 'package:smart_net_firmware_loader/domain/blocs/home_bloc.dart';
import 'package:smart_net_firmware_loader/domain/blocs/logging_bloc.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/action_buttons.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/app_header.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/batch_selection_panel.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/console_terminal_widget.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/firmware_control_panel.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/serial_monitor_terminal_widget.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/warning_dialog.dart';
import 'package:get_it/get_it.dart';
import 'package:synchronized/synchronized.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with SingleTickerProviderStateMixin {
  final TextEditingController _serialController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  String? _selectedFirmwareVersion;
  String? _selectedPort;
  bool _isDarkTheme = false;
  final int _selectedBaudRate = 115200;

  final LogService _logService = GetIt.instance<LogService>();
  final ArduinoService _arduinoService = GetIt.instance<ArduinoService>();
  final BluetoothService _bluetoothService = GetIt.instance<BluetoothService>();
  final SerialMonitorService _serialMonitorService =
      GetIt.instance<SerialMonitorService>();

  bool _showWarningDialog = false;
  String _warningType = '';
  bool _canFlash = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<HomeBloc>().add(LoadInitialDataEvent());
    _initializeServices();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50) {
        context.read<LoggingBloc>().add(AutoScrollEvent());
      }
    });
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!mounted) return;
    if (_tabController.index != 1) {
      _serialMonitorService.stopMonitor();
    }
    setState(() {});
    _logService.addLog(
      message:
          'Switched to tab ${_tabController.index == 0 ? "Console Log" : "Serial Monitor"}',
      level: LogLevel.debug,
      step:
          _tabController.index == 0
              ? ProcessStep.consoleLog
              : ProcessStep.serialMonitor,
      origin: 'system',
    );
  }

  Future<void> _initializeServices() async {
    await _logService.initialize();
    await _bluetoothService.start(
      onSerialReceived: (serial) {
        _serialController.text = serial;
        context.read<HomeBloc>().add(SubmitSerialEvent(serial));
      },
    );
    _logService.addLog(
      message: 'Services initialized',
      level: LogLevel.info,
      step: ProcessStep.systemEvent,
      origin: 'system',
    );
  }

  @override
  void dispose() {
    _bluetoothService.stop();
    _serialController.dispose();
    _scrollController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _serialMonitorService.dispose();
    _logService.dispose();
    super.dispose();
  }

  void _startSerialMonitor(String serialNumber) {
    if (_selectedPort == null || _selectedPort!.isEmpty) {
      _logService.addLog(
        message: 'No COM port selected. Please select a COM port first.',
        level: LogLevel.warning,
        step: ProcessStep.serialMonitor,
        deviceId: serialNumber,
        origin: 'system',
      );
      return;
    }

    _logService.addLog(
      message:
          'Starting serial monitor for port $_selectedPort at $_selectedBaudRate baud',
      level: LogLevel.info,
      step: ProcessStep.serialMonitor,
      deviceId: serialNumber,
      origin: 'system',
    );

    _serialMonitorService.startMonitor(_selectedPort!, _selectedBaudRate);
    setState(() {
      _tabController.animateTo(1);
    });
  }

  void _handleFilePick() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ino', 'cpp'],
        allowMultiple: false,
        dialogTitle: 'Chọn file firmware',
      );

      if (!mounted || result == null || result.files.single.path == null)
        return;

      final filePath = result.files.single.path!;
      context.read<HomeBloc>().add(SelectLocalFileEvent(filePath));
      _logService.addLog(
        message: 'Selected firmware file: ${result.files.single.name}',
        level: LogLevel.info,
        step: ProcessStep.selectFirmware,
        origin: 'system',
      );
    } catch (e) {
      _logService.addLog(
        message: 'Error selecting file: $e',
        level: LogLevel.error,
        step: ProcessStep.selectFirmware,
        origin: 'system',
      );
    }
  }

  final _flashLock = Lock();

  Future<void> _flashFirmware(
    String deviceId,
    String deviceSerial,
    String deviceType,
    String? localFilePath,
  ) async {
    await _flashLock.synchronized(() async {
      if (_selectedPort == null || _selectedPort!.isEmpty) {
        _logService.addLog(
          message: 'No COM port selected. Please select a COM port first.',
          level: LogLevel.warning,
          step: ProcessStep.flash,
          origin: 'system',
        );
        return;
      }

      try {
        final success = await _arduinoService.compileAndFlash(
          sketchPath:
              localFilePath ??
              context.read<HomeBloc>().state.selectedFirmwareId!,
          port: _selectedPort!,
          deviceId: deviceSerial,
        );

        if (success) {
          _logService.addLog(
            message: '✅ Firmware upload successful',
            level: LogLevel.success,
            step: ProcessStep.flash,
            origin: 'system',
            deviceId: deviceSerial,
          );
          _startSerialMonitor(deviceSerial);
        } else {
          _logService.addLog(
            message: '❌ Firmware upload failed',
            level: LogLevel.error,
            step: ProcessStep.flash,
            origin: 'system',
            deviceId: deviceSerial,
          );
        }
      } catch (e) {
        _logService.addLog(
          message: 'Error flashing firmware: $e',
          level: LogLevel.error,
          step: ProcessStep.flash,
          origin: 'system',
          deviceId: deviceSerial,
        );
      }
    });
  }

  Widget _buildSerialMonitorTab(HomeState state) {
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

  void _handleWarningContinue() {
    setState(() {
      _showWarningDialog = false;
    });

    switch (_warningType) {
      case 'switch_to_local':
        context.read<HomeBloc>().add(SelectLocalFileEvent(null));
        break;
      case 'switch_to_version':
        context.read<HomeBloc>().add(SelectLocalFileEvent(null));
        break;
      case 'select_local_file':
        _handleFilePick();
        break;
      case 'version_change':
        if (_selectedFirmwareVersion != null) {
          context.read<HomeBloc>().add(
            SelectFirmwareEvent(_selectedFirmwareVersion),
          );
        }
        break;
      case 'manual_serial':
        if (_serialController.text.isNotEmpty) {
          context.read<HomeBloc>().add(
            SubmitSerialEvent(_serialController.text),
          );
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
        return 'Bạn đang chuyển sang chế độ upload file firmware cục bộ. Việc này có thể gây ra rủi ro nếu file không được kiểm tra. Bạn chịu hoàn toàn trách nhiệm với mọi vấn đề phát sinh. Tiếp tục?';
      case 'switch_to_version':
        return 'Bạn đang chuyển sang chế độ chọn version từ server. Mọi file firmware cục bộ sẽ bị xóa. Tiếp tục?';
      case 'select_local_file':
        return 'Bạn đang sử dụng file firmware cục bộ. Việc này có thể gây ra rủi ro nếu file không được kiểm tra. Bạn chịu hoàn toàn trách nhiệm với mọi vấn đề phát sinh. Tiếp tục?';
      case 'version_change':
        return 'Bạn đang thay đổi phiên bản firmware so với mặc định. Việc này có thể gây ra rủi ro nếu phiên bản không tương thích. Bạn chịu hoàn toàn trách nhiệm với mọi vấn đề phát sinh. Tiếp tục?';
      case 'manual_serial':
        return 'Bạn đang nhập serial thủ công thay vì quét QR code. Việc này có thể gây ra rủi ro nếu serial không chính xác. Bạn chịu hoàn toàn trách nhiệm với mọi vấn đề phát sinh. Tiếp tục?';
      default:
        return 'H����nh động này có thể gây ra rủi ro. Bạn có chắc muốn tiếp tục?';
    }
  }

  Widget _buildBatchDevicesTable(List<Device> devices) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _isDarkTheme ? AppColors.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isDarkTheme
                ? AppColors.darkHeaderBackground
                : AppColors.primary.withAlpha(25),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Text(
              'Danh sách thiết bị trong lô',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Serial')),
                DataColumn(label: Text('Trạng thái')),
                DataColumn(label: Text('Thao tác')),
              ],
              rows: devices.map((device) {
                // Since Device fields are non-nullable now, we don't need the null check
                final isSelected = device.serial == _serialController.text;
                return DataRow(
                  selected: isSelected,
                  cells: [
                    DataCell(Text(device.serial)),
                    DataCell(Text(_getStatusText(device.status))),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          color: AppColors.success,
                          onPressed: () => _updateDeviceStatus(device.id, 'firmware_uploading'),
                          tooltip: 'Xác nhận',
                        ),
                        IconButton(
                          icon: const Icon(Icons.error_outline),
                          color: AppColors.error,
                          onPressed: () => _updateDeviceStatus(device.id, 'error'),
                          tooltip: 'Báo lỗi',
                        ),
                      ],
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'firmware_uploading':
        return 'Sẵn sàng nạp firmware';
      case 'error':
        return 'Lỗi';
      default:
        return status;
    }
  }

  void _updateDeviceStatus(String deviceId, String status) {
    context.read<HomeBloc>().add(UpdateDeviceStatusEvent(deviceId, status));
  }

  void _handleFlashStatusChanged(bool canFlash) {
    setState(() {
      _canFlash = canFlash;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: _isDarkTheme ? AppColors.darkBackground : Colors.grey[50],
          appBar: AppHeader(
            isDarkTheme: _isDarkTheme,
            onThemeToggled: () => setState(() => _isDarkTheme = !_isDarkTheme),
          ),
          body: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        BatchSelectionPanel(
                          plannings: state.plannings,
                          batches: state.batches,
                          selectedPlanningId: state.selectedPlanningId,
                          selectedBatchId: state.selectedBatchId,
                          onPlanningSelected: (value) {
                            context.read<HomeBloc>().add(SelectPlanningEvent(value));
                          },
                          onBatchSelected: (value) {
                            context.read<HomeBloc>().add(SelectBatchEvent(value));
                          },
                          isDarkTheme: _isDarkTheme,
                        ),
                        if (state.devices.isNotEmpty)
                          _buildBatchDevicesTable(state.devices),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        FirmwareControlPanel(
                          isDarkTheme: _isDarkTheme,
                          selectedFirmwareVersion: state.selectedFirmwareId,
                          selectedPort: state.selectedPort,
                          serialController: _serialController,
                          isLocalFileMode: state.isLocalFileMode,
                          firmwares: state.firmwares,
                          availablePorts: state.availablePorts,
                          onFirmwareVersionSelected:
                              (value) => _handleWarningAction(
                                'version_change',
                                value: value,
                              ),
                          onUsbPortSelected: (value) {
                            setState(() => _selectedPort = value);
                            context.read<HomeBloc>().add(
                              SelectPortEvent(value),
                            );
                          },
                          onLocalFileSearch:
                              () => _handleWarningAction('select_local_file'),
                          onUsbPortRefresh:
                              () => context.read<HomeBloc>().add(
                                RefreshPortsEvent(),
                              ),
                          onSerialSubmitted:
                              (value) => _handleWarningAction('manual_serial'),
                          onQrCodeScan:
                              () => context.read<HomeBloc>().add(
                                StartQrScanEvent(),
                              ),
                          onQrCodeAvailabilityChanged:
                              (_) {}, // We don't need to track QR availability
                          onWarningRequested: _handleWarningAction,
                          onFlashStatusChanged: _handleFlashStatusChanged,
                        ),
                        const SizedBox(height: 16),
                        ActionButtons(
                          isDarkTheme: _isDarkTheme,
                          onClearLogs:
                              () => context.read<LoggingBloc>().add(
                                ClearLogsEvent(),
                              ),
                          onInitiateFlash: (
                            deviceId,
                            _,
                            deviceSerial,
                            deviceType,
                            localFilePath,
                          ) {
                            if (_canFlash) {
                              _flashFirmware(
                                deviceId,
                                deviceSerial,
                                deviceType,
                                localFilePath,
                              );
                            }
                          },
                          selectedPort: state.selectedPort,
                          selectedFirmwareVersion: state.selectedFirmwareId,
                          selectedDevice: state.selectedSerial,
                          deviceSerial: _serialController.text,
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                color:
                                    _isDarkTheme
                                        ? AppColors.darkTabBackground
                                        : Colors.grey[200],
                                child: TabBar(
                                  controller: _tabController,
                                  tabs: const [
                                    Tab(text: 'Console Log'),
                                    Tab(text: 'Serial Monitor'),
                                  ],
                                  labelColor:
                                      _isDarkTheme
                                          ? AppColors.accent
                                          : Colors.blue,
                                  unselectedLabelColor:
                                      _isDarkTheme
                                          ? AppColors.darkTextSecondary
                                          : Colors.grey,
                                  indicatorColor:
                                      _isDarkTheme
                                          ? AppColors.accent
                                          : Colors.blue,
                                ),
                              ),
                              Expanded(
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8.0),
                                      child: ConsoleTerminalWidget(
                                        scrollController: _scrollController,
                                        isActiveTab: _tabController.index == 0,
                                      ),
                                    ),
                                    _buildSerialMonitorTab(state),
                                  ],
                                ),
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
                      onCancel:
                          () => setState(() => _showWarningDialog = false),
                      onContinue: _handleWarningContinue,
                      title: _getWarningTitle(),
                      message: _getWarningMessage(),
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
