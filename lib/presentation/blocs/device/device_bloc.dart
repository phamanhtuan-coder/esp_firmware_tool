import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/data/repositories/socket_repository.dart';
import 'package:esp_firmware_tool/utils/enums.dart';
import 'package:esp_firmware_tool/data/models/device.dart';
import 'package:esp_firmware_tool/presentation/blocs/device/device_event.dart';
import 'package:esp_firmware_tool/presentation/blocs/device/device_state.dart';

class DeviceBloc extends Bloc<DeviceEvent, DeviceState> {
  final ISocketRepository socketRepository;
  StreamSubscription? _devicesSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _deviceLogsSubscription;

  DeviceBloc({required this.socketRepository}) : super(const DeviceState()) {
    on<StartProcess>(_onStartProcess);
    on<StopProcess>(_onStopProcess);
    on<FetchDevices>(_onFetchDevices);
    on<UpdateStatus>(_onUpdateStatus);
    on<SelectTemplate>(_onSelectTemplate);
    on<ViewDeviceLogs>(_onViewDeviceLogs);
    on<CheckUsbConnection>(_onCheckUsbConnection); // Add handler for new event

    // Initialize connection and start listening to device updates
    _initialize();
  }

  void _initialize() {
    socketRepository.connect();

    // Listen to status updates
    _statusSubscription = socketRepository.getStatus().listen((status) {
      add(UpdateStatus(status));
    });

    // Start fetching devices
    add(FetchDevices());
  }

  Future<void> _onStartProcess(StartProcess event, Emitter<DeviceState> emit) async {
    emit(state.copyWith(status: DeviceStatus.compiling));
    try {
      await socketRepository.startProcess(state.selectedTemplate);
    } catch (e) {
      emit(state.copyWith(
        status: DeviceStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onStopProcess(StopProcess event, Emitter<DeviceState> emit) async {
    try {
      await socketRepository.stopProcess();
      emit(state.copyWith(status: DeviceStatus.connected));
    } catch (e) {
      emit(state.copyWith(
        status: DeviceStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onFetchDevices(FetchDevices event, Emitter<DeviceState> emit) async {
    try {
      _devicesSubscription?.cancel();
      _devicesSubscription = socketRepository.getDevices().listen((devices) {
        emit(state.copyWith(devices: devices));
      });
    } catch (e) {
      emit(state.copyWith(
        status: DeviceStatus.error,
        error: e.toString(),
      ));
    }
  }

  void _onUpdateStatus(UpdateStatus event, Emitter<DeviceState> emit) {
    DeviceStatus newStatus;

    switch (event.status.toLowerCase()) {
      case 'connected':
        newStatus = DeviceStatus.connected;
        break;
      case 'compiling':
        newStatus = DeviceStatus.compiling;
        break;
      case 'flashing':
        newStatus = DeviceStatus.flashing;
        break;
      case 'done':
        newStatus = DeviceStatus.done;
        break;
      default:
        newStatus = DeviceStatus.error;
    }

    emit(state.copyWith(status: newStatus));
  }

  void _onSelectTemplate(SelectTemplate event, Emitter<DeviceState> emit) {
    emit(state.copyWith(selectedTemplate: event.path));
  }

  Future<void> _onViewDeviceLogs(ViewDeviceLogs event, Emitter<DeviceState> emit) async {
    emit(state.copyWith(selectedDeviceId: event.deviceId));

    // Switch log subscription to the selected device
    _deviceLogsSubscription?.cancel();
    _deviceLogsSubscription = socketRepository.getDeviceLogs(event.deviceId).listen((log) {
      // Handle logs in the LogView
    });
  }

  Future<void> _onCheckUsbConnection(CheckUsbConnection event, Emitter<DeviceState> emit) async {
    try {
      emit(state.copyWith(status: DeviceStatus.checking));

      final result = await socketRepository.checkUsbConnection(event.serialNumber);

      if (result['success'] == true) {
        // Device found, create a Device object from the result
        if (result.containsKey('device')) {
          final deviceData = result['device'] as Map<String, dynamic>;
          final device = Device.fromJson(deviceData);

          // Add the found device to the devices list if not already present
          final updatedDevices = List<Device>.from(state.devices);
          final existingDeviceIndex = updatedDevices.indexWhere((d) => d.id == device.id);

          if (existingDeviceIndex >= 0) {
            updatedDevices[existingDeviceIndex] = device;
          } else {
            updatedDevices.add(device);
          }

          emit(state.copyWith(
            devices: updatedDevices,
            status: DeviceStatus.connected,
            selectedDeviceId: device.id,
            error: null,
          ));
        } else {
          emit(state.copyWith(
            status: DeviceStatus.connected,
            error: null,
          ));
        }
      } else {
        // Device not found or error occurred
        final errorMessage = result['error'] as String? ?? 'Device not found';
        emit(state.copyWith(
          status: DeviceStatus.error,
          error: errorMessage,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: DeviceStatus.error,
        error: 'Failed to check USB connection: ${e.toString()}',
      ));
    }
  }

  @override
  Future<void> close() {
    _devicesSubscription?.cancel();
    _statusSubscription?.cancel();
    _deviceLogsSubscription?.cancel();
    socketRepository.disconnect();
    return super.close();
  }
}