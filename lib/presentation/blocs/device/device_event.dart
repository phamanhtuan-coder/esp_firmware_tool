import 'package:equatable/equatable.dart';

abstract class DeviceEvent extends Equatable {
  const DeviceEvent();

  @override
  List<Object> get props => [];
}

class ScanPortsEvent extends DeviceEvent {}

class ConnectToPortEvent extends DeviceEvent {
  final String portName;

  const ConnectToPortEvent(this.portName);

  @override
  List<Object> get props => [portName];
}

class SetSerialNumberEvent extends DeviceEvent {
  final String serialNumber;

  const SetSerialNumberEvent(this.serialNumber);

  @override
  List<Object> get props => [serialNumber];
}

class SelectTemplateEvent extends DeviceEvent {
  final String templatePath;

  const SelectTemplateEvent(this.templatePath);

  @override
  List<Object> get props => [templatePath];
}

class StartProcessEvent extends DeviceEvent {}

class StopProcessEvent extends DeviceEvent {}

class SelectUsbPortEvent extends DeviceEvent {
  final String portName;

  const SelectUsbPortEvent(this.portName);

  @override
  List<Object> get props => [portName];
}

class ScanUsbPortsEvent extends DeviceEvent {}