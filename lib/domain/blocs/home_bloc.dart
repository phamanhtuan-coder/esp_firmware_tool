import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/data/models/batch.dart';
import 'package:smart_net_firmware_loader/data/models/device.dart';
import 'package:smart_net_firmware_loader/data/models/firmware.dart';
import 'package:smart_net_firmware_loader/data/models/planning.dart';
import 'package:smart_net_firmware_loader/data/services/api_client.dart';
import 'package:smart_net_firmware_loader/data/services/arduino_service.dart';
import 'package:smart_net_firmware_loader/data/services/bluetooth_service.dart';
import 'package:get_it/get_it.dart';

abstract class HomeEvent {}

class LoadInitialDataEvent extends HomeEvent {}

class SelectPlanningEvent extends HomeEvent {
  final String? planningId;
  SelectPlanningEvent(this.planningId);
}

class SelectBatchEvent extends HomeEvent {
  final String? batchId;
  SelectBatchEvent(this.batchId);
}

class RefreshBatchDevicesEvent extends HomeEvent {
  final String batchId;
  RefreshBatchDevicesEvent(this.batchId);
}

class SelectFirmwareEvent extends HomeEvent {
  final String? firmwareId;
  SelectFirmwareEvent(this.firmwareId);
}

class SubmitSerialEvent extends HomeEvent {
  final String serial;
  SubmitSerialEvent(this.serial);
}

class SelectLocalFileEvent extends HomeEvent {
  final String? filePath;
  SelectLocalFileEvent(this.filePath);
}

class RefreshPortsEvent extends HomeEvent {}

class SelectPortEvent extends HomeEvent {
  final String? port;
  SelectPortEvent(this.port);
}

class StartQrScanEvent extends HomeEvent {}

class UpdateDeviceStatusEvent extends HomeEvent {
  final String deviceId;
  final String status;
  UpdateDeviceStatusEvent(this.deviceId, this.status);
}

class FlashFirmwareEvent extends HomeEvent {}

class FetchBatchesEvent extends HomeEvent {}

class StatusUpdateEvent extends HomeEvent {
  final String deviceSerial;
  final bool isSuccessful;
  StatusUpdateEvent(this.deviceSerial, this.isSuccessful);
}

class CloseStatusDialogEvent extends HomeEvent {}

class HomeState {
  final List<Planning> plannings;
  final String? selectedPlanningId;
  final List<Batch> batches;
  final String? selectedBatchId;
  final List<Device> devices;
  final List<Firmware> firmwares;
  final String? selectedFirmwareId;
  final String? selectedSerial;
  final String? localFilePath;
  final List<String> availablePorts;
  final String? selectedPort;
  final bool isLocalFileMode;
  final bool isFlashing;
  final String? selectedDeviceId;
  final String? selectedDeviceType;
  final bool canFlash;
  final bool isLoading;
  final bool showStatusDialog;
  final String statusDialogType;
  final String statusDialogMessage;

  HomeState({
    this.plannings = const [],
    this.selectedPlanningId,
    this.batches = const [],
    this.selectedBatchId,
    this.devices = const [],
    this.firmwares = const [],
    this.selectedFirmwareId,
    this.selectedSerial,
    this.localFilePath,
    this.availablePorts = const [],
    this.selectedPort,
    this.isLocalFileMode = false,
    this.isFlashing = false,
    this.selectedDeviceId,
    this.selectedDeviceType,
    this.canFlash = false,
    this.isLoading = false,
    this.showStatusDialog = false,
    this.statusDialogType = '',
    this.statusDialogMessage = '',
  });

  HomeState copyWith({
    List<Planning>? plannings,
    String? selectedPlanningId,
    List<Batch>? batches,
    String? selectedBatchId,
    List<Device>? devices,
    List<Firmware>? firmwares,
    String? selectedFirmwareId,
    String? selectedSerial,
    String? localFilePath,
    List<String>? availablePorts,
    String? selectedPort,
    bool? isLocalFileMode,
    bool? isFlashing,
    String? selectedDeviceId,
    String? selectedDeviceType,
    bool? canFlash,
    bool? isLoading,
    bool? showStatusDialog,
    String? statusDialogType,
    String? statusDialogMessage,
  }) {
    return HomeState(
      plannings: plannings ?? this.plannings,
      selectedPlanningId: selectedPlanningId ?? this.selectedPlanningId,
      batches: batches ?? this.batches,
      selectedBatchId: selectedBatchId ?? this.selectedBatchId,
      devices: devices ?? this.devices,
      firmwares: firmwares ?? this.firmwares,
      selectedFirmwareId: selectedFirmwareId ?? this.selectedFirmwareId,
      selectedSerial: selectedSerial ?? this.selectedSerial,
      localFilePath: localFilePath ?? this.localFilePath,
      availablePorts: availablePorts ?? this.availablePorts,
      selectedPort: selectedPort ?? this.selectedPort,
      isLocalFileMode: isLocalFileMode ?? this.isLocalFileMode,
      isFlashing: isFlashing ?? this.isFlashing,
      selectedDeviceId: selectedDeviceId ?? this.selectedDeviceId,
      selectedDeviceType: selectedDeviceType ?? this.selectedDeviceType,
      canFlash: canFlash ?? this.canFlash,
      isLoading: isLoading ?? this.isLoading,
      showStatusDialog: showStatusDialog ?? this.showStatusDialog,
      statusDialogType: statusDialogType ?? this.statusDialogType,
      statusDialogMessage: statusDialogMessage ?? this.statusDialogMessage,
    );
  }
}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final ApiService _apiService = GetIt.instance<ApiService>();
  final ArduinoService _arduinoService = GetIt.instance<ArduinoService>();
  final BluetoothService _bluetoothService = GetIt.instance<BluetoothService>();
  bool _disposed = false;

  HomeBloc() : super(HomeState()) {
    on<LoadInitialDataEvent>(_onLoadInitialData);
    on<SelectPlanningEvent>(_onSelectPlanning);
    on<SelectBatchEvent>(_onSelectBatch);
    on<RefreshBatchDevicesEvent>(_onRefreshBatchDevices);
    on<SelectFirmwareEvent>(_onSelectFirmware);
    on<SubmitSerialEvent>(_onSubmitSerial);
    on<SelectLocalFileEvent>(_onSelectLocalFile);
    on<RefreshPortsEvent>(_onRefreshPorts);
    on<SelectPortEvent>(_onSelectPort);
    on<StartQrScanEvent>(_onStartQrScan);
    on<UpdateDeviceStatusEvent>(_onUpdateDeviceStatus);
    on<FlashFirmwareEvent>(_onFlashFirmware);
    on<FetchBatchesEvent>(_onFetchBatches);
    on<StatusUpdateEvent>(_onStatusUpdate);
    on<CloseStatusDialogEvent>(_onCloseStatusDialog);
  }

  @override
  Future<void> close() async {
    _disposed = true;
    _bluetoothService.stop();
    await super.close();
  }

  // Prevent emitting states after the bloc is closed
  void safeEmit(Emitter<HomeState> emit, HomeState newState) {
    if (!_disposed) {
      emit(newState);
    }
  }

  Future<void> _onFetchBatches(
    FetchBatchesEvent event,
    Emitter<HomeState> emit,
  ) async {
    try {
      if (state.selectedPlanningId == null) return;

      emit(state.copyWith(isLoading: true));

      print('Fetching batches for planning ${state.selectedPlanningId}...');
      final batches = await _apiService.fetchBatches(state.selectedPlanningId);
      print('Fetched ${batches.length} batches for planning ${state.selectedPlanningId}');

      emit(state.copyWith(
        batches: batches,
        isLoading: false,
      ));
    } catch (e) {
      print('Error fetching batches: $e');
      emit(state.copyWith(
        batches: [],
        isLoading: false,
      ));
    }
  }

  Future<void> _onLoadInitialData(
    LoadInitialDataEvent event,
    Emitter<HomeState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true));

      print('Fetching initial plannings...');
      final plannings = await _apiService.fetchPlannings();
      print('Fetched ${plannings.length} plannings');

      final ports = await _arduinoService.getAvailablePorts();
      print('Fetched ${ports.length} available ports');

      emit(state.copyWith(
        plannings: plannings,
        availablePorts: ports,
        isLoading: false,
      ));
    } catch (e) {
      print('Error loading initial data: $e');
      emit(state.copyWith(
        plannings: [],
        availablePorts: [],
        isLoading: false,
      ));
    }
  }

  Future<void> _onSelectPlanning(
    SelectPlanningEvent event,
    Emitter<HomeState> emit,
  ) async {
    try {
      print('Planning selected: ${event.planningId}');
      emit(state.copyWith(isLoading: true));

      // Clear all dependent state when switching plannings
      emit(state.copyWith(
        selectedPlanningId: event.planningId,
        selectedBatchId: null,
        batches: [], // Clear existing batches
        devices: [],
        firmwares: [],
        selectedFirmwareId: null, // Clear selected firmware
        selectedSerial: null, // Clear selected serial
      ));

      if (event.planningId != null) {
        // Fetch batches for selected planning
        final batches = await _apiService.fetchBatches(event.planningId);
        emit(state.copyWith(
          batches: batches,
          isLoading: false,
        ));
      } else {
        emit(state.copyWith(isLoading: false));
      }
    } catch (e) {
      print('Error selecting planning: $e');
      emit(state.copyWith(
        batches: [],
        selectedBatchId: null,
        devices: [],
        firmwares: [],
        selectedFirmwareId: null,
        selectedSerial: null,
        isLoading: false,
      ));
    }
  }

  Future<void> _onSelectBatch(
    SelectBatchEvent event,
    Emitter<HomeState> emit,
  ) async {
    try {
      print('Batch selected: ${event.batchId}');
      safeEmit(emit, state.copyWith(isLoading: true));

      // Reset device and firmware state
      safeEmit(emit, state.copyWith(
        selectedBatchId: event.batchId,
        devices: [],
        firmwares: [],
        selectedFirmwareId: null,
      ));

      if (event.batchId != null) {
        final batch = state.batches.firstWhere(
          (b) => b.id == event.batchId,
          orElse: () => throw Exception('Batch not found: ${event.batchId}'),
        );

        if (batch.templateId.isEmpty) {
          throw Exception('Template ID is empty for batch: ${event.batchId}');
        }

        print('Selected batch template ID: ${batch.templateId}');

        try {
          // Fetch devices first
          final devices = await _apiService.fetchDevices(event.batchId as String);

          // Then fetch firmwares
          final firmwares = await _apiService.fetchFirmwares(batch.templateId);

          if (!_disposed) {
            // Get default firmware from batch or template rules
            final defaultFirmware = await _apiService.getDefaultFirmware(
              batch.templateId,
              batch.firmwareId
            );

            print('Fetched ${devices.length} devices and ${firmwares.length} firmwares');

            safeEmit(emit, state.copyWith(
              devices: devices,
              firmwares: firmwares,
              selectedFirmwareId: defaultFirmware?.firmwareId.toString(),
              isLoading: false,
            ));
          }
        } catch (e) {
          print('Error fetching data: $e');
          if (!_disposed) {
            safeEmit(emit, state.copyWith(
              devices: [],
              firmwares: [],
              selectedFirmwareId: null,
              isLoading: false,
            ));
          }
        }
      } else {
        safeEmit(emit, state.copyWith(isLoading: false));
      }
    } catch (e) {
      print('Error selecting batch: $e');
      if (!_disposed) {
        safeEmit(emit, state.copyWith(
          devices: [],
          firmwares: [],
          selectedFirmwareId: null,
          isLoading: false,
        ));
      }
    }
  }

  Future<void> _onRefreshBatchDevices(
    RefreshBatchDevicesEvent event,
    Emitter<HomeState> emit,
  ) async {
    try {
      if (event.batchId.isNotEmpty) {
        // Fetch updated devices list
        final devices = await _apiService.fetchDevices(event.batchId);
        emit(state.copyWith(devices: devices));
      }
    } catch (e) {
      print('Error refreshing devices: $e');
    }
  }

  void _onSelectFirmware(SelectFirmwareEvent event, Emitter<HomeState> emit) {
    emit(state.copyWith(selectedFirmwareId: event.firmwareId));
  }

  void _onSubmitSerial(SubmitSerialEvent event, Emitter<HomeState> emit) {
    final device = state.devices.firstWhere(
      (d) => d.serial.trim().toLowerCase() == event.serial.trim().toLowerCase(),
      orElse: () => Device(id: '', batchId: '', serial: '', status: ''),
    );
    if (device.id.isNotEmpty && device.status == 'firmware_uploading') {
      emit(state.copyWith(selectedSerial: event.serial));
    }
  }

  void _onSelectLocalFile(SelectLocalFileEvent event, Emitter<HomeState> emit) {
    emit(
      state.copyWith(
        localFilePath: event.filePath,
        isLocalFileMode: event.filePath != null,
      ),
    );
  }

  Future<void> _onRefreshPorts(
    RefreshPortsEvent event,
    Emitter<HomeState> emit,
  ) async {
    final ports = await _arduinoService.getAvailablePorts();

    // Nếu port đang chọn không còn trong danh sách available, reset selected port
    if (state.selectedPort != null && !ports.contains(state.selectedPort)) {
      emit(state.copyWith(
        availablePorts: ports,
        selectedPort: null,
      ));
    } else {
      emit(state.copyWith(availablePorts: ports));
    }
  }

  void _onSelectPort(SelectPortEvent event, Emitter<HomeState> emit) {
    emit(state.copyWith(selectedPort: event.port));
  }

  Future<void> _onStartQrScan(
    StartQrScanEvent event,
    Emitter<HomeState> emit,
  ) async {
    if (state.selectedBatchId != null) {
      await _bluetoothService.start(
        onSerialReceived: (serial) {
          add(SubmitSerialEvent(serial));
        },
      );
    }
  }

  Future<void> _onUpdateDeviceStatus(
    UpdateDeviceStatusEvent event,
    Emitter<HomeState> emit,
  ) async {
    try {
      bool isSuccessful;

      if (event.status == 'completed') {
        isSuccessful = true;
      } else if (event.status == 'error') {
        isSuccessful = false;
      } else {
        return;
      }

      // Update device status via API
      final result = await _apiService.updateDeviceStatusWithResult(
        deviceSerial: event.deviceId,
        isSuccessful: isSuccessful,
      );

      // Show result dialog
      emit(state.copyWith(
        showStatusDialog: true,
        statusDialogType: result['success'] == true ? 'success' : 'error',
        statusDialogMessage: result['message'] ?? (isSuccessful
          ? 'Cập nhật trạng thái thiết bị thành công'
          : 'Cập nhật trạng thái thiết bị thất bại'),
      ));

      // Always refresh devices list after status update
      if (state.selectedBatchId != null) {
        print('Refreshing devices list after status update...');
        final devices = await _apiService.fetchDevices(state.selectedBatchId!);
        emit(state.copyWith(devices: devices));
      }

    } catch (e) {
      print('Error updating device status: $e');
      emit(state.copyWith(
        showStatusDialog: true,
        statusDialogType: 'error',
        statusDialogMessage: 'Lỗi cập nhật trạng thái: $e',
      ));

      // Still try to refresh devices list even after error
      if (state.selectedBatchId != null) {
        final devices = await _apiService.fetchDevices(state.selectedBatchId!);
        emit(state.copyWith(devices: devices));
      }
    }
  }

  Future<void> _onFlashFirmware(
    FlashFirmwareEvent event,
    Emitter<HomeState> emit,
  ) async {
    if (state.isLocalFileMode) {
      if (state.localFilePath != null &&
          state.selectedPort != null &&
          state.selectedSerial != null) {
        await _arduinoService.compileAndFlash(
          sketchPath: state.localFilePath!,
          port: state.selectedPort!,
          deviceId: state.selectedSerial!,
        );
      }
    } else {
      if (state.selectedFirmwareId != null &&
          state.selectedPort != null &&
          state.selectedSerial != null) {
        final firmware = state.firmwares.firstWhere(
          (f) => f.firmwareId.toString() == state.selectedFirmwareId,
        );
        await _arduinoService.compileAndFlash(
          sketchPath: firmware.filePath,
          port: state.selectedPort!,
          deviceId: state.selectedSerial!,
        );
      }
    }
  }

  Future<void> _onStatusUpdate(
    StatusUpdateEvent event,
    Emitter<HomeState> emit,
  ) async {
    try {
      final result = await _apiService.updateDeviceStatusWithResult(
        deviceSerial: event.deviceSerial,
        isSuccessful: event.isSuccessful,
      );

      // Show result dialog
      emit(state.copyWith(
        showStatusDialog: true,
        statusDialogType: result['success'] == true ? 'success' : 'error',
        statusDialogMessage: result['message'] ?? (event.isSuccessful
          ? 'Cập nhật trạng thái thành công'
          : 'Lỗi cập nhật trạng thái'),
      ));

      // Always refresh devices list after status update
      if (state.selectedBatchId != null) {
        print('Refreshing devices list after status update...');
        final devices = await _apiService.fetchDevices(state.selectedBatchId!);
        emit(state.copyWith(devices: devices));
      }
    } catch (e) {
      print('Error in status update: $e');
      emit(state.copyWith(
        showStatusDialog: true,
        statusDialogType: 'error',
        statusDialogMessage: 'Lỗi cập nhật trạng thái: $e',
      ));

      // Still try to refresh devices list even after error
      if (state.selectedBatchId != null) {
        final devices = await _apiService.fetchDevices(state.selectedBatchId!);
        emit(state.copyWith(devices: devices));
      }
    }
  }

  void _onCloseStatusDialog(
    CloseStatusDialogEvent event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(
      showStatusDialog: false,
      statusDialogType: '',
      statusDialogMessage: '',
    ));
  }
}
