import 'package:bloc/bloc.dart';
import 'package:esp_firmware_tool/data/models/log_entry.dart';
import 'package:esp_firmware_tool/data/services/arduino_cli_service.dart';
import 'package:esp_firmware_tool/data/services/log_service.dart';
import 'package:esp_firmware_tool/data/services/template_service.dart';
import 'package:esp_firmware_tool/data/services/usb_service.dart';

class LogState {
  final List<LogEntry> filteredLogs;
  final String? activeInputRequest;
  final String? status;
  final String? error;
  final bool isFlashing;
  final bool isScanning;
  final List<String> availablePorts;
  final String? selectedPort;
  final String? serialNumber;
  final String? selectedBatch;
  final List<String> batchSerials;

  LogState({
    this.filteredLogs = const [],
    this.activeInputRequest,
    this.status,
    this.error,
    this.isFlashing = false,
    this.isScanning = false,
    this.availablePorts = const [],
    this.selectedPort,
    this.serialNumber,
    this.selectedBatch,
    this.batchSerials = const [],
  });
}

class LogBloc extends Bloc<LogEvent, LogState> {
  final LogService logService;
  final ArduinoCliService arduinoCliService;
  final TemplateService templateService;
  final UsbService usbService;

  LogBloc({
    required this.logService,
    required this.arduinoCliService,
    required this.templateService,
    required this.usbService,
  }) : super(LogState()) {
    on<FilterLogEvent>((event, emit) async => emit(LogState(filteredLogs: await logService.logStream.toList())));
    on<ClearLogsEvent>((event, emit) {
      logService.clearLogs();
      emit(LogState(filteredLogs: []));
    });
    on<ScanUsbPortsEvent>((event, emit) async {
      emit(LogState(
        filteredLogs: state.filteredLogs,
        isScanning: true,
        availablePorts: state.availablePorts,
        selectedPort: state.selectedPort,
        serialNumber: state.serialNumber,
      ));
      final ports = usbService.getAvailablePorts();
      emit(LogState(
        filteredLogs: state.filteredLogs,
        isScanning: false,
        availablePorts: ports,
        selectedPort: state.selectedPort,
        serialNumber: state.serialNumber,
      ));
    });
    on<SelectUsbPortEvent>((event, emit) => emit(LogState(
      filteredLogs: state.filteredLogs,
      availablePorts: state.availablePorts,
      selectedPort: event.port,
      serialNumber: state.serialNumber,
    )));
    on<UpdateSerialNumberEvent>((event, emit) => emit(LogState(
      filteredLogs: state.filteredLogs,
      availablePorts: state.availablePorts,
      selectedPort: state.selectedPort,
      serialNumber: event.serialNumber,
    )));
    on<InitiateFlashEvent>((event, emit) async {
      emit(LogState(
        filteredLogs: state.filteredLogs,
        isFlashing: true,
        status: 'Flashing',
        availablePorts: state.availablePorts,
        selectedPort: state.selectedPort,
        serialNumber: event.deviceSerial,
        selectedBatch: state.selectedBatch,
        batchSerials: state.batchSerials,
      ));
      final templatePath = await logService.createFirmwareTemplate(
        state.selectedBatch ?? '',
        event.deviceSerial,
        event.deviceId,
      );
      if (templatePath != null) {
        final success = await logService.compileAndFlash(
          templatePath,
          state.selectedPort ?? '',
          arduinoCliService.getBoardFqbn(event.deviceType),
          event.deviceId,
        );
        if (success) {
          logService.markDeviceProcessed(event.deviceSerial, true);
        }
        emit(LogState(
          filteredLogs: state.filteredLogs,
          isFlashing: false,
          status: success ? 'Done' : 'Error',
          error: success ? null : 'Failed to flash firmware',
          availablePorts: state.availablePorts,
          selectedPort: state.selectedPort,
          serialNumber: event.deviceSerial,
          selectedBatch: state.selectedBatch,
          batchSerials: state.batchSerials,
        ));
      } else {
        emit(LogState(
          filteredLogs: state.filteredLogs,
          isFlashing: false,
          status: 'Error',
          error: 'Failed to prepare template',
          availablePorts: state.availablePorts,
          selectedPort: state.selectedPort,
          serialNumber: event.deviceSerial,
          selectedBatch: state.selectedBatch,
          batchSerials: state.batchSerials,
        ));
      }
    });
    on<StopProcessEvent>((event, emit) async {
      await logService.killActiveProcess();
      emit(LogState(
        filteredLogs: state.filteredLogs,
        isFlashing: false,
        status: 'Stopped',
        availablePorts: state.availablePorts,
        selectedPort: state.selectedPort,
        serialNumber: state.serialNumber,
      ));
    });
    on<SelectBatchEvent>((event, emit) async {
      final serials = await logService.fetchSerialsForBatch(event.batchId);
      emit(LogState(
        filteredLogs: state.filteredLogs,
        availablePorts: state.availablePorts,
        selectedPort: state.selectedPort,
        serialNumber: state.serialNumber,
        selectedBatch: event.batchId,
        batchSerials: serials,
      ));
    });
    on<SelectSerialEvent>((event, emit) async {
      // Check if serial is already flashed or defective
      bool isFlashed = await _checkIfFlashed(event.serialNumber);
      bool isDefective = await _checkIfDefective(event.serialNumber);
      if (isFlashed) {
        emit(LogState(
          filteredLogs: state.filteredLogs,
          availablePorts: state.availablePorts,
          selectedPort: state.selectedPort,
          serialNumber: event.serialNumber,
          selectedBatch: state.selectedBatch,
          batchSerials: state.batchSerials,
          error: 'Device ${event.serialNumber} already flashed',
        ));
      } else if (isDefective) {
        emit(LogState(
          filteredLogs: state.filteredLogs,
          availablePorts: state.availablePorts,
          selectedPort: state.selectedPort,
          serialNumber: event.serialNumber,
          selectedBatch: state.selectedBatch,
          batchSerials: state.batchSerials,
          error: 'Device ${event.serialNumber} is defective',
        ));
      } else {
        emit(LogState(
          filteredLogs: state.filteredLogs,
          availablePorts: state.availablePorts,
          selectedPort: state.selectedPort,
          serialNumber: event.serialNumber,
          selectedBatch: state.selectedBatch,
          batchSerials: state.batchSerials,
        ));
      }
    });
    on<MarkDeviceDefectiveEvent>((event, emit) async {
      // Simulate API call to mark device as defective
      await _markDeviceDefective(event.serialNumber);
      logService.markDeviceProcessed(event.serialNumber, false);
      emit(LogState(
        filteredLogs: state.filteredLogs,
        availablePorts: state.availablePorts,
        selectedPort: state.selectedPort,
        serialNumber: state.serialNumber,
        selectedBatch: state.selectedBatch,
        batchSerials: state.batchSerials,
        status: 'Device ${event.serialNumber} marked as defective',
      ));
    });
  }
  Future<bool> _checkIfFlashed(String serialNumber) async {
    // Simulate API check (replace with actual API call)
    return false;
  }

  Future<bool> _checkIfDefective(String serialNumber) async {
    // Simulate API check (replace with actual API call)
    return false;
  }

  Future<void> _markDeviceDefective(String serialNumber) async {
    // Simulate API call to mark device as defective
    await Future.delayed(const Duration(seconds: 1));
  }
}

abstract class LogEvent {}

class SelectBatchEvent extends LogEvent {
  final String batchId;
  SelectBatchEvent(this.batchId);
}

class SelectSerialEvent extends LogEvent {
  final String serialNumber;
  SelectSerialEvent(this.serialNumber);
}

class MarkDeviceDefectiveEvent extends LogEvent {
  final String serialNumber;
  MarkDeviceDefectiveEvent(this.serialNumber);
}

class FilterLogEvent extends LogEvent {
  final String deviceFilter;
  FilterLogEvent({required this.deviceFilter});
}

class ClearLogsEvent extends LogEvent {}

class ScanUsbPortsEvent extends LogEvent {}

class SelectUsbPortEvent extends LogEvent {
  final String port;
  SelectUsbPortEvent(this.port);
}

class UpdateSerialNumberEvent extends LogEvent {
  final String serialNumber;
  UpdateSerialNumberEvent(this.serialNumber);
}

class InitiateFlashEvent extends LogEvent {
  final String deviceId;
  final String firmwareVersion;
  final String deviceSerial;
  final String deviceType;
  InitiateFlashEvent({
    required this.deviceId,
    required this.firmwareVersion,
    required this.deviceSerial,
    required this.deviceType,
  });
}

class StopProcessEvent extends LogEvent {}