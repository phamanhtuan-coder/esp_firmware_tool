import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/data/repositories/socket_repository.dart';
import 'log_event.dart';
import 'log_state.dart';

class LogBloc extends Bloc<LogEvent, LogState> {
  final ISocketRepository socketRepository;
  StreamSubscription? _logSubscription;

  LogBloc({required this.socketRepository}) : super(LogState()) {
    on<StartLogging>(_onStartLogging);
    on<StopLogging>(_onStopLogging);
    on<ClearLogs>(_onClearLogs);
    on<LogReceived>(_onLogReceived);
  }

  void _onStartLogging(StartLogging event, Emitter<LogState> emit) {
    _logSubscription?.cancel();
    _logSubscription = socketRepository.getDeviceLogs(event.deviceId).listen(
      (log) {
        add(LogReceived(log));
      },
    );
  }

  void _onStopLogging(StopLogging event, Emitter<LogState> emit) {
    _logSubscription?.cancel();
  }

  void _onClearLogs(ClearLogs event, Emitter<LogState> emit) {
    emit(state.copyWith(logs: []));
  }

  void _onLogReceived(LogReceived event, Emitter<LogState> emit) {
    final updatedLogs = List<String>.from(state.logs)..add(event.log);
    emit(state.copyWith(logs: updatedLogs));
  }

  @override
  Future<void> close() {
    _logSubscription?.cancel();
    return super.close();
  }
}