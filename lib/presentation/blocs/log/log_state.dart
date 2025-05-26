import 'package:equatable/equatable.dart';

class LogState extends Equatable {
  final List<String> logs;
  final bool isLoading;
  final String? error;

  const LogState({
    this.logs = const [],
    this.isLoading = false,
    this.error,
  });

  LogState copyWith({
    List<String>? logs,
    bool? isLoading,
    String? error,
  }) {
    return LogState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      error: error,  // Allow setting to null
    );
  }

  @override
  List<Object?> get props => [logs, isLoading, error];
}