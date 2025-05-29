import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:esp_firmware_tool/data/models/batch.dart';
import 'package:esp_firmware_tool/data/models/device.dart';
import 'package:esp_firmware_tool/data/models/log_entry.dart';

// Sample data (mimic React's SAMPLE_BATCHES and SAMPLE_DEVICES)
final List<Batch> SAMPLE_BATCHES = [
  Batch(id: 1, name: 'Batch A-001'),
  Batch(id: 2, name: 'Batch B-002'),
  Batch(id: 3, name: 'Batch C-003'),
];

final List<Device> SAMPLE_DEVICES = [
  Device(id: 1, batchId: 1, serial: 'SN001', status: 'pending'),
  Device(id: 2, batchId: 1, serial: 'SN002', status: 'pending'),
   Device(id: 3, batchId: 1, serial: 'SN003', status: 'pending'),
  Device(id: 4, batchId: 2, serial: 'SN004', status: 'pending'),
   Device(id: 5, batchId: 2, serial: 'SN005', status: 'pending'),
   Device(id: 6, batchId: 3, serial: 'SN006', status: 'pending'),
];

// Events
// log_bloc.dart (cập nhật một phần)
abstract class LogEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadInitialDataEvent extends LogEvent {}
class SelectBatchEvent extends LogEvent { final String batchId; SelectBatchEvent(this.batchId); @override List<Object?> get props => [batchId]; }
class SelectDeviceEvent extends LogEvent { final String deviceId; SelectDeviceEvent(this.deviceId); @override List<Object?> get props => [deviceId]; }
class MarkDeviceDefectiveEvent extends LogEvent { final String deviceId; final String? reason; MarkDeviceDefectiveEvent(this.deviceId, {this.reason}); @override List<Object?> get props => [deviceId, reason]; }
class SelectUsbPortEvent extends LogEvent { final String port; SelectUsbPortEvent(this.port); @override List<Object?> get props => [port]; }
class ScanUsbPortsEvent extends LogEvent {}
class InitiateFlashEvent extends LogEvent { final String deviceId; final String firmwareVersion; final String deviceSerial; final String deviceType; InitiateFlashEvent({required this.deviceId, required this.firmwareVersion, required this.deviceSerial, required this.deviceType}); @override List<Object?> get props => [deviceId, firmwareVersion, deviceSerial, deviceType]; }
class StopProcessEvent extends LogEvent {}
class ClearLogsEvent extends LogEvent {}
class FilterLogEvent extends LogEvent { final String? filter; FilterLogEvent({this.filter}); @override List<Object?> get props => [filter]; }
class SelectSerialEvent extends LogEvent { final String serial; SelectSerialEvent(this.serial); @override List<Object?> get props => [serial]; }
class AutoScrollEvent extends LogEvent {}

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
    batches, devices, availablePorts, filteredLogs, selectedBatchId, selectedDeviceId, serialNumber, isFlashing, status, error,
  ];
}

class LogBloc extends Bloc<LogEvent, LogState> {
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
  }

  Future<void> _onLoadInitialData(LoadInitialDataEvent event, Emitter<LogState> emit) async {
    await Future.delayed(const Duration(milliseconds: 100));
    emit(state.copyWith(
      batches: SAMPLE_BATCHES,
      devices: SAMPLE_DEVICES,
      availablePorts: ['COM1', 'COM2', 'COM3'],
    ));
  }

  void _onSelectBatch(SelectBatchEvent event, Emitter<LogState> emit) {
    final selectedBatch = state.batches.firstWhere((batch) => batch.id.toString() == event.batchId);
    final filteredDevices = SAMPLE_DEVICES.where((device) => device.batchId == selectedBatch.id).toList();
    emit(state.copyWith(selectedBatchId: event.batchId, devices: filteredDevices));
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
    emit(state.copyWith(status: 'Scanning ports...', availablePorts: ['COM1', 'COM2', 'COM3', 'COM4']));
  }

  void _onInitiateFlash(InitiateFlashEvent event, Emitter<LogState> emit) {
    emit(state.copyWith(isFlashing: true, status: 'Flashing ${event.firmwareVersion} on ${event.deviceSerial}...'));
    Future.delayed(const Duration(seconds: 3), () {
      if (state.isFlashing) {
        final success = DateTime.now().second % 2 == 0;
        add(success ? ClearLogsEvent() : StopProcessEvent());
        emit(state.copyWith(
          isFlashing: false,
          status: success ? 'Firmware flashed successfully!' : 'Firmware flash failed.',
          error: success ? null : 'Flash failed. Please retry.',
        ));
      }
    });
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
        : state.filteredLogs.where((log) => log.message.toLowerCase().contains(event.filter!.toLowerCase()) || log.deviceId == event.filter).toList();
    emit(state.copyWith(filteredLogs: filtered, status: 'Filtering logs for: ${event.filter ?? 'all'}'));
  }

  void _onSelectSerial(SelectSerialEvent event, Emitter<LogState> emit) {
    emit(state.copyWith(serialNumber: event.serial));
  }

  void _onAutoScroll(AutoScrollEvent event, Emitter<LogState> emit) {
    // Handle auto-scroll if needed
  }
}