import 'package:equatable/equatable.dart';
import 'package:esp_firmware_tool/data/models/device.dart';
import 'package:esp_firmware_tool/utils/enums.dart';

class DeviceState extends Equatable {
  final List<Device> devices;
  final DeviceStatus status;
  final String? error;
  final String? selectedTemplate;
  final String? selectedDeviceId;

  const DeviceState({
    this.devices = const [],
    this.status = DeviceStatus.connected,
    this.error,
    this.selectedTemplate,
    this.selectedDeviceId,
  });

  Device? get selectedDevice => selectedDeviceId != null
    ? devices.firstWhere(
        (d) => d.id == selectedDeviceId,
        orElse: () => Device(id: '', name: '', status: ''))
    : null;

  DeviceState copyWith({
    List<Device>? devices,
    DeviceStatus? status,
    String? error,
    String? selectedTemplate,
    String? selectedDeviceId,
  }) {
    return DeviceState(
      devices: devices ?? this.devices,
      status: status ?? this.status,
      error: error,  // Allow setting to null
      selectedTemplate: selectedTemplate ?? this.selectedTemplate,
      selectedDeviceId: selectedDeviceId ?? this.selectedDeviceId,
    );
  }

  @override
  List<Object?> get props => [
    devices,
    status,
    error,
    selectedTemplate,
    selectedDeviceId,
  ];
}