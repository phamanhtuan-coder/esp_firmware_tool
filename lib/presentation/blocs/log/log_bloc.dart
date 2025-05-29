import 'package:equatable/equatable.dart';
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

class LogState extends Equatable {
  final List<Batch> batches;
  final List<Device> devices;
  final List<String> availablePorts;
  final List<LogEntry> filteredLogs;
  final String? selectedBatchId;
  final String? selectedDeviceId;
  final String? serialNumber;
  final bool isFlashing;
  final String? status;
  final String? error;

  const LogState({
    this.batches = const [],
    this.devices = const [],
    this.availablePorts = const [],
    this.filteredLogs = const [],
    this.selectedBatchId,
    this.selectedDeviceId,
    this.serialNumber,
    this.isFlashing = false,
    this.status,
    this.error,
  });

  LogState copyWith({
    List<Batch>? batches,
    List<Device>? devices,
    List<String>? availablePorts,
    List<LogEntry>? filteredLogs,
    String? selectedBatchId,
    String? selectedDeviceId,
    String? serialNumber,
    bool? isFlashing,
    String? status,
    String? error,
  }) {
    return LogState(
      batches: batches ?? this.batches,
      devices: devices ?? this.devices,
      availablePorts: availablePorts ?? this.availablePorts,
      filteredLogs: filteredLogs ?? this.filteredLogs,
      selectedBatchId: selectedBatchId ?? this.selectedBatchId,
      selectedDeviceId: selectedDeviceId ?? this.selectedDeviceId,
      serialNumber: serialNumber ?? this.serialNumber,
      isFlashing: isFlashing ?? this.isFlashing,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
    batches,
    devices,
    availablePorts,
    filteredLogs,
    selectedBatchId,
    selectedDeviceId,
    serialNumber,
    isFlashing,
    status,
    error,
  ];
}

class LogBloc extends Bloc<LogEvent, LogState> {
  final LogService _logService = serviceLocator<LogService>();
  final UsbService _usbService = serviceLocator<UsbService>();

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
  }

  Future<void> _onLoadInitialData(LoadInitialDataEvent event, Emitter<LogState> emit) async {
    final batches = await _logService.fetchBatches();
    final ports = _usbService.getAvailablePorts();
    emit(state.copyWith(
      batches: batches.map((b) => Batch(id: int.parse(b['id']), name: b['name'])).toList(),
      availablePorts: ports,
    ));
  }

  void _onSelectBatch(SelectBatchEvent event, Emitter<LogState> emit) async {
    final serials = await _logService.fetchSerialsForBatch(event.batchId);
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
    emit(state.copyWith(status: 'Selected port: ${event.port}'));
  }

  void _onScanUsbPorts(ScanUsbPortsEvent event, Emitter<LogState> emit) {
    final ports = _usbService.getAvailablePorts();
    emit(state.copyWith(status: 'Scanning ports...', availablePorts: ports));
  }

  void _onInitiateFlash(InitiateFlashEvent event, Emitter<LogState> emit) {
    emit(state.copyWith(isFlashing: true, status: 'Flashing ${event.firmwareVersion} on ${event.deviceSerial}...'));
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
}