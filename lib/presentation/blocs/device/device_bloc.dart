import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/data/repositories/socket_repository.dart';
import 'package:esp_firmware_tool/utils/enums.dart';
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

  @override
  Future<void> close() {
    _devicesSubscription?.cancel();
    _statusSubscription?.cancel();
    _deviceLogsSubscription?.cancel();
    socketRepository.disconnect();
    return super.close();
  }
}