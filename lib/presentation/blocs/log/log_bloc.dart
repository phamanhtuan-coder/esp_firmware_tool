import 'package:equatable/equatable.dart';
import 'package:esp_firmware_tool/data/services/arduino_cli_service.dart';
import 'package:esp_firmware_tool/data/services/batch_service.dart';
import 'package:esp_firmware_tool/data/services/usb_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/data/models/batch.dart';
import 'package:esp_firmware_tool/data/models/device.dart';
import 'package:esp_firmware_tool/data/models/log_entry.dart';
import 'package:esp_firmware_tool/di/service_locator.dart';
import 'package:esp_firmware_tool/data/services/log_service.dart';

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
  const InitiateFlashEvent({
    required this.deviceId,
    required this.firmwareVersion,
    required this.deviceSerial,
    required this.deviceType,
  });
  @override
  List<Object?> get props => [deviceId, firmwareVersion, deviceSerial, deviceType];
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
  }

  Future<void> _onLoadInitialData(LoadInitialDataEvent event, Emitter<LogState> emit) async {
    final batches = await _batchService.fetchBatches();
    final ports = _usbService.getAvailablePorts();
    emit(state.copyWith(
      batches: batches.map((b) => Batch(id: int.parse(b['id']!), name: b['name']!)).toList(),
      availablePorts: ports,
    ));
  }

  Future<void> _onSelectBatch(SelectBatchEvent event, Emitter<LogState> emit) async {
    final serials = await _batchService.fetchSerialsForBatch(event.batchId);
    final devices = serials.map((serial) => Device(id: serial.hashCode, batchId: int.parse(event.batchId), serial: serial)).toList();
    emit(state.copyWith(selectedBatchId: event.batchId, devices: devices));
  }

  void _onSelectDevice(SelectDeviceEvent event, Emitter<LogState> emit) {
    final device = state.devices.firstWhere((device) => device.id.toString() == event.deviceId);
    emit(state.copyWith(selectedDeviceId: event.deviceId, serialNumber: device.serial));
  }

  void _onMarkDeviceDefective(MarkDeviceDefectiveEvent event, Emitter<LogState> emit) {
    final updatedDevices = state.devices.map((device) {
      if (device.id.toString() == event.deviceId) {
        return device.copyWith(status: 'defective', reason: event.reason);
      }
      return device;
    }).toList();
    emit(state.copyWith(devices: updatedDevices, status: 'Device ${event.deviceId} marked as defective'));
  }

  void _onSelectUsbPort(SelectUsbPortEvent event, Emitter<LogState> emit) {
    emit(state.copyWith(
      selectedPort: event.port,
      status: 'Selected port: ${event.port}'
    ));

    final logEntry = LogEntry(
      message: 'Selected COM port: ${event.port}',
      timestamp: DateTime.now(),
      level: LogLevel.info,
      step: ProcessStep.usbCheck,
      origin: 'system',
    );
    add(AddLogEvent(logEntry));
  }

  void _onScanUsbPorts(ScanUsbPortsEvent event, Emitter<LogState> emit) {
    final ports = _usbService.getAvailablePorts();
    emit(state.copyWith(status: 'Scanning ports...', availablePorts: ports));
  }

  Future<void> _onInitiateFlash(InitiateFlashEvent event, Emitter<LogState> emit) async {
    emit(state.copyWith(isFlashing: true, status: 'Compiling firmware for ${event.deviceSerial}...'));

    final arduinoCliService = serviceLocator<ArduinoCliService>();

    const String deviceType = 'arduino_uno_r3';
    final String fqbn = arduinoCliService.getBoardFqbn(deviceType);

    final String? selectedPort = state.selectedPort;

    if (selectedPort == null || selectedPort.isEmpty) {
      emit(state.copyWith(
        isFlashing: false,
        error: 'No COM port selected',
        status: 'Please select a COM port first'
      ));
      return;
    }

    final String sketchPath = state.localFilePath ?? 'lib/firmware_template/template.ino';

    final compileStartLog = LogEntry(
      message: 'Starting compilation of $sketchPath for Arduino UNO R3 ($fqbn)',
      timestamp: DateTime.now(),
      level: LogLevel.info,
      step: ProcessStep.compile,
      origin: 'system',
    );
    add(AddLogEvent(compileStartLog));

    emit(state.copyWith(status: 'Compiling Arduino UNO R3 firmware...'));
    final bool compileSuccess = await arduinoCliService.compileSketch(sketchPath, fqbn);

    if (!compileSuccess) {
      final compileFailLog = LogEntry(
        message: 'Compilation failed for $sketchPath',
        timestamp: DateTime.now(),
        level: LogLevel.error,
        step: ProcessStep.compile,
        origin: 'system',
      );
      add(AddLogEvent(compileFailLog));

      emit(state.copyWith(
        isFlashing: false,
        error: 'Compilation failed',
        status: 'Failed to compile firmware for ${event.deviceSerial}'
      ));
      return;
    }

    final compileSuccessLog = LogEntry(
      message: 'Compilation successful, starting upload to device on port $selectedPort',
      timestamp: DateTime.now(),
      level: LogLevel.info,
      step: ProcessStep.flash,
      origin: 'system',
    );
    add(AddLogEvent(compileSuccessLog));

    emit(state.copyWith(status: 'Uploading firmware to ${event.deviceSerial} on port $selectedPort...'));

    final bool uploadSuccess = await arduinoCliService.uploadSketch(sketchPath, selectedPort, fqbn);

    if (!uploadSuccess) {
      final uploadFailLog = LogEntry(
        message: 'Upload failed to device ${event.deviceSerial} on port $selectedPort',
        timestamp: DateTime.now(),
        level: LogLevel.error,
        step: ProcessStep.flash,
        origin: 'system',
      );
      add(AddLogEvent(uploadFailLog));

      emit(state.copyWith(
        isFlashing: false,
        error: 'Upload failed',
        status: 'Failed to upload firmware to ${event.deviceSerial}'
      ));
      return;
    }

    final uploadSuccessLog = LogEntry(
      message: 'Successfully flashed firmware to device ${event.deviceSerial} on port $selectedPort',
      timestamp: DateTime.now(),
      level: LogLevel.success,
      step: ProcessStep.flash,
      origin: 'system',
    );
    add(AddLogEvent(uploadSuccessLog));

    emit(state.copyWith(
      isFlashing: false,
      status: 'Successfully flashed firmware to ${event.deviceSerial}',
      error: null
    ));
  }

  void _onStopProcess(StopProcessEvent event, Emitter<LogState> emit) {
    emit(state.copyWith(isFlashing: false, status: 'Process stopped', error: null));
  }

  void _onClearLogs(ClearLogsEvent event, Emitter<LogState> emit) {
    emit(state.copyWith(filteredLogs: [], status: 'Logs cleared'));
  }

  void _onFilterLog(FilterLogEvent event, Emitter<LogState> emit) {
    final filtered = event.filter == null
        ? state.filteredLogs
        : state.filteredLogs
        .where((log) => log.message.toLowerCase().contains(event.filter!.toLowerCase()) || log.deviceId == event.filter)
        .toList();
    emit(state.copyWith(filteredLogs: filtered, status: 'Filtering logs for: ${event.filter ?? 'all'}'));
  }

  void _onSelectSerial(SelectSerialEvent event, Emitter<LogState> emit) {
    emit(state.copyWith(serialNumber: event.serial));
  }

  void _onAutoScroll(AutoScrollEvent event, Emitter<LogState> emit) {
    // Handle auto-scroll if needed
  }

  void _onAddLog(AddLogEvent event, Emitter<LogState> emit) {
    final updatedLogs = List<LogEntry>.from(state.filteredLogs)..add(event.log);
    emit(state.copyWith(filteredLogs: updatedLogs));
  }

  void _onSelectLocalFile(SelectLocalFileEvent event, Emitter<LogState> emit) {
    emit(state.copyWith(
      localFilePath: event.filePath,
      status: 'Selected local file: ${event.filePath}',
    ));
    final logEntry = LogEntry(
      message: 'Selected local file: ${event.filePath}',
      timestamp: DateTime.now(),
      level: LogLevel.info,
      step: ProcessStep.firmwareDownload,
      origin: 'system',
    );
    add(AddLogEvent(logEntry));
  }

  Future<void> _onLoadBatchesForPlanning(LoadBatchesForPlanningEvent event, Emitter<LogState> emit) async {
    final batches = await _batchService.fetchBatchesForPlanning(event.planningId);
    emit(state.copyWith(
      selectedPlanningId: event.planningId,
      batches: batches.map((b) => Batch(id: int.parse(b['id']!), name: b['name']!)).toList(),
    ));
  }
}