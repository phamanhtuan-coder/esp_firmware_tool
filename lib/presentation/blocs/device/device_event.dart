import 'package:equatable/equatable.dart';

abstract class DeviceEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class StartProcess extends DeviceEvent {}

class StopProcess extends DeviceEvent {}

class SelectTemplate extends DeviceEvent {
  final String path;

  SelectTemplate(this.path);

  @override
  List<Object?> get props => [path];
}

class FetchDevices extends DeviceEvent {}

class UpdateStatus extends DeviceEvent {
  final String status;

  UpdateStatus(this.status);

  @override
  List<Object?> get props => [status];
}