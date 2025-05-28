import 'package:equatable/equatable.dart';

import '../../../data/models/log_entry.dart';

// Class to represent a device in a batch
class BatchDevice extends Equatable {
  final String serialNumber;
  final bool isProcessed;
  final DateTime? flashTime;
  final bool hasError;
  final String? errorMessage;

  const BatchDevice({
    required this.serialNumber,
    this.isProcessed = false,
    this.flashTime,
    this.hasError = false,
    this.errorMessage,
  });

  BatchDevice copyWith({
    bool? isProcessed,
    DateTime? flashTime,
    bool? hasError,
    String? errorMessage,
  }) {
    return BatchDevice(
      serialNumber: this.serialNumber,
      isProcessed: isProcessed ?? this.isProcessed,
      flashTime: flashTime ?? this.flashTime,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [serialNumber, isProcessed, flashTime, hasError, errorMessage];
}

class LogState extends Equatable {
  final List<LogEntry> logs;
  final List<LogEntry> filteredLogs;
  final String filter;
  final String deviceFilter;
  final ProcessStep? stepFilter;

  // New fields for updated log view
  final List<BatchDevice> batchDevices;
  final String currentBatchId;
  final LogEntry? activeInputRequest;
  final bool isProcessing;
  final String? currentFirmwareId;
  final String? currentDeviceType;
  final String? scannedSerialNumber;
  final bool autoScroll;

  const LogState({
    this.logs = const [],
    this.filteredLogs = const [],
    this.filter = '',
    this.deviceFilter = '',
    this.stepFilter,
    this.batchDevices = const [],
    this.currentBatchId = '',
    this.activeInputRequest,
    this.isProcessing = false,
    this.currentFirmwareId,
    this.currentDeviceType,
    this.scannedSerialNumber,
    this.autoScroll = true,
  });

  LogState copyWith({
    List<LogEntry>? logs,
    List<LogEntry>? filteredLogs,
    String? filter,
    String? deviceFilter,
    ProcessStep? stepFilter,
    bool clearStepFilter = false,
    List<BatchDevice>? batchDevices,
    String? currentBatchId,
    LogEntry? activeInputRequest,
    bool clearActiveInputRequest = false,
    bool? isProcessing,
    String? currentFirmwareId,
    bool clearCurrentFirmwareId = false,
    String? currentDeviceType,
    bool clearCurrentDeviceType = false,
    String? scannedSerialNumber,
    bool clearScannedSerialNumber = false,
    bool? autoScroll,
  }) {
    return LogState(
      logs: logs ?? this.logs,
      filteredLogs: filteredLogs ?? this.filteredLogs,
      filter: filter ?? this.filter,
      deviceFilter: deviceFilter ?? this.deviceFilter,
      stepFilter: clearStepFilter ? null : stepFilter ?? this.stepFilter,
      batchDevices: batchDevices ?? this.batchDevices,
      currentBatchId: currentBatchId ?? this.currentBatchId,
      activeInputRequest: clearActiveInputRequest ? null : activeInputRequest ?? this.activeInputRequest,
      isProcessing: isProcessing ?? this.isProcessing,
      currentFirmwareId: clearCurrentFirmwareId ? null : currentFirmwareId ?? this.currentFirmwareId,
      currentDeviceType: clearCurrentDeviceType ? null : currentDeviceType ?? this.currentDeviceType,
      scannedSerialNumber: clearScannedSerialNumber ? null : scannedSerialNumber ?? this.scannedSerialNumber,
      autoScroll: autoScroll ?? this.autoScroll,
    );
  }

  // Update specific batch device status
  LogState updateBatchDeviceStatus({
    required String serialNumber,
    bool? isProcessed,
    DateTime? flashTime,
    bool? hasError,
    String? errorMessage,
  }) {
    final updatedBatchDevices = batchDevices.map((device) {
      if (device.serialNumber == serialNumber) {
        return device.copyWith(
          isProcessed: isProcessed,
          flashTime: flashTime,
          hasError: hasError,
          errorMessage: errorMessage,
        );
      }
      return device;
    }).toList();

    return copyWith(batchDevices: updatedBatchDevices);
  }

  @override
  List<Object?> get props => [
    logs, filteredLogs, filter, deviceFilter, stepFilter,
    batchDevices, currentBatchId, activeInputRequest, isProcessing,
    currentFirmwareId, currentDeviceType, scannedSerialNumber, autoScroll,
  ];
}