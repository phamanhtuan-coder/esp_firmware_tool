import 'package:equatable/equatable.dart';
import 'package:smart_net_firmware_loader/data/models/firmware.dart';
import 'package:smart_net_firmware_loader/data/services/batch_service.dart';
import 'package:smart_net_firmware_loader/data/services/planning_service.dart';
import 'package:smart_net_firmware_loader/data/services/usb_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/data/models/batch.dart';
import 'package:smart_net_firmware_loader/data/models/device.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/di/service_locator.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';

class LogEvent extends Equatable {
  const LogEvent();
  @override
  List<Object?> get props => [];
}

class LoadInitialDataEvent extends LogEvent {}
class SelectBatchEvent extends LogEvent {
  final String batchId;
  const SelectBatchEvent(this.batchId);
  @override
  List<Object?> get props => [batchId];
}
class SelectDeviceEvent extends LogEvent {
  final String deviceId;
  const SelectDeviceEvent(this.deviceId);
  @override
  List<Object?> get props => [deviceId];
}
class MarkDeviceDefectiveEvent extends LogEvent {
  final String deviceId;
  final String reason;
  const MarkDeviceDefectiveEvent(this.deviceId, {this.reason = ''});
  @override
  List<Object?> get props => [deviceId, reason];
}
class SelectUsbPortEvent extends LogEvent {
  final String port;
  const SelectUsbPortEvent(this.port);
  @override
  List<Object?> get props => [port];
}
class ScanUsbPortsEvent extends LogEvent {}
class InitiateFlashEvent extends LogEvent {
  final String deviceId;
  final String firmwareVersion;
  final String deviceSerial;
  final String deviceType;
  final String? localFilePath;
  const InitiateFlashEvent({
    required this.deviceId,
    required this.firmwareVersion,
    required this.deviceSerial,
    required this.deviceType,
    this.localFilePath,
  });
  @override
  List<Object?> get props => [deviceId, firmwareVersion, deviceSerial, deviceType, localFilePath];
}
class StopProcessEvent extends LogEvent {}
class ClearLogsEvent extends LogEvent {}
class FilterLogEvent extends LogEvent {
  final String? filter;
  const FilterLogEvent({this.filter});
  @override
  List<Object?> get props => [filter];
}
class SelectSerialEvent extends LogEvent {
  final String serial;
  const SelectSerialEvent(this.serial);
  @override
  List<Object?> get props => [serial];
}
class AutoScrollEvent extends LogEvent {}
class AddLogEvent extends LogEvent {
  final LogEntry log;
  const AddLogEvent(this.log);
  @override
  List<Object?> get props => [log];
}
class SelectLocalFileEvent extends LogEvent {
  final String filePath;
  const SelectLocalFileEvent(this.filePath);
  @override
  List<Object?> get props => [filePath];
}

class ClearLocalFileEvent extends LogEvent {}

class LoadBatchesForPlanningEvent extends LogEvent {
  final String planningId;
  const LoadBatchesForPlanningEvent(this.planningId);
  @override
  List<Object?> get props => [planningId];
}

class RefreshBatchDevicesEvent extends LogEvent {
  final String batchId;
  const RefreshBatchDevicesEvent(this.batchId);
  @override
  List<Object?> get props => [batchId];
}

class LoadBatchDataEvent extends LogEvent {
  final String batchId;
  final String planningId;
  const LoadBatchDataEvent(this.batchId, this.planningId);
  @override
  List<Object?> get props => [batchId, planningId];
}

class SwitchToVersionModeEvent extends LogEvent {
  const SwitchToVersionModeEvent();
}

class SwitchToLocalModeEvent extends LogEvent {
  const SwitchToLocalModeEvent();
}

class LogState extends Equatable {
  final List<Batch> batches;
  final List<Device> devices;
  final List<String> availablePorts;
  final List<LogEntry> filteredLogs;
  final String? selectedPlanningId;
  final String? selectedBatchId;
  final String? selectedDeviceId;
  final String? serialNumber;
  final String? selectedPort;
  final bool isFlashing;
  final String? status;
  final String? error;
  final String? localFilePath;
  final List<String> serialBuffer;
  final List<Firmware> firmwares;
  final int? selectedTemplateId;
  final List<LogEntry> logs;
  final String? selectedFirmwareVersion;
  final bool isLocalFileMode;

  const LogState({
    this.batches = const [],
    this.devices = const [],
    this.availablePorts = const [],
    this.filteredLogs = const [],
    this.selectedPlanningId,
    this.selectedBatchId,
    this.selectedDeviceId,
    this.serialNumber,
    this.selectedPort,
    this.isFlashing = false,
    this.status,
    this.error,
    this.localFilePath,
    this.serialBuffer = const [],
    this.firmwares = const [],
    this.selectedTemplateId,
    this.logs = const [],
    this.selectedFirmwareVersion,
    this.isLocalFileMode = false,
  });

  LogState copyWith({
    List<Batch>? batches,
    List<Device>? devices,
    List<String>? availablePorts,
    List<LogEntry>? filteredLogs,
    String? selectedPlanningId,
    String? selectedBatchId,
    String? selectedDeviceId,
    String? serialNumber,
    String? selectedPort,
    bool? isFlashing,
    String? status,
    String? error,
    String? localFilePath,
    List<String>? serialBuffer,
    List<Firmware>? firmwares,
    int? selectedTemplateId,
    List<LogEntry>? logs,
    String? selectedFirmwareVersion,
    bool? isLocalFileMode,
  }) {
    return LogState(
      batches: batches ?? this.batches,
      devices: devices ?? this.devices,
      availablePorts: availablePorts ?? this.availablePorts,
      filteredLogs: filteredLogs ?? this.filteredLogs,
      selectedPlanningId: selectedPlanningId ?? this.selectedPlanningId,
      selectedBatchId: selectedBatchId ?? this.selectedBatchId,
      selectedDeviceId: selectedDeviceId ?? this.selectedDeviceId,
      serialNumber: serialNumber ?? this.serialNumber,
      selectedPort: selectedPort ?? this.selectedPort,
      isFlashing: isFlashing ?? this.isFlashing,
      status: status ?? this.status,
      error: error ?? this.error,
      localFilePath: localFilePath ?? this.localFilePath,
      serialBuffer: serialBuffer ?? this.serialBuffer,
      firmwares: firmwares ?? this.firmwares,
      selectedTemplateId: selectedTemplateId ?? this.selectedTemplateId,
      logs: logs ?? this.logs,
      selectedFirmwareVersion: selectedFirmwareVersion ?? this.selectedFirmwareVersion,
      isLocalFileMode: isLocalFileMode ?? this.isLocalFileMode,
    );
  }

  @override
  List<Object?> get props => [
    batches,
    devices,
    availablePorts,
    filteredLogs,
    selectedPlanningId,
    selectedBatchId,
    selectedDeviceId,
    serialNumber,
    selectedPort,
    isFlashing,
    status,
    error,
    localFilePath,
    serialBuffer,
    firmwares,
    selectedTemplateId,
    logs,
    selectedFirmwareVersion,
    isLocalFileMode,
  ];
}

class LogBloc extends Bloc<LogEvent, LogState> {
  final LogService _logService = serviceLocator<LogService>();
  final UsbService _usbService = serviceLocator<UsbService>();
  final BatchService _batchService = serviceLocator<BatchService>();

  LogBloc() : super(const LogState()) {
    on<LoadInitialDataEvent>(_onLoadInitialData);
    on<SelectBatchEvent>(_onSelectBatch);
    on<SelectDeviceEvent>(_onSelectDevice);
    on<MarkDeviceDefectiveEvent>(_onMarkDeviceDefective);
    on<SelectUsbPortEvent>(_onSelectUsbPort);
    on<ScanUsbPortsEvent>(_onScanUsbPorts);
    on<InitiateFlashEvent>(_onInitiateFlash);
    on<StopProcessEvent>(_onStopProcess);
    on<ClearLogsEvent>(_onClearLogs);
    on<FilterLogEvent>(_onFilterLog);
    on<SelectSerialEvent>(_onSelectSerial);
    on<AutoScrollEvent>(_onAutoScroll);
    on<AddLogEvent>(_onAddLog);
    on<SelectLocalFileEvent>(_onSelectLocalFile);
    on<ClearLocalFileEvent>((event, emit) {
      emit(state.copyWith(localFilePath: null));
    });
    on<LoadBatchesForPlanningEvent>(_onLoadBatchesForPlanning);
    on<RefreshBatchDevicesEvent>(_onRefreshBatchDevices);
    on<LoadBatchDataEvent>(_onLoadBatchData);
    on<SwitchToVersionModeEvent>((event, emit) {
      // Handle switching to version mode
      emit(state.copyWith(
        isLocalFileMode: false, // Disable local file mode
      ));
    });
    on<SwitchToLocalModeEvent>((event, emit) {
      // Handle switching to local mode
      emit(state.copyWith(
        isLocalFileMode: true, // Enable local file mode
      ));
    });
  }

  Future<void> _onLoadInitialData(LoadInitialDataEvent event, Emitter<LogState> emit) async {
    try {
      // Start scanning USB ports
      add(ScanUsbPortsEvent());

      // Log initialization
      add(AddLogEvent(LogEntry(
        message: 'Application initialized successfully',
        timestamp: DateTime.now(),
        level: LogLevel.info,
        step: ProcessStep.systemStart,
        origin: 'system',
      )));


      // We don't need to load all plannings, batches and devices here
      // They will be loaded when user selects specific planning/batch

      // Get available ports
      final ports = _usbService.getAvailablePorts();
      emit(state.copyWith(availablePorts: ports));

    } catch (e, stackTrace) {
      print('Error during initialization: $e');
      print(stackTrace);
    }
  }

  Future<void> _onSelectBatch(SelectBatchEvent event, Emitter<LogState> emit) async {
    // Clear previous device selection when changing batch
    emit(state.copyWith(
      selectedDeviceId: null,
      selectedBatchId: event.batchId,
    ));

    // Load both devices and firmwares for the new batch
    if (state.selectedPlanningId != null) {
      add(LoadBatchDataEvent(event.batchId, state.selectedPlanningId!));
    } else {
      add(AddLogEvent(LogEntry(
        message: 'Không thể tải dữ liệu batch: Planning ID không hợp lệ',
        timestamp: DateTime.now(),
        level: LogLevel.error,
        step: ProcessStep.productBatch,
        origin: 'system',
      )));
    }
  }

  Future<void> _onLoadBatchData(LoadBatchDataEvent event, Emitter<LogState> emit) async {
    try {
      final planningService = serviceLocator<PlanningService>();

      // Load both devices and firmwares
      final batchData = await planningService.loadBatchData(event.batchId, event.planningId);

      // Get current batch to check firmware_id
      final selectedBatch = state.batches.firstWhere(
        (batch) => batch.id == event.batchId,
        orElse: () => Batch(
          id: '',
          name: '',
          planningId: '',
          templateId: '',
        ),
      );

      // Get list of firmwares and find the default one
      final firmwares = batchData['firmwares'] as List<Firmware>;
      String? defaultFirmwareId;

      // If batch has firmware_id, use it
      if (selectedBatch.firmwareId != null) {
        defaultFirmwareId = selectedBatch.firmwareId.toString();
      } else {
        // Otherwise find first mandatory and approved firmware
        final defaultFirmware = firmwares.firstWhere(
          (fw) => fw.isMandatory && fw.isApproved,
          orElse: () => firmwares.firstWhere(
            (fw) => fw.isApproved,
            orElse: () => firmwares.isNotEmpty ? firmwares.first : Firmware(
              firmwareId: 0,
              version: '',
              name: '',
              filePath: '',
              templateId: 0,
              isMandatory: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              isDeleted: false,
              isApproved: false,
              templateName: '',
              templateIsDeleted: false,
              logs: [],
            ),
          ),
        );
        defaultFirmwareId = defaultFirmware.firmwareId.toString();
      }

      emit(state.copyWith(
        devices: batchData['devices'] as List<Device>,
        firmwares: firmwares,
        selectedTemplateId: batchData['templateId'] as int?,
        selectedBatchId: event.batchId,
        selectedFirmwareVersion: defaultFirmwareId,  // Set default firmware
      ));

      add(AddLogEvent(LogEntry(
        message: 'Đã tải ${batchData['devices'].length} thiết bị và ${firmwares.length} phiên bản firmware',
        timestamp: DateTime.now(),
        level: LogLevel.info,
        step: ProcessStep.productBatch,
        origin: 'system',
      )));

      // Log selected firmware version
      add(AddLogEvent(LogEntry(
        message: 'Đã chọn firmware mặc định: $defaultFirmwareId',
        timestamp: DateTime.now(),
        level: LogLevel.info,
        step: ProcessStep.selectFirmware,
        origin: 'system',
      )));
    } catch (e, stackTrace) {
      print('Error loading batch data: $e');
      print(stackTrace);

      add(AddLogEvent(LogEntry(
        message: 'Lỗi khi tải dữ liệu batch: $e',
        timestamp: DateTime.now(),
        level: LogLevel.error,
        step: ProcessStep.productBatch,
        origin: 'system',
      )));
    }
  }

  Future<void> _onLoadBatchesForPlanning(LoadBatchesForPlanningEvent event, Emitter<LogState> emit) async {
    try {
      final planningService = serviceLocator<PlanningService>();
      final batches = await planningService.fetchBatches(event.planningId);

      emit(state.copyWith(
        batches: batches,
        selectedPlanningId: event.planningId,  // Save planning ID
        // Clear previous selections when changing planning
        selectedBatchId: null,
        selectedDeviceId: null,
        devices: [],
        firmwares: [],
        selectedTemplateId: null,
      ));

    } catch (e, stackTrace) {
      print('Error loading batches: $e');
      print(stackTrace);

      add(AddLogEvent(LogEntry(
        message: 'Lỗi khi tải danh sách lô: $e',
        timestamp: DateTime.now(),
        level: LogLevel.error,
        step: ProcessStep.productBatch,
        origin: 'system',
      )));
    }
  }

  Future<void> _onSelectDevice(SelectDeviceEvent event, Emitter<LogState> emit) async {
    emit(state.copyWith(selectedDeviceId: event.deviceId));
  }

  Future<void> _onMarkDeviceDefective(MarkDeviceDefectiveEvent event, Emitter<LogState> emit) async {
    // Handle marking device as defective
    _logService.addLog(
      message: 'Device ${event.deviceId} marked as defective${event.reason.isNotEmpty ? ': ${event.reason}' : ''}',
      level: LogLevel.warning,
      step: ProcessStep.deviceStatus,
      origin: 'system',
    );
  }

  Future<void> _onSelectUsbPort(SelectUsbPortEvent event, Emitter<LogState> emit) async {
    emit(state.copyWith(selectedPort: event.port));
  }

  Future<void> _onScanUsbPorts(ScanUsbPortsEvent event, Emitter<LogState> emit) async {
    final ports = _usbService.getAvailablePorts();
    emit(state.copyWith(availablePorts: ports));
  }

  Future<void> _onInitiateFlash(InitiateFlashEvent event, Emitter<LogState> emit) async {
    print('DEBUG: _onInitiateFlash called, current isFlashing=${state.isFlashing}');

    // Always force isFlashing to true, creating a complete new state to ensure detection
    final newState = LogState(
      batches: state.batches,
      devices: state.devices,
      availablePorts: state.availablePorts,
      filteredLogs: state.filteredLogs,
      selectedPlanningId: state.selectedPlanningId,
      selectedBatchId: state.selectedBatchId,
      selectedDeviceId: state.selectedDeviceId,
      serialNumber: state.serialNumber,
      selectedPort: state.selectedPort,
      isFlashing: true, // Force this to true
      status: state.status,
      error: state.error,
      localFilePath: state.localFilePath,
      serialBuffer: state.serialBuffer,
      firmwares: state.firmwares,
      selectedTemplateId: state.selectedTemplateId,
      logs: state.logs,
      selectedFirmwareVersion: state.selectedFirmwareVersion,
      isLocalFileMode: state.isLocalFileMode,
    );

    print('DEBUG: Emitting new state with isFlashing=true');
    emit(newState);

    // Verify state update
    print('DEBUG: After emit in _onInitiateFlash: isFlashing=${newState.isFlashing}');

    // Add a log entry to track the process start
    add(AddLogEvent(LogEntry(
      message: 'Starting firmware flashing process',
      timestamp: DateTime.now(),
      level: LogLevel.info,
      step: ProcessStep.flash,
      origin: 'system',
    )));
  }

  Future<void> _onStopProcess(StopProcessEvent event, Emitter<LogState> emit) async {
    print('DEBUG: _onStopProcess called, current isFlashing=${state.isFlashing}');

    // Ensure clean state by emitting immediately
    emit(state.copyWith(isFlashing: false));

    // Add log entry for completion
    add(AddLogEvent(LogEntry(
      message: 'Firmware flashing process completed',
      timestamp: DateTime.now(),
      level: LogLevel.info,
      step: ProcessStep.flash,
      origin: 'system',
    )));

    print('DEBUG: After emit in _onStopProcess: isFlashing=false');
  }

  Future<void> _onClearLogs(ClearLogsEvent event, Emitter<LogState> emit) async {
    emit(state.copyWith(filteredLogs: []));
  }

  Future<void> _onFilterLog(FilterLogEvent event, Emitter<LogState> emit) async {
    if (event.filter == null || event.filter!.isEmpty) {
      // If no filter, show all logs
      emit(state.copyWith(filteredLogs: state.logs));
    } else {
      // Filter logs based on the search term
      final filteredLogs = state.logs.where((log) =>
        log.message.toLowerCase().contains(event.filter!.toLowerCase())
      ).toList();
      emit(state.copyWith(filteredLogs: filteredLogs));
    }
  }

  Future<void> _onSelectSerial(SelectSerialEvent event, Emitter<LogState> emit) async {
    emit(state.copyWith(serialNumber: event.serial));
  }

  Future<void> _onAutoScroll(AutoScrollEvent event, Emitter<LogState> emit) async {
    // Auto scroll handling is done in the UI
  }

  Future<void> _onAddLog(AddLogEvent event, Emitter<LogState> emit) async {
    final updatedLogs = List<LogEntry>.from(state.logs)..add(event.log);
    print('DEBUG: Adding log: ${event.log.message}, level: ${event.log.level}, total logs: ${updatedLogs.length}');
    emit(state.copyWith(
      logs: updatedLogs,
      filteredLogs: updatedLogs, // Ensure filteredLogs includes all logs
    ));
  }

  Future<void> _onSelectLocalFile(SelectLocalFileEvent event, Emitter<LogState> emit) async {
    emit(state.copyWith(localFilePath: event.filePath));
  }

  Future<void> _onRefreshBatchDevices(RefreshBatchDevicesEvent event, Emitter<LogState> emit) async {
    if (event.batchId.isNotEmpty) {
      final devices = await _batchService.fetchDevices(event.batchId);
      emit(state.copyWith(devices: devices));
    }
  }
}
