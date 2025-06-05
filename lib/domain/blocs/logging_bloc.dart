import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';

abstract class LoggingEvent {}

class AddLogEvent extends LoggingEvent {
  final LogEntry log;
  AddLogEvent(this.log);
}

class FilterLogEvent extends LoggingEvent {
  final String? filter;
  FilterLogEvent(this.filter);
}

class ClearLogsEvent extends LoggingEvent {}

class AutoScrollEvent extends LoggingEvent {}

class LoggingState {
  final List<LogEntry> logs;
  final List<LogEntry> filteredLogs;
  final String? filter;
  final bool autoScroll;

  const LoggingState({
    this.logs = const [],
    this.filteredLogs = const [],
    this.filter,
    this.autoScroll = true,
  });

  LoggingState copyWith({
    List<LogEntry>? logs,
    List<LogEntry>? filteredLogs,
    String? filter,
    bool? autoScroll,
  }) {
    if (filter != null || logs != null) {
      final newLogs = logs ?? this.logs;
      final filtered =
          (filter != null && filter.isNotEmpty)
              ? newLogs
                  .where(
                    (log) => log.message.toLowerCase().contains(
                      filter.toLowerCase(),
                    ),
                  )
                  .toList()
              : newLogs;

      return LoggingState(
        logs: newLogs,
        filteredLogs: filtered,
        filter: filter,
        autoScroll: autoScroll ?? this.autoScroll,
      );
    }

    return LoggingState(
      logs: logs ?? this.logs,
      filteredLogs: filteredLogs ?? this.filteredLogs,
      filter: filter,
      autoScroll: autoScroll ?? this.autoScroll,
    );
  }
}

class LoggingBloc extends Bloc<LoggingEvent, LoggingState> {
  LoggingBloc() : super(LoggingState()) {
    on<AddLogEvent>(_onAddLog);
    on<FilterLogEvent>(_onFilterLog);
    on<ClearLogsEvent>(_onClearLogs);
    on<AutoScrollEvent>(_onAutoScroll);
  }

  void _onAddLog(AddLogEvent event, Emitter<LoggingState> emit) {
    final log = LogEntry(
      message: event.log.message,
      timestamp: event.log.timestamp,
      level: event.log.level,
      step: event.log.step,
      origin: event.log.origin,
      deviceId: event.log.deviceId,
      rawOutput: event.log.rawOutput,
    );

    final newLogs = List<LogEntry>.from(state.logs)..add(log);
    emit(state.copyWith(logs: newLogs));
  }

  void _onFilterLog(FilterLogEvent event, Emitter<LoggingState> emit) {
    emit(state.copyWith(filter: event.filter));
  }

  void _onClearLogs(ClearLogsEvent event, Emitter<LoggingState> emit) {
    emit(LoggingState()); // Reset to initial state
  }

  void _onAutoScroll(AutoScrollEvent event, Emitter<LoggingState> emit) {
    emit(state.copyWith(autoScroll: true));
  }
}
