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
      ));
      final templatePath = await templateService.getFirmwareTemplate(
        event.firmwareVersion,
        event.deviceType,
      );
      if (templatePath != null) {
        final preparedPath = await templateService.prepareFirmwareTemplate(
          templatePath,
          event.deviceSerial,
          event.deviceId,
        );
        if (preparedPath != null) {
          final success = await logService.compileAndFlash(
            preparedPath,
            state.selectedPort ?? '',
            arduinoCliService.getBoardFqbn(event.deviceType),
            event.deviceId,
          );
          emit(LogState(
            filteredLogs: state.filteredLogs,
            isFlashing: false,
            status: success ? 'Done' : 'Error',
            error: success ? null : 'Failed to flash firmware',
            availablePorts: state.availablePorts,
            selectedPort: state.selectedPort,
            serialNumber: state.serialNumber,
          ));
        } else {
          emit(LogState(
            filteredLogs: state.filteredLogs,
            isFlashing: false,
            status: 'Error',
            error: 'Failed to prepare template',
            availablePorts: state.availablePorts,
            selectedPort: state.selectedPort,
            serialNumber: state.serialNumber,
          ));
        }
      } else {
        emit(LogState(
          filteredLogs: state.filteredLogs,
          isFlashing: false,
          status: 'Error',
          error: 'Failed to get template',
          availablePorts: state.availablePorts,
          selectedPort: state.selectedPort,
          serialNumber: state.serialNumber,
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
  }
}

abstract class LogEvent {}

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