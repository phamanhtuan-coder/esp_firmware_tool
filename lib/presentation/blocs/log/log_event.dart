import 'package:equatable/equatable.dart';

import '../../../data/models/log_entry.dart';

abstract class LogEvent extends Equatable {
  const LogEvent();

  @override
  List<Object?> get props => [];
}

class AddLogEvent extends LogEvent {
  final LogEntry logEntry;

  const AddLogEvent(this.logEntry);

  @override
  List<Object?> get props => [logEntry];
}

class FilterLogEvent extends LogEvent {
  final String? textFilter;
  final String? deviceFilter;
  final ProcessStep? stepFilter;
  final bool clearFilters;

  const FilterLogEvent({
    this.textFilter,
    this.deviceFilter,
    this.stepFilter,
    this.clearFilters = false,
  });

  @override
  List<Object?> get props => [textFilter, deviceFilter, stepFilter, clearFilters];
}

class ClearLogsEvent extends LogEvent {}