import 'package:equatable/equatable.dart';

import '../../../data/models/log_entry.dart';

class LogState extends Equatable {
  final List<LogEntry> logs;
  final List<LogEntry> filteredLogs;
  final String filter;
  final String deviceFilter;
  final ProcessStep? stepFilter;

  const LogState({
    this.logs = const [],
    this.filteredLogs = const [],
    this.filter = '',
    this.deviceFilter = '',
    this.stepFilter,
  });

  LogState copyWith({
    List<LogEntry>? logs,
    List<LogEntry>? filteredLogs,
    String? filter,
    String? deviceFilter,
    ProcessStep? stepFilter,
    bool clearStepFilter = false,
  }) {
    return LogState(
      logs: logs ?? this.logs,
      filteredLogs: filteredLogs ?? this.filteredLogs,
      filter: filter ?? this.filter,
      deviceFilter: deviceFilter ?? this.deviceFilter,
      stepFilter: clearStepFilter ? null : stepFilter ?? this.stepFilter,
    );
  }

  @override
  List<Object?> get props => [logs, filteredLogs, filter, deviceFilter, stepFilter];
}