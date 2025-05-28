import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/data/services/arduino_cli_service.dart';
import 'package:esp_firmware_tool/data/services/usb_service.dart';
import 'package:esp_firmware_tool/data/services/template_service.dart';
import 'package:esp_firmware_tool/data/models/log_entry.dart';  // Import for ProcessStep enum
import 'package:esp_firmware_tool/presentation/blocs/device/device_event.dart';
import 'package:esp_firmware_tool/presentation/blocs/device/device_state.dart';

class DeviceBloc extends Bloc<DeviceEvent, DeviceState> {
  final ArduinoCliService _arduinoCliService;
  final UsbService _usbService;
  final TemplateService _templateService;
  StreamSubscription? _deviceSubscription;

  DeviceBloc(
    this._arduinoCliService,
    this._usbService,
    [TemplateService? templateService]
  ) : _templateService = templateService ?? TemplateService(),
      super(const DeviceState()) {

    // Listen to USB device events
    _deviceSubscription = _usbService.deviceStream.listen((deviceEvent) {
      if (deviceEvent.connected) {
        // A new device was connected
        add(ScanUsbPortsEvent());
      } else {
        // A device was disconnected
        if (state.selectedPort == deviceEvent.port) {
          // If the disconnected device was selected, reset state
          add(StopProcessEvent());
        }
        // Rescan ports
        add(ScanUsbPortsEvent());
      }
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

    if (state.serialNumber == null || state.serialNumber!.isEmpty) {
      emit(state.copyWith(error: 'No serial number provided'));
      return;
    }

    emit(state.copyWith(
      isCompiling: true,
      status: 'Processing template...',
    ));

    try {
      // Process the template first to replace placeholders
      final processedTemplatePath = await _templateService.prepareFirmwareTemplate(
        state.selectedTemplate!,
        state.serialNumber!,
        'device-${state.serialNumber}',
      );

      if (processedTemplatePath == null) {
        emit(state.copyWith(
          isCompiling: false,
          error: 'Failed to prepare template',
        ));
        return;
      }

      emit(state.copyWith(status: 'Compiling firmware...'));

      // Use the Arduino CLI service to compile and flash the firmware
      final port = state.selectedPort!;
      final boardFqbn = _arduinoCliService.getBoardFqbn(state.deviceType ?? 'esp32');

      // Compile the firmware
      final compileResult = await _arduinoCliService.runProcess(
        'arduino-cli',
        ['compile', '--fqbn', boardFqbn, processedTemplatePath],
        step: ProcessStep.compile,
        deviceId: 'device-${state.serialNumber}',
      );

      if (compileResult != 0) {
        emit(state.copyWith(
          isCompiling: false,
          error: 'Compilation failed with code: $compileResult',
        ));
        return;
      }

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

        final uploadResult = await _arduinoCliService.runProcess(
          'arduino-cli',
          ['upload', '--fqbn', boardFqbn, '--port', port, processedTemplatePath],
          step: ProcessStep.flash,
          deviceId: 'device-${state.serialNumber}',
        );

        if (uploadResult != 0) {
          emit(state.copyWith(
            isFlashing: false,
            error: 'Flash failed with code: $uploadResult',
          ));
          return;
        }

        emit(state.copyWith(
          isFlashing: false,
          status: 'Flash successful',
          error: null,
        ));
      } else {
        emit(state.copyWith(
          error: 'No port selected for flashing',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isCompiling: false,
        isFlashing: false,
        error: 'Error: ${e.toString()}',
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
    _deviceSubscription?.cancel();
    return super.close();
  }
}