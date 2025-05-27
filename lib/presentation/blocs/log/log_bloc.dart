import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/log_entry.dart';
import '../../../data/services/log_service.dart';
import 'log_event.dart';
import 'log_state.dart';

class LogBloc extends Bloc<LogEvent, LogState> {
  final LogService logService;
  StreamSubscription<LogEntry>? _logSubscription;

  LogBloc({required this.logService}) : super(const LogState()) {
    on<AddLogEvent>(_onAddLog);
    on<FilterLogEvent>(_onFilterLog);
    on<ClearLogsEvent>(_onClearLogs);

    // Initialize the log service and subscribe to the log stream
    _initLogService();
  }

  Future<void> _initLogService() async {
    await logService.initialize();
    _logSubscription = logService.logStream.listen((logEntry) {
      add(AddLogEvent(logEntry));
    });
  }

  void _onAddLog(AddLogEvent event, Emitter<LogState> emit) {
    final updatedLogs = List<LogEntry>.from(state.logs)..add(event.logEntry);
    final filteredLogs = _applyFilters(updatedLogs, state.filter, state.deviceFilter, state.stepFilter);

    emit(state.copyWith(
      logs: updatedLogs,
      filteredLogs: filteredLogs,
    ));
  }

  void _onFilterLog(FilterLogEvent event, Emitter<LogState> emit) {
    if (event.clearFilters) {
      emit(state.copyWith(
        filter: '',
        deviceFilter: '',
        clearStepFilter: true,
        filteredLogs: state.logs,
      ));
      return;
    }

    final newFilter = event.textFilter ?? state.filter;
    final newDeviceFilter = event.deviceFilter ?? state.deviceFilter;
    final newStepFilter = event.stepFilter;

    final filteredLogs = _applyFilters(state.logs, newFilter, newDeviceFilter, newStepFilter);

    emit(state.copyWith(
      filter: newFilter,
      deviceFilter: newDeviceFilter,
      stepFilter: newStepFilter,
      filteredLogs: filteredLogs,
    ));
  }

  void _onClearLogs(ClearLogsEvent event, Emitter<LogState> emit) {
    emit(const LogState());
  }

  List<LogEntry> _applyFilters(List<LogEntry> logs, String textFilter, String deviceFilter, ProcessStep? stepFilter) {
    return logs.where((log) {
      // Apply text filter
      final textMatch = textFilter.isEmpty ||
          log.message.toLowerCase().contains(textFilter.toLowerCase());

      // Apply device filter
      final deviceMatch = deviceFilter.isEmpty ||
          log.deviceId.toLowerCase().contains(deviceFilter.toLowerCase());

      // Apply step filter
      final stepMatch = stepFilter == null || log.step == stepFilter;

      return textMatch && deviceMatch && stepMatch;
    }).toList();
  }

  @override
  Future<void> close() {
    _logSubscription?.cancel();
    logService.dispose();
    return super.close();
  }
}