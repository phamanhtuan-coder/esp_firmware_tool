import 'package:equatable/equatable.dart';
import 'package:esp_firmware_tool/utils/enums.dart';

abstract class DeviceEvent extends Equatable {
  const DeviceEvent();

  @override
  List<Object?> get props => [];
}

// Process Control Events
class StartProcess extends DeviceEvent {}
class StopProcess extends DeviceEvent {}

// Template Management
class SelectTemplate extends DeviceEvent {
  final String path;
  const SelectTemplate(this.path);
  @override
  List<Object?> get props => [path];
}

// Device Management Events
class FetchDevices extends DeviceEvent {}

class UpdateStatus extends DeviceEvent {
  final String status;
  const UpdateStatus(this.status);
  @override
  List<Object?> get props => [status];
}

class UpdateDeviceStatus extends DeviceEvent {
  final String deviceId;
  final DeviceStatus status;
  const UpdateDeviceStatus(this.deviceId, this.status);
  @override
  List<Object?> get props => [deviceId, status];
}

// Device Operations
class FlashDevice extends DeviceEvent {
  final String deviceId;
  final String firmwarePath;
  const FlashDevice({required this.deviceId, required this.firmwarePath});
  @override
  List<Object?> get props => [deviceId, firmwarePath];
}

class ViewDeviceLogs extends DeviceEvent {
  final String deviceId;
  const ViewDeviceLogs(this.deviceId);
  @override
  List<Object?> get props => [deviceId];
}

// Connection Events
class DeviceConnected extends DeviceEvent {
  final String deviceId;
  const DeviceConnected(this.deviceId);
  @override
  List<Object?> get props => [deviceId];
}

class DeviceDisconnected extends DeviceEvent {
  final String deviceId;
  const DeviceDisconnected(this.deviceId);
  @override
  List<Object?> get props => [deviceId];
}

// USB Connection Check
class CheckUsbConnection extends DeviceEvent {
  final String serialNumber;
  const CheckUsbConnection(this.serialNumber);
  @override
  List<Object?> get props => [serialNumber];
}

// Serial Number Input
class SetSerialNumber extends DeviceEvent {
  final String serialNumber;
  const SetSerialNumber(this.serialNumber);
  @override
  List<Object?> get props => [serialNumber];
}

// USB Port Management
class ScanUsbPorts extends DeviceEvent {
  final bool silent; // If true, won't show loading indicators
  const ScanUsbPorts({this.silent = false});
  @override
  List<Object?> get props => [silent];
}

class SelectUsbPort extends DeviceEvent {
  final String port;
  const SelectUsbPort(this.port);
  @override
  List<Object?> get props => [port];
}

// Error Events
class DeviceError extends DeviceEvent {
  final String deviceId;
  final String error;
  const DeviceError(this.deviceId, this.error);
  @override
  List<Object?> get props => [deviceId, error];
}