import 'package:equatable/equatable.dart';
import 'package:esp_firmware_tool/data/models/device.dart';
import 'package:esp_firmware_tool/utils/enums.dart';

class DeviceState extends Equatable {
  final List<Device> devices;
  final DeviceStatus status;
  final String? error;
  final String? selectedTemplate;
  final String? selectedDeviceId;
  final String? serialNumber;
  final List<String> availablePorts;
  final String? selectedPort;
  final bool isScanning; // Track if a port scan is in progress
  final DateTime? lastScanTime; // When the last scan was completed

  const DeviceState({
    this.devices = const [],
    this.status = DeviceStatus.connected,
    this.error,
    this.selectedTemplate,
    this.selectedDeviceId,
    this.serialNumber,
    this.availablePorts = const [],
    this.selectedPort,
    this.isScanning = false,
    this.lastScanTime,
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
    String? serialNumber,
    List<String>? availablePorts,
    String? selectedPort,
    bool? isScanning,
    DateTime? lastScanTime,
  }) {
    return DeviceState(
      devices: devices ?? this.devices,
      status: status ?? this.status,
      error: error,  // Allow setting to null
      selectedTemplate: selectedTemplate ?? this.selectedTemplate,
      selectedDeviceId: selectedDeviceId ?? this.selectedDeviceId,
      serialNumber: serialNumber ?? this.serialNumber,
      availablePorts: availablePorts ?? this.availablePorts,
      selectedPort: selectedPort ?? this.selectedPort,
      isScanning: isScanning ?? this.isScanning,
      lastScanTime: lastScanTime ?? this.lastScanTime,
    );
  }

  @override
  List<Object?> get props => [
    devices,
    status,
    error,
    selectedTemplate,
    selectedDeviceId,
    serialNumber,
    availablePorts,
    selectedPort,
    isScanning,
    lastScanTime,
  ];
}