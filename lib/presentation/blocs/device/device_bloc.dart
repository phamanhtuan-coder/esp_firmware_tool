import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/socket_repository.dart';
import '../../../utils/enums.dart';
import 'device_event.dart';
import 'device_state.dart';

class DeviceBloc extends Bloc<DeviceEvent, DeviceState> {
  final ISocketRepository socketRepository;
  StreamSubscription? _devicesSubscription;
  StreamSubscription? _statusSubscription;

  DeviceBloc({required this.socketRepository}) : super(const DeviceState()) {
    on<StartProcess>(_onStartProcess);
    on<StopProcess>(_onStopProcess);
    on<FetchDevices>(_onFetchDevices);
    on<UpdateStatus>(_onUpdateStatus);
    on<SelectTemplate>(_onSelectTemplate);

    // Initialize connection
    socketRepository.connect();

    // Listen to status updates
    _statusSubscription = socketRepository.getStatus().listen((status) {
      add(UpdateStatus(status));
    });
  }

  Future<void> _onStartProcess(StartProcess event, Emitter<DeviceState> emit) async {
    emit(state.copyWith(status: DeviceStatus.processing));
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
      emit(state.copyWith(status: DeviceStatus.idle));
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

    // Convert string status from socket to DeviceStatus enum
    switch (event.status.toLowerCase()) {
      case 'processing':
        newStatus = DeviceStatus.processing;
        break;
      case 'completed':
        newStatus = DeviceStatus.completed;
        break;
      case 'error':
        newStatus = DeviceStatus.error;
        break;
      default:
        newStatus = DeviceStatus.idle;
    }

    emit(state.copyWith(status: newStatus));
  }

  void _onSelectTemplate(SelectTemplate event, Emitter<DeviceState> emit) {
    emit(state.copyWith(selectedTemplate: event.path));
  }

  @override
  Future<void> close() {
    _devicesSubscription?.cancel();
    _statusSubscription?.cancel();
    socketRepository.disconnect();
    return super.close();
  }
}