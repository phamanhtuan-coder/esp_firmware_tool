import 'package:equatable/equatable.dart';

abstract class LogEvent extends Equatable {
  const LogEvent();

  @override
  List<Object?> get props => [];
}

class StartLogging extends LogEvent {
  final String deviceId;

  const StartLogging(this.deviceId);

  @override
  List<Object?> get props => [deviceId];
}

class StopLogging extends LogEvent {}

class ClearLogs extends LogEvent {}

class LogReceived extends LogEvent {
  final String log;

  const LogReceived(this.log);

  @override
  List<Object?> get props => [log];
}