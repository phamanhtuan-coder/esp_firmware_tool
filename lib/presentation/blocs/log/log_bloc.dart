import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/log_entry.dart';
import '../../../data/services/log_service.dart';
import '../../../data/services/arduino_cli_service.dart';
import '../../../data/services/template_service.dart';
import '../../../data/services/usb_service.dart';
import 'log_event.dart';
import 'log_state.dart';

class LogBloc extends Bloc<LogEvent, LogState> {
  final LogService logService;
  final ArduinoCliService? arduinoCliService;
  final TemplateService? templateService;
  final UsbService? usbService;
  StreamSubscription<LogEntry>? _logSubscription;

  // Track USB device connections for automatic log clearing
  StreamSubscription? _usbDeviceSubscription;

  LogBloc({
    required this.logService,
    this.arduinoCliService,
    this.templateService,
    this.usbService,
  }) : super(const LogState()) {
    on<AddLogEvent>(_onAddLog);
    on<FilterLogEvent>(_onFilterLog);
    on<ClearLogsEvent>(_onClearLogs);

    // Register handlers for new events
    on<SetBatchEvent>(_onSetBatch);
    on<UpdateBatchDeviceStatusEvent>(_onUpdateBatchDeviceStatus);
    on<SelectDeviceTypeEvent>(_onSelectDeviceType);
    on<SelectFirmwareEvent>(_onSelectFirmware);
    on<SetScannedSerialNumberEvent>(_onSetScannedSerialNumber);
    on<InitiateFlashEvent>(_onInitiateFlash);
    on<SetActiveInputRequestEvent>(_onSetActiveInputRequest);
    on<ClearActiveInputRequestEvent>(_onClearActiveInputRequest);
    on<ToggleAutoScrollEvent>(_onToggleAutoScroll);
    on<ProcessSerialInputEvent>(_onProcessSerialInput);

    // Initialize the log service and subscribe to the log stream
    _initLogService();
  }

  Future<void> _initLogService() async {
    await logService.initialize();

    // Listen for log entries
    _logSubscription = logService.logStream.listen((logEntry) {
      add(AddLogEvent(logEntry));

      // Handle special log entry types
      _handleSpecialLogEntries(logEntry);
    });

    // Listen for USB device connections/disconnections if available
    if (usbService != null) {
      _usbDeviceSubscription = usbService!.deviceStream.listen((deviceEvent) {
        if (deviceEvent.connected) {
          logService.registerUsbConnection(deviceEvent.deviceId, deviceEvent.port);
        } else {
          logService.registerUsbDisconnection(deviceEvent.deviceId);

          // We should clear logs related to this device
          add(ClearLogsEvent());
        }
      });
    }
  }

  // Handle special log entry types like input requests
  void _handleSpecialLogEntries(LogEntry logEntry) {
    // Set active input request if this is a serial input entry
    if (logEntry is SerialInputLogEntry) {
      add(SetActiveInputRequestEvent(logEntry));
    }

    // Clear active input request if there's a message indicating monitor closed
    if (logEntry.message.contains('Serial monitor closed') ||
        logEntry.message.contains('No active serial monitor')) {
      add(ClearActiveInputRequestEvent());
    }

    // Handle "CLEAR_LOGS" special message
    if (logEntry.message == 'CLEAR_LOGS') {
      // If deviceId is provided, only clear logs for that device
      if (logEntry.deviceId.isNotEmpty) {
        add(FilterLogEvent(deviceFilter: ''));
      } else {
        add(ClearLogsEvent());
      }
    }
  }

  void _onAddLog(AddLogEvent event, Emitter<LogState> emit) {
    final updatedLogs = List<LogEntry>.from(state.logs)..add(event.logEntry);
    final filteredLogs = _applyFilters(updatedLogs, state.filter, state.deviceFilter, state.stepFilter);

    emit(state.copyWith(
      logs: updatedLogs,
      filteredLogs: filteredLogs,
    ));
  }

  void _onFilterLog(FilterLogEvent event, Emitter<LogState> emit) {
    if (event.clearFilters) {
      emit(state.copyWith(
        filter: '',
        deviceFilter: '',
        clearStepFilter: true,
        filteredLogs: state.logs,
      ));
      return;
    }

    final newFilter = event.textFilter ?? state.filter;
    final newDeviceFilter = event.deviceFilter ?? state.deviceFilter;
    final newStepFilter = event.stepFilter;

    final filteredLogs = _applyFilters(state.logs, newFilter, newDeviceFilter, newStepFilter);

    emit(state.copyWith(
      filter: newFilter,
      deviceFilter: newDeviceFilter,
      stepFilter: newStepFilter,
      filteredLogs: filteredLogs,
    ));
  }

  void _onClearLogs(ClearLogsEvent event, Emitter<LogState> emit) {
    emit(state.copyWith(
      logs: [],
      filteredLogs: [],
    ));
  }

  void _onSetBatch(SetBatchEvent event, Emitter<LogState> emit) {
    // Convert batch serial numbers to BatchDevice objects
    final batchDevices = event.serialNumbers.map(
      (serial) => BatchDevice(serialNumber: serial)
    ).toList();

    // Update state with new batch
    emit(state.copyWith(
      batchDevices: batchDevices,
      currentBatchId: event.batchId,
    ));

    // Register batch with log service for tracking
    logService.setCurrentBatch(event.batchId, event.serialNumbers);

    // Add a log entry about the batch selection
    logService.addLog(
      message: 'Selected batch: ${event.batchId} with ${event.serialNumbers.length} devices',
      level: LogLevel.info,
      step: ProcessStep.productBatch,
    );
  }

  void _onUpdateBatchDeviceStatus(UpdateBatchDeviceStatusEvent event, Emitter<LogState> emit) {
    // Use the helper method to update a specific device status
    final updatedState = state.updateBatchDeviceStatus(
      serialNumber: event.serialNumber,
      isProcessed: event.isProcessed,
      flashTime: event.flashTime,
      hasError: event.hasError,
      errorMessage: event.errorMessage,
    );

    emit(updatedState);

    // Update the log service if a device was processed
    if (event.isProcessed != null && event.isProcessed == true) {
      logService.markDeviceProcessed(
        event.serialNumber,
        !(event.hasError != null && event.hasError == true)
      );
    }
  }

  void _onSelectDeviceType(SelectDeviceTypeEvent event, Emitter<LogState> emit) {
    emit(state.copyWith(
      currentDeviceType: event.deviceType,
      // Clear firmware selection when device type changes
      clearCurrentFirmwareId: true,
    ));

    logService.addLog(
      message: 'Device type selected: ${event.deviceType}',
      level: LogLevel.info,
      step: ProcessStep.selectDeviceType,
    );
  }

  void _onSelectFirmware(SelectFirmwareEvent event, Emitter<LogState> emit) {
    emit(state.copyWith(
      currentFirmwareId: event.firmwareId,
    ));

    logService.addLog(
      message: 'Firmware selected: ${event.firmwareId}',
      level: LogLevel.info,
      step: ProcessStep.selectFirmware,
    );
  }

  void _onSetScannedSerialNumber(SetScannedSerialNumberEvent event, Emitter<LogState> emit) {
    emit(state.copyWith(
      scannedSerialNumber: event.serialNumber,
    ));

    logService.addLog(
      message: 'Device scanned: ${event.serialNumber}',
      level: LogLevel.info,
      step: ProcessStep.scanQrCode,
    );
  }

  Future<void> _onInitiateFlash(InitiateFlashEvent event, Emitter<LogState> emit) async {
    // Mark as processing
    emit(state.copyWith(isProcessing: true));

    // Log the flash initiation
    logService.addLog(
      message: 'Starting flash process for device: ${event.deviceSerial}',
      level: LogLevel.info,
      step: ProcessStep.flash,
      deviceId: event.deviceId,
    );

    // Check if we have template service and device available
    if (templateService == null || arduinoCliService == null) {
      logService.addLog(
        message: 'Required services not available',
        level: LogLevel.error,
        step: ProcessStep.error,
        deviceId: event.deviceId,
      );
      emit(state.copyWith(isProcessing: false));
      return;
    }

    try {
      // 1. Fetch firmware template (in real case, this would come from your API)
      final templatePath = await templateService!.getFirmwareTemplate(
        event.firmwareVersion,
        state.currentDeviceType ?? 'unknown',
      );

      if (templatePath == null) {
        throw Exception('Failed to get firmware template');
      }

      // 2. Prepare the firmware template with the serial number
      final preparedSketchPath = await logService.prepareFirmwareTemplate(
        templatePath,
        event.deviceSerial,
        event.deviceId,
      );

      if (preparedSketchPath == null) {
        throw Exception('Failed to prepare firmware template');
      }

      // 3. Compile and flash
      final port = await arduinoCliService!.getPortForDevice(event.deviceId);
      final boardFqbn = arduinoCliService!.getBoardFqbn(state.currentDeviceType ?? 'esp32');

      if (port == null) {
        throw Exception('Device port not found');
      }

      final success = await logService.compileAndFlash(
        preparedSketchPath,
        port,
        boardFqbn,
        event.deviceId,
      );

      // 4. Update status based on result
      if (success) {
        add(UpdateBatchDeviceStatusEvent(
          serialNumber: event.deviceSerial,
          isProcessed: true,
          flashTime: DateTime.now(),
          hasError: false,
        ));
      } else {
        add(UpdateBatchDeviceStatusEvent(
          serialNumber: event.deviceSerial,
          isProcessed: true,
          flashTime: DateTime.now(),
          hasError: true,
          errorMessage: 'Flash failed',
        ));
      }
    } catch (e) {
      logService.addLog(
        message: 'Error during flash process: $e',
        level: LogLevel.error,
        step: ProcessStep.error,
        deviceId: event.deviceId,
      );

      add(UpdateBatchDeviceStatusEvent(
        serialNumber: event.deviceSerial,
        isProcessed: true,
        flashTime: DateTime.now(),
        hasError: true,
        errorMessage: e.toString(),
      ));
    } finally {
      // Mark as no longer processing
      emit(state.copyWith(isProcessing: false));
    }
  }

  void _onSetActiveInputRequest(SetActiveInputRequestEvent event, Emitter<LogState> emit) {
    emit(state.copyWith(activeInputRequest: event.inputRequest));
  }

  void _onClearActiveInputRequest(ClearActiveInputRequestEvent event, Emitter<LogState> emit) {
    emit(state.copyWith(clearActiveInputRequest: true));
  }

  void _onToggleAutoScroll(ToggleAutoScrollEvent event, Emitter<LogState> emit) {
    final newAutoScroll = event.autoScroll ?? !state.autoScroll;
    emit(state.copyWith(autoScroll: newAutoScroll));
  }

  void _onProcessSerialInput(ProcessSerialInputEvent event, Emitter<LogState> emit) {
    // Send input to serial monitor if there's an active input request
    if (state.activeInputRequest is SerialInputLogEntry) {
      final inputRequest = state.activeInputRequest as SerialInputLogEntry;
      inputRequest.onSerialInput(event.input);
    }
  }

  List<LogEntry> _applyFilters(List<LogEntry> logs, String textFilter, String deviceFilter, ProcessStep? stepFilter) {
    return logs.where((log) {
      // Apply text filter
      final textMatch = textFilter.isEmpty ||
          log.message.toLowerCase().contains(textFilter.toLowerCase());

      // Apply device filter
      final deviceMatch = deviceFilter.isEmpty ||
          log.deviceId.toLowerCase().contains(deviceFilter.toLowerCase());

      // Apply step filter
      final stepMatch = stepFilter == null || log.step == stepFilter;

      return textMatch && deviceMatch && stepMatch;
    }).toList();
  }

  @override
  Future<void> close() {
    _logSubscription?.cancel();
    _usbDeviceSubscription?.cancel();
    logService.dispose();
    return super.close();
  }
}