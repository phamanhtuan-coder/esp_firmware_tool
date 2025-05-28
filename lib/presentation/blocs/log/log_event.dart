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

// New events for the updated log view

class SetBatchEvent extends LogEvent {
  final String batchId;
  final List<String> serialNumbers;

  const SetBatchEvent({
    required this.batchId,
    required this.serialNumbers,
  });

  @override
  List<Object?> get props => [batchId, serialNumbers];
}

class UpdateBatchDeviceStatusEvent extends LogEvent {
  final String serialNumber;
  final bool? isProcessed;
  final DateTime? flashTime;
  final bool? hasError;
  final String? errorMessage;

  const UpdateBatchDeviceStatusEvent({
    required this.serialNumber,
    this.isProcessed,
    this.flashTime,
    this.hasError,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [serialNumber, isProcessed, flashTime, hasError, errorMessage];
}

class SelectDeviceTypeEvent extends LogEvent {
  final String deviceType;

  const SelectDeviceTypeEvent(this.deviceType);

  @override
  List<Object?> get props => [deviceType];
}

class SelectFirmwareEvent extends LogEvent {
  final String firmwareId;

  const SelectFirmwareEvent(this.firmwareId);

  @override
  List<Object?> get props => [firmwareId];
}

class SetScannedSerialNumberEvent extends LogEvent {
  final String serialNumber;

  const SetScannedSerialNumberEvent(this.serialNumber);

  @override
  List<Object?> get props => [serialNumber];
}

class InitiateFlashEvent extends LogEvent {
  final String deviceId;
  final String firmwareVersion;
  final String deviceSerial;

  const InitiateFlashEvent({
    required this.deviceId,
    required this.firmwareVersion,
    required this.deviceSerial,
  });

  @override
  List<Object?> get props => [deviceId, firmwareVersion, deviceSerial];
}

class SetActiveInputRequestEvent extends LogEvent {
  final LogEntry? inputRequest;

  const SetActiveInputRequestEvent(this.inputRequest);

  @override
  List<Object?> get props => [inputRequest];
}

class ClearActiveInputRequestEvent extends LogEvent {
  const ClearActiveInputRequestEvent();
}

class ToggleAutoScrollEvent extends LogEvent {
  final bool? autoScroll;

  const ToggleAutoScrollEvent([this.autoScroll]);

  @override
  List<Object?> get props => [autoScroll];
}

class ProcessSerialInputEvent extends LogEvent {
  final String input;

  const ProcessSerialInputEvent(this.input);

  @override
  List<Object?> get props => [input];
}