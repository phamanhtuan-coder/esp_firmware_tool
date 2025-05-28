import 'package:equatable/equatable.dart';

class DeviceState extends Equatable {
  final List<String> availablePorts;
  final String? selectedPort;
  final bool isConnected;
  final bool isCompiling;
  final bool isFlashing;
  final bool isScanning;
  final String? serialNumber;
  final String? deviceType;
  final String? selectedTemplate;
  final String? error;
  final DateTime? lastScanTime;
  final String? status;

  const DeviceState({
    this.availablePorts = const [],
    this.selectedPort,
    this.isConnected = false,
    this.isCompiling = false,
    this.isFlashing = false,
    this.isScanning = false,
    this.serialNumber,
    this.deviceType,
    this.selectedTemplate,
    this.error,
    this.lastScanTime,
    this.status,
  });

  DeviceState copyWith({
    List<String>? availablePorts,
    String? selectedPort,
    bool? isConnected,
    bool? isCompiling,
    bool? isFlashing,
    bool? isScanning,
    String? serialNumber,
    String? deviceType,
    String? selectedTemplate,
    String? error,
    DateTime? lastScanTime,
    String? status,
  }) {
    return DeviceState(
      availablePorts: availablePorts ?? this.availablePorts,
      selectedPort: selectedPort ?? this.selectedPort,
      isConnected: isConnected ?? this.isConnected,
      isCompiling: isCompiling ?? this.isCompiling,
      isFlashing: isFlashing ?? this.isFlashing,
      isScanning: isScanning ?? this.isScanning,
      serialNumber: serialNumber ?? this.serialNumber,
      deviceType: deviceType ?? this.deviceType,
      selectedTemplate: selectedTemplate ?? this.selectedTemplate,
      error: error,
      lastScanTime: lastScanTime ?? this.lastScanTime,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
        availablePorts,
        selectedPort,
        isConnected,
        isCompiling,
        isFlashing,
        isScanning,
        serialNumber,
        deviceType,
        selectedTemplate,
        error,
        lastScanTime,
        status,
      ];
}