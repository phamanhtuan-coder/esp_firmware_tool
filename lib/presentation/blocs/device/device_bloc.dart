import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/data/services/arduino_cli_service.dart';
import 'package:esp_firmware_tool/data/services/usb_service.dart';
import 'package:esp_firmware_tool/presentation/blocs/device/device_event.dart';
import 'package:esp_firmware_tool/presentation/blocs/device/device_state.dart';

class DeviceBloc extends Bloc<DeviceEvent, DeviceState> {
  final ArduinoCliService _arduinoCliService;
  final USBService _usbService;
  StreamSubscription? _portSubscription;

  DeviceBloc(this._arduinoCliService, this._usbService) : super(const DeviceState()) {
    _portSubscription = _usbService.portUpdates.listen((ports) {
      add(ScanPortsEvent());
    });

    on<ScanPortsEvent>(_onScanPorts);
    on<ConnectToPortEvent>(_onConnectToPort);
    on<SetSerialNumberEvent>(_onSetSerialNumber);
    on<SelectTemplateEvent>(_onSelectTemplate);
    on<StartProcessEvent>(_onStartProcess);
    on<StopProcessEvent>(_onStopProcess);
    on<SelectUsbPortEvent>(_onSelectUsbPort);
    on<ScanUsbPortsEvent>(_onScanUsbPorts);
  }

  Future<void> _onScanPorts(ScanPortsEvent event, Emitter<DeviceState> emit) async {
    final ports = _usbService.getAvailablePorts();
    emit(state.copyWith(
      availablePorts: ports,
      lastScanTime: DateTime.now(),
    ));
  }

  Future<void> _onConnectToPort(ConnectToPortEvent event, Emitter<DeviceState> emit) async {
    try {
      final success = _usbService.connectToPort(event.portName);
      if (success) {
        emit(state.copyWith(
          selectedPort: event.portName,
          isConnected: true,
          error: null,
          status: 'Connected to ${event.portName}',
        ));
      } else {
        emit(state.copyWith(
          isConnected: false,
          error: 'Failed to connect to port ${event.portName}',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isConnected: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onSetSerialNumber(SetSerialNumberEvent event, Emitter<DeviceState> emit) async {
    emit(state.copyWith(serialNumber: event.serialNumber));
  }

  Future<void> _onSelectTemplate(SelectTemplateEvent event, Emitter<DeviceState> emit) async {
    emit(state.copyWith(selectedTemplate: event.templatePath));
  }

  Future<void> _onStartProcess(StartProcessEvent event, Emitter<DeviceState> emit) async {
    if (state.selectedTemplate == null) {
      emit(state.copyWith(error: 'No template selected'));
      return;
    }

    emit(state.copyWith(
      isCompiling: true,
      status: 'Compiling firmware...',
    ));

    try {
      final compiledPath = await _arduinoCliService.compileFirmware(state.selectedTemplate!);
      emit(state.copyWith(
        isCompiling: false,
        status: 'Compilation successful',
      ));

      // Start flashing process
      if (state.selectedPort != null) {
        emit(state.copyWith(
          isFlashing: true,
          status: 'Flashing firmware...',
        ));

        final success = await _usbService.flashFirmware(
          compiledPath,
          state.selectedPort!,
        );

        emit(state.copyWith(
          isFlashing: false,
          status: success ? 'Flashing successful' : 'Flashing failed',
          error: success ? null : 'Failed to flash firmware',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isCompiling: false,
        isFlashing: false,
        error: e.toString(),
        status: 'Process failed',
      ));
    }
  }

  Future<void> _onStopProcess(StopProcessEvent event, Emitter<DeviceState> emit) async {
    emit(state.copyWith(
      isCompiling: false,
      isFlashing: false,
      status: 'Process stopped',
    ));
  }

  Future<void> _onSelectUsbPort(SelectUsbPortEvent event, Emitter<DeviceState> emit) async {
    emit(state.copyWith(selectedPort: event.portName));
  }

  Future<void> _onScanUsbPorts(ScanUsbPortsEvent event, Emitter<DeviceState> emit) async {
    emit(state.copyWith(isScanning: true));

    try {
      final ports = _usbService.getAvailablePorts();
      emit(state.copyWith(
        availablePorts: ports,
        isScanning: false,
        lastScanTime: DateTime.now(),
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isScanning: false,
        error: 'Failed to scan ports: ${e.toString()}',
      ));
    }
  }

  @override
  Future<void> close() {
    _portSubscription?.cancel();
    return super.close();
  }
}