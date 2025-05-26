import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/log_entry.dart';
import 'log_event.dart';
import 'log_state.dart';

class LogBloc extends Bloc<LogEvent, LogState> {
  LogBloc() : super(const LogState()) {
    on<AddLogEvent>(_onAddLog);
    on<FilterLogEvent>(_onFilterLog);
    on<ClearLogsEvent>(_onClearLogs);
  }

  void _onAddLog(AddLogEvent event, Emitter<LogState> emit) {
    final updatedLogs = List<LogEntry>.from(state.logs)..add(event.logEntry);
    final filteredLogs = _applyFilters(updatedLogs);

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

    final updatedState = state.copyWith(
      filter: event.textFilter ?? state.filter,
      deviceFilter: event.deviceFilter ?? state.deviceFilter,
      stepFilter: event.stepFilter,
    );

    final filteredLogs = _applyFilters(state.logs);

    emit(updatedState.copyWith(filteredLogs: filteredLogs));
  }

  void _onClearLogs(ClearLogsEvent event, Emitter<LogState> emit) {
    emit(const LogState());
  }

  List<LogEntry> _applyFilters(List<LogEntry> logs) {
    return logs.where((log) {
      // Apply text filter
      final textMatch = state.filter.isEmpty ||
          log.message.toLowerCase().contains(state.filter.toLowerCase());

      // Apply device filter
      final deviceMatch = state.deviceFilter.isEmpty ||
          log.deviceId.toLowerCase().contains(state.deviceFilter.toLowerCase());

      // Apply step filter
      final stepMatch = state.stepFilter == null || log.step == state.stepFilter;

      return textMatch && deviceMatch && stepMatch;
    }).toList();
  }
}