import 'package:equatable/equatable.dart';
import '../../utils/enums.dart';

class DeviceState extends Equatable {
  final List<dynamic> devices;
  final DeviceStatus status;
  final String? error;
  final String? selectedTemplate;

  const DeviceState({
    this.devices = const [],
    this.status = DeviceStatus.idle,
    this.error,
    this.selectedTemplate,
  });

  DeviceState copyWith({
    List<dynamic>? devices,
    DeviceStatus? status,
    String? error,
    String? selectedTemplate,
  }) {
    return DeviceState(
      devices: devices ?? this.devices,
      status: status ?? this.status,
      error: error ?? this.error,
      selectedTemplate: selectedTemplate ?? this.selectedTemplate,
    );
  }

  @override
  List<Object?> get props => [devices, status, error, selectedTemplate];
}