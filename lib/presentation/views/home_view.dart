import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';
import 'package:smart_net_firmware_loader/core/utils/string_extensions.dart';
import 'package:smart_net_firmware_loader/data/models/device.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/arduino_service.dart';
import 'package:smart_net_firmware_loader/data/services/bluetooth_service.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:smart_net_firmware_loader/data/services/serial_monitor_service.dart';
import 'package:smart_net_firmware_loader/data/services/template_service.dart';
import 'package:smart_net_firmware_loader/domain/blocs/home_bloc.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/app_header.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/batch_selection_panel.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/console_terminal_widget.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/firmware_control_panel.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/serial_monitor_terminal_widget.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/warning_dialog.dart';
import 'package:get_it/get_it.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/batch_devices_list_view.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/loading_overlay.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with SingleTickerProviderStateMixin {
  final TextEditingController _serialController = TextEditingController();
  late TabController _tabController;
  String? _selectedFirmwareVersion;
  String? _selectedPort;
  bool _isDarkTheme = false;
  final int _selectedBaudRate = 115200;

  final LogService _logService = GetIt.instance<LogService>();
  final ArduinoService _arduinoService = GetIt.instance<ArduinoService>();
  final BluetoothService _bluetoothService = GetIt.instance<BluetoothService>();
  final SerialMonitorService _serialMonitorService = GetIt.instance<SerialMonitorService>();
  final TemplateService _templateService;

  _HomeViewState() : _templateService = TemplateService(logService: GetIt.instance<LogService>());

  bool _showWarningDialog = false;
  String _warningType = '';
  bool _canFlash = false;
  bool _isFlashing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<HomeBloc>().add(LoadInitialDataEvent());
    _initializeServices();
    _tabController.addListener(_handleTabChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDarkTheme = Theme.of(context).brightness == Brightness.dark;
  }

  void _handleTabChange() {
    if (!mounted) return;
    if (_tabController.index != 1) {
      _serialMonitorService.stopMonitor();
    }
    if (mounted) {
      setState(() {});
    }
    _logService.addLog(
      message: 'Switched to tab ${_tabController.index == 0 ? "Console Log" : "Serial Monitor"}',
      level: LogLevel.debug,
      step: _tabController.index == 0 ? ProcessStep.consoleLog : ProcessStep.serialMonitor,
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
      message: 'Starting serial monitor for port $_selectedPort at $_selectedBaudRate baud',
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

      if (!mounted || result == null || result.files.single.path == null) return;

      final filePath = result.files.single.path!;

      // Delay state update using microtask to avoid build cycle issues
      Future.microtask(() {
        if (mounted) {
          context.read<HomeBloc>().add(SelectLocalFileEvent(filePath));
          _logService.addLog(
            message: 'Selected firmware file: ${result.files.single.name}',
            level: LogLevel.info,
            step: ProcessStep.selectFirmware,
            origin: 'system',
          );
        }
      });
    } catch (e) {
      _logService.addLog(
        message: 'Error selecting file: $e',
        level: LogLevel.error,
        step: ProcessStep.selectFirmware,
        origin: 'system',
      );
    }
  }


  Future<void> _flashFirmware(
      String deviceId,
      String deviceSerial,
      String deviceType,
      String? localFilePath,
  ) async {
    if (_selectedPort == null || _selectedPort!.isEmpty) {
      _logService.addLog(
        message: 'No COM port selected',
        level: LogLevel.warning,
        step: ProcessStep.flash,
        origin: 'system',
      );
      return;
    }

    setState(() => _isFlashing = true);

    try {
      String? sketchPath;
      String boardType = deviceType.toLowerCase(); // Default to provided device type

      _logService.addLog(
        message: 'Starting firmware flash process for device $deviceSerial',
        level: LogLevel.info,
        step: ProcessStep.flash,
        deviceId: deviceSerial,
        origin: 'system',
      );

      if (!localFilePath.isNullOrEmpty) {
        // Log template source
        final templateContent = await File(localFilePath!).readAsString();
        _logService.addLog(
          message: 'Processing local template file:\n$templateContent',
          level: LogLevel.info,
          step: ProcessStep.templatePreparation,
          deviceId: deviceSerial,
          origin: 'system',
        );

        // Xử lý template cho local file
        sketchPath = await _templateService.prepareFirmwareTemplate(
          localFilePath,
          deviceSerial,
          deviceId,
          useQuotesForDefines: true
        );

        if (sketchPath == null) throw Exception('Failed to prepare firmware template');

        // Read processed template to detect board type
        final processedContent = await File(sketchPath).readAsString();
        boardType = _templateService.extractBoardType(processedContent);
      } else {
        // Lấy firmware source code và xử lý template
        final firmware = context.read<HomeBloc>().state.firmwares.firstWhere(
          (f) => f.firmwareId.toString() == context.read<HomeBloc>().state.selectedFirmwareId,
          orElse: () => throw Exception('Selected firmware not found'),
        );

        _logService.addLog(
          message: 'Selected firmware: ${firmware.firmwareId}',
          level: LogLevel.info,
          step: ProcessStep.templatePreparation,
          deviceId: deviceSerial,
          origin: 'system',
        );

        // Xử lý template
        sketchPath = await _templateService.prepareFirmwareTemplate(
          firmware.filePath,
          deviceSerial,
          deviceId,
          useQuotesForDefines: true
        );

        if (sketchPath == null) throw Exception('Failed to prepare firmware template');

        // Read processed template to detect board type
        final processedContent = await File(sketchPath).readAsString();
        boardType = _templateService.extractBoardType(processedContent);
      }

      _logService.addLog(
        message: 'Template prepared successfully, detected board type: $boardType',
        level: LogLevel.success,
        step: ProcessStep.templatePreparation,
        deviceId: deviceSerial,
        origin: 'system',
      );

      // Proceed with compile and flash
      final success = await _arduinoService.compileAndFlash(
        sketchPath: sketchPath!,
        port: _selectedPort!,
        deviceId: deviceSerial,
        deviceType: boardType,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nạp firmware thành công!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Cập nhật trạng thái thiết bị
        context.read<HomeBloc>().add(
          StatusUpdateEvent(deviceSerial, true),
        );

        // Khởi động serial monitor
        _startSerialMonitor(deviceSerial);
      } else {
        throw Exception('Flashing failed');
      }
    } catch (e) {
      _logService.addLog(
        message: 'Error during firmware flash: $e',
        level: LogLevel.error,
        step: ProcessStep.flash,
        deviceId: deviceSerial,
        origin: 'system',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi nạp firmware: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );

      // Cập nhật trạng thái thiết bị thành thất bại
      context.read<HomeBloc>().add(
        StatusUpdateEvent(deviceSerial, false),
      );
    } finally {
      if (mounted) {
        setState(() => _isFlashing = false);
      }
    }
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
          context.read<HomeBloc>().add(SelectFirmwareEvent(_selectedFirmwareVersion!));
        }
        break;
      case 'manual_serial':
        if (_serialController.text.isNotEmpty) {
          context.read<HomeBloc>().add(SubmitSerialEvent(_serialController.text));
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
        return 'Cảnh báo: Thay đổi Phi����n bản Firmware';
      case 'manual_serial':
        return 'Cảnh báo: Nhập Serial Thủ Công';
      default:
        return 'Cảnh báo';
    }
  }

  String _getWarningMessage() {
    switch (_warningType) {
      case 'switch_to_local':
        return 'Bạn đang chuyển sang chế độ upload file firmware cục b��. Việc này có thể gây ra rủi ro nếu file không được kiểm tra. Bạn chịu hoàn toàn trách nhiệm với mọi vấn đề phát sinh. Tiếp tục?';
      case 'switch_to_version':
        return 'Bạn đang chuyển sang chế độ chọn version từ server. Mọi file firmware cục bộ sẽ được xóa bỏ. Tiếp tục?';
      case 'select_local_file':
        return 'Bạn đang sử d���ng file firmware cục bộ. Việc này có thể gây ra rủi ro nếu file không được kiểm tra. Bạn chịu hoàn toàn trách nhiệm với mọi vấn đề phát sinh. Tiếp tục?';
      case 'version_change':
        return 'Bạn đang thay đổi phiên b��n firmware so với mặc định. Việc này có thể gây ra rủi ro nếu phiên bản không tương thích. Bạn chịu hoàn toàn trách nhiệm với mọi vấn đề phát sinh. Tiếp tục?';
      case 'manual_serial':
        return 'Bạn đang nhập serial thủ công thay vì quét QR code. Việc này có thể gây ra rủi ro nếu serial không chính xác. Bạn chịu hoàn toàn trách nhiệm với mọi vấn đề phát sinh. Tiếp tục?';
      default:
        return 'Hành động này có thể gây ra rủi ro. Bạn có chắc muốn tiếp tục?';
    }
  }

  Widget _buildBatchDevicesTable(List<Device> devices) {
    return SizedBox(
      height: 300, // Fixed height for the device list container
      child: BatchDevicesListView(
        devices: devices,
        isDarkTheme: _isDarkTheme,
        selectedSerial: _serialController.text,
        onUpdateDeviceStatus: _updateDeviceStatus,
      ),
    );
  }

  void _updateDeviceStatus(String deviceId, String status) {
    context.read<HomeBloc>().add(UpdateDeviceStatusEvent(deviceId, status));
  }

  void _handleFlashStatusChanged(bool canFlash) {
    if (!mounted) return;
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _canFlash = canFlash;
        });
      }
    });
  }

  Widget _buildConsoleSection() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            color: _isDarkTheme ? AppColors.darkTabBackground : AppColors.componentBackground,
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
          SizedBox(
            height: 300,
            child: TabBarView(
              controller: _tabController,
              children: [
                ConsoleTerminalWidget(
                  isActiveTab: _tabController.index == 0,
                ),
                BlocBuilder<HomeBloc, HomeState>(
                  builder: (context, state) {
                    return _buildSerialMonitorTab(state);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeBloc, HomeState>(
      listenWhen: (previous, current) =>
        previous.showStatusDialog != current.showStatusDialog ||
        previous.statusDialogType != current.statusDialogType ||
        previous.statusDialogMessage != current.statusDialogMessage,
      listener: (context, state) {
        if (state.showStatusDialog) {
          showDialog(
            context: context,
            builder: (context) => WarningDialog(
              isDarkTheme: _isDarkTheme,
              onCancel: () {
                Navigator.of(context).pop();
                context.read<HomeBloc>().add(
                  CloseStatusDialogEvent(),
                );
              },
              onContinue: () {
                Navigator.of(context).pop();
                context.read<HomeBloc>().add(
                  CloseStatusDialogEvent(),
                );
              },
              title: state.statusDialogType == 'success' ? 'Thành công' : 'Lỗi',
              message: state.statusDialogMessage,
              type: state.statusDialogType,
            ),
          );
        }
      },
      builder: (context, state) {
        return LoadingOverlay(
          isLoading: _isFlashing,
          child: Scaffold(
            backgroundColor: _isDarkTheme ? AppColors.darkBackground : AppColors.background,
            appBar: AppHeader(
              isDarkTheme: _isDarkTheme,
              onThemeToggled: () => setState(() => _isDarkTheme = !_isDarkTheme),
            ),
            body: SafeArea(
              child: Stack(
                children: [
                  Container(
                    color: _isDarkTheme ? AppColors.darkBackground : AppColors.background,
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Left panel - Batch selection and devices list
                              SizedBox(
                                width: 400, // Fixed width for left panel
                                child: Card(
                                  margin: const EdgeInsets.all(8.0),
                                  elevation: 4.0,
                                  color: _isDarkTheme ? AppColors.darkCardBackground : AppColors.cardBackground,
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
                                        isLoading: state.isLoading,
                                      ),
                                      if (state.devices.isNotEmpty)
                                        Expanded(
                                          child: _buildBatchDevicesTable(state.devices),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              // Right panel - Controls and Console
                              Expanded(
                                child: Card(
                                  margin: const EdgeInsets.all(8.0),
                                  elevation: 4.0,
                                  color: _isDarkTheme ? AppColors.darkCardBackground : AppColors.cardBackground,
                                  child: Column(
                                    children: [
                                      // Firmware control panel with fixed height
                                      SizedBox(
                                        height: 460, // Fixed height for control panel
                                        child: FirmwareControlPanel(
                                          isDarkTheme: _isDarkTheme,
                                          selectedFirmwareVersion: state.selectedFirmwareId,
                                          selectedPort: state.selectedPort,
                                          serialController: _serialController,
                                          isLocalFileMode: state.isLocalFileMode,
                                          firmwares: state.firmwares,
                                          availablePorts: state.availablePorts,
                                          onFirmwareVersionSelected: (value) {
                                            _selectedFirmwareVersion = value;
                                            _handleWarningAction('version_change', value: value);
                                          },
                                          onUsbPortSelected: (value) {
                                            setState(() => _selectedPort = value);
                                            context.read<HomeBloc>().add(SelectPortEvent(value));
                                          },
                                          onLocalFileSearch: () => _handleWarningAction('select_local_file'),
                                          onUsbPortRefresh: () => context.read<HomeBloc>().add(RefreshPortsEvent()),
                                          onSerialSubmitted: (value) => _handleWarningAction('manual_serial'),
                                          onQrCodeScan: () => context.read<HomeBloc>().add(StartQrScanEvent()),
                                          onQrCodeAvailabilityChanged: (_) {},
                                          onWarningRequested: (type, {value}) {
                                            if (type == 'flash_firmware') {
                                              if (_canFlash) {
                                                _flashFirmware(
                                                  state.selectedDeviceId ?? '',
                                                  _serialController.text,
                                                  state.selectedDeviceType ?? '',
                                                  state.localFilePath,
                                                );
                                              }
                                            } else {
                                              _handleWarningAction(type, value: value);
                                            }
                                          },
                                          onFlashStatusChanged: _handleFlashStatusChanged,
                                        ),
                                      ),
                                      // Console section with remaining height in scrollview
                                      Expanded(
                                        child: _buildConsoleSection(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Overlay warning dialog in the center of the screen
                  if (_showWarningDialog)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: Center(
                          child: WarningDialog(
                            isDarkTheme: _isDarkTheme,
                            onCancel: () => setState(() => _showWarningDialog = false),
                            onContinue: _handleWarningContinue,
                            title: _getWarningTitle(),
                            message: _getWarningMessage(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

