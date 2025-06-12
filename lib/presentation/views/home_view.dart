import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
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
import 'package:smart_net_firmware_loader/domain/blocs/logging_bloc.dart';
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

    _initializeServices().then((_) {
      if (mounted) {
        context.read<HomeBloc>().add(LoadInitialDataEvent());
      }
    });
    _tabController.addListener(_handleTabChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDarkTheme = Theme.of(context).brightness == Brightness.dark;
  }

  void _handleTabChange() {
    if (!mounted) return;

    // Stop serial monitor when switching away from its tab
    if (_tabController.index != 1) {
      _serialMonitorService.stopMonitor();
      _logService.addLog(
        message: 'Switched to Console Log - Serial monitor stopped',
        level: LogLevel.info,
        step: ProcessStep.consoleLog,
        origin: 'system',
      );
    } else {
      // Switching to Serial Monitor tab
      _logService.addLog(
        message: 'Switched to Serial Monitor',
        level: LogLevel.info,
        step: ProcessStep.serialMonitor,
        origin: 'system',
      );
    }

    setState(() {});
  }

  Future<void> _initializeServices() async {
    try {
      _logService.addLog(
        message: 'Starting service initialization...',
        level: LogLevel.info,
        step: ProcessStep.systemStart,
        origin: 'system',
      );

      // Initialize Arduino service first since it's critical
      final cliInitialized = await _arduinoService.initialize();
      if (!cliInitialized) {
        throw Exception('Failed to initialize Arduino CLI');
      }
      _logService.addLog(
        message: 'Arduino CLI service initialized successfully',
        level: LogLevel.success,
        step: ProcessStep.systemStart,
        origin: 'system',
      );

      // Initialize BluetoothService with proper error handling
      try {
        await _bluetoothService.start(
          onSerialReceived: (serial) {
            if (mounted) {
              setState(() {
                _serialController.text = serial;
              });
              context.read<HomeBloc>().add(SubmitSerialEvent(serial));
            }
          },
        );
        _logService.addLog(
          message: 'Bluetooth service started successfully',
          level: LogLevel.success,
          step: ProcessStep.systemStart,
          origin: 'system',
        );
      } catch (e) {
        _logService.addLog(
          message: 'Warning: Bluetooth service failed to start: $e',
          level: LogLevel.warning,
          step: ProcessStep.systemStart,
          origin: 'system',
        );
        // Continue execution since Bluetooth is not critical
      }

      if (mounted) {
        context.read<HomeBloc>().add(LoadInitialDataEvent());
      }

      _logService.addLog(
        message: 'All services initialized successfully',
        level: LogLevel.success,
        step: ProcessStep.systemStart,
        origin: 'system',
      );
    } catch (e, stack) {
      _logService.addLog(
        message: 'Critical error during service initialization: $e\n$stack',
        level: LogLevel.error,
        step: ProcessStep.systemStart,
        origin: 'system',
      );
      rethrow;
    }
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
    print('DEBUG: Starting _flashFirmware');
    print('DEBUG: deviceId: $deviceId');
    print('DEBUG: deviceSerial: $deviceSerial');
    print('DEBUG: deviceType: $deviceType');
    print('DEBUG: localFilePath: $localFilePath');
    print('DEBUG: selectedPort: $_selectedPort');

    if (_selectedPort == null || _selectedPort!.isEmpty) {
      _logService.addLog(
        message: 'No COM port selected',
        level: LogLevel.warning,
        step: ProcessStep.flash,
        origin: 'system',
      );
      return;
    }

    // Validate required parameters
    if (deviceSerial.isEmpty) {
      _logService.addLog(
        message: 'Serial number is required',
        level: LogLevel.error,
        step: ProcessStep.flash,
        origin: 'system',
      );
      return;
    }

    setState(() => _isFlashing = true);

    try {
      String? sketchPath;
      print('DEBUG: Starting template preparation');

      final effectiveDeviceId = deviceId.isEmpty ? deviceSerial : deviceId;

      String boardType;
      String content;

      if (!localFilePath.isNullOrEmpty) {
        print('DEBUG: Processing local file: $localFilePath');
        final localFile = File(localFilePath!);
        if (!await localFile.exists()) {
          throw Exception('Local file not found: $localFilePath');
        }

        // First read the file content to detect board type
        content = await localFile.readAsString();
        boardType = _templateService.extractBoardType(content).toLowerCase();
        print('DEBUG: Detected board type from local file: $boardType');

        // Install core before processing template
        print('DEBUG: Installing core for board type: $boardType');
        final coreInstalled = await _arduinoService.installCore(boardType);
        if (!coreInstalled) {
          throw Exception('Failed to install core for board type: $boardType');
        }

        sketchPath = await _templateService.prepareFirmwareTemplate(
          localFilePath,
          deviceSerial,
          effectiveDeviceId,
          useQuotesForDefines: true,
        );

      } else {
        print('DEBUG: Processing firmware from state');
        final firmware = context.read<HomeBloc>().state.firmwares.firstWhere(
          (f) => f.firmwareId.toString() == context.read<HomeBloc>().state.selectedFirmwareId,
          orElse: () => throw Exception('Selected firmware not found'),
        );

        print('DEBUG: Found firmware: ${firmware.firmwareId}');
        content = firmware.filePath;

        // Detect board type from firmware content
        boardType = _templateService.extractBoardType(content).toLowerCase();
        print('DEBUG: Detected board type from firmware: $boardType');

        // Install core before saving to temp file
        print('DEBUG: Installing core for board type: $boardType');
        final coreInstalled = await _arduinoService.installCore(boardType);
        if (!coreInstalled) {
          throw Exception('Failed to install core for board type: $boardType');
        }

        // Save to temp file and process template
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(path.join(tempDir.path, 'firmware_${firmware.firmwareId}.ino'));
        await tempFile.writeAsString(content);
        print('DEBUG: Saved firmware to temp file: ${tempFile.path}');

        sketchPath = await _templateService.prepareFirmwareTemplate(
          tempFile.path,
          deviceSerial,
          effectiveDeviceId,
          useQuotesForDefines: true,
        );
      }

      if (sketchPath == null) {
        throw Exception('Failed to prepare firmware template');
      }

      // Try compiling and flashing with the detected board type
      print('DEBUG: Starting compile and flash');
      print('DEBUG: Sketch path: $sketchPath');
      print('DEBUG: Port: $_selectedPort');
      print('DEBUG: Device ID: $deviceSerial');
      print('DEBUG: Board type: $boardType');

      final success = await _arduinoService.compileAndFlash(
        sketchPath: sketchPath,
        port: _selectedPort!,
        deviceId: deviceSerial,
        deviceType: boardType,
      );

      print('DEBUG: Compile and flash result: $success');

      if (success) {
        _logService.addLog(
          message: '✅ Firmware flash completed successfully!',
          level: LogLevel.success,
          step: ProcessStep.flash,
          deviceId: deviceSerial,
          origin: 'system',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Nạp firmware thành công!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );

        // Start serial monitor after a small delay to let the device initialize
        Future.delayed(const Duration(milliseconds: 800), () {
          _startSerialMonitor(deviceSerial);
        });
      } else {
        throw Exception('Flashing failed - check Arduino CLI output in console');
      }
    } catch (e, stack) {
      print('DEBUG: Error in _flashFirmware: $e');
      print('DEBUG: Stack trace: $stack');

      _logService.addLog(
        message: 'Error during firmware flash: $e\nStack trace: $stack',
        level: LogLevel.error,
        step: ProcessStep.flash,
        deviceId: deviceSerial,
        origin: 'system',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi nạp firmware: ${e.toString()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      print('DEBUG: Flash firmware completed');
      // Ensure the flash button state is reset regardless of success or failure
      if (mounted) {
        // Reset flash button state with a small delay to ensure UI updates correctly
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _isFlashing = false;
              // Make sure _canFlash is updated to reflect current state
              _canFlash = _serialController.text.isNotEmpty &&
                  _selectedPort != null &&
                  (context.read<HomeBloc>().state.isLocalFileMode ?
                      context.read<HomeBloc>().state.localFilePath != null :
                      context.read<HomeBloc>().state.selectedFirmwareId != null);
            });
          }
        });
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
    if (!mounted) return;

    final state = context.read<HomeBloc>().state;

    if (type == 'flash_firmware') {
      print('DEBUG: Flash firmware requested');
      if (_canFlash && !_isFlashing) {
        print('DEBUG: Starting flash firmware process');
        _flashFirmware(
          state.selectedDeviceId ?? '',
          _serialController.text,
          state.selectedDeviceType ?? '',
          state.localFilePath,
        );
        return;
      } else {
        print('DEBUG: Cannot flash - canFlash: $_canFlash, isFlashing: $_isFlashing');
      }
      return;
    }

    setState(() {
      _showWarningDialog = true;
      _warningType = type;
    });
  }

  void _handleWarningContinue() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

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
    });
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
        return 'Bạn đang chuyển sang chế độ upload file firmware cục bộ. Việc này có thể gây ra rủi ro nếu file không được kiểm tra. Bạn ch���u hoàn toàn trách nhiệm với mọi vấn đề phát sinh. Tiếp tục?';
      case 'switch_to_version':
        return 'Bạn đang chuyển sang chế độ chọn version từ server. Mọi file firmware cục bộ sẽ được xóa bỏ. Tiếp tục?';
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
    print('DEBUG: Flash status changed: $canFlash');
    if (!mounted) return;
    setState(() {
      _canFlash = canFlash;
      print('DEBUG: _canFlash updated to: $_canFlash');
    });
  }

  Widget _buildConsoleSection() {
    return Column(
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
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Console Log Tab
              BlocProvider.value(
                value: context.read<LoggingBloc>(),
                child: ConsoleTerminalWidget(
                  isActiveTab: _tabController.index == 0,
                ),
              ),
              // Serial Monitor Tab
              BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  return _buildSerialMonitorTab(state);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handlePlanningSelected(String? value) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && value != null) {
        context.read<HomeBloc>().add(SelectPlanningEvent(value));
      }
    });
  }

  void _handleBatchSelected(String? value) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && value != null) {
        context.read<HomeBloc>().add(SelectBatchEvent(value));
      }
    });
  }

  void _handleUsbPortSelected(String? value) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _selectedPort = value);
        context.read<HomeBloc>().add(SelectPortEvent(value));
      }
    });
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left panel - Batch selection and devices list
                        SizedBox(
                          width: 400,
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
                                  onPlanningSelected: _handlePlanningSelected,
                                  onBatchSelected: _handleBatchSelected,
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
                          child: Column(
                            children: [
                              // Firmware Control Panel
                              Card(
                                margin: const EdgeInsets.all(8.0),
                                elevation: 4.0,
                                color: _isDarkTheme ? AppColors.darkCardBackground : AppColors.cardBackground,
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
                                  onUsbPortSelected: _handleUsbPortSelected,
                                  onLocalFileSearch: () => _handleWarningAction('select_local_file'),
                                  onUsbPortRefresh: () => context.read<HomeBloc>().add(RefreshPortsEvent()),
                                  onSerialSubmitted: (value) => _handleWarningAction('manual_serial'),
                                  onQrCodeScan: () {
                                    // Store current value for comparison to detect changes
                                    final currentSerialValue = _serialController.text;

                                    // Start QR scan via Bloc
                                    context.read<HomeBloc>().add(
                                      StartQrScanEvent(
                                        onSerialReceived: (receivedSerial) {
                                          // This callback will be called when a serial is received
                                          if (mounted) {
                                            setState(() {
                                              _serialController.text = receivedSerial;
                                              print("DEBUG: Serial controller updated in HomeView: $receivedSerial");
                                            });

                                            // Find FirmwareControlPanel widget and set QR flag
                                            final FirmwareControlPanel controlPanel =
                                                context.findAncestorWidgetOfExactType<FirmwareControlPanel>()!;

                                            // Instead of trying to access the private state directly,
                                            // let's pass a flag to the validateSerial function
                                            // This is done indirectly through our QR scan callback
                                            Future.microtask(() {
                                              // Add a small delay to ensure textfield update happens first
                                              // then trigger validation with QR flag
                                              controlPanel.serialController.notifyListeners();
                                            });
                                          }
                                        }
                                      )
                                    );
                                  },
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
                              // Console section fills remaining space
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                  decoration: BoxDecoration(
                                    color: _isDarkTheme ? AppColors.darkCardBackground : AppColors.cardBackground,
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, -2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: _isDarkTheme ? AppColors.darkTabBackground : AppColors.componentBackground,
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                        ),
                                        child: TabBar(
                                          controller: _tabController,
                                          tabs: const [
                                            Tab(text: 'Console Log'),
                                            Tab(text: 'Serial Monitor'),
                                          ],
                                          labelColor: _isDarkTheme ? AppColors.accent : Colors.blue,
                                          unselectedLabelColor: _isDarkTheme ? AppColors.darkTextSecondary : Colors.grey,
                                          indicatorColor: _isDarkTheme ? AppColors.accent : Colors.blue,
                                          indicatorWeight: 3,
                                        ),
                                      ),
                                      Expanded(
                                        child: TabBarView(
                                          controller: _tabController,
                                          children: [
                                            // Console Log Tab
                                            Builder(
                                              builder: (context) => BlocProvider.value(
                                                value: context.read<LoggingBloc>(),
                                                child: ConsoleTerminalWidget(
                                                  isActiveTab: _tabController.index == 0,
                                                  key: ValueKey(_tabController.index == 0),
                                                ),
                                              ),
                                            ),
                                            // Serial Monitor Tab
                                            _buildSerialMonitorTab(state),
                                          ],
                                        ),
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

