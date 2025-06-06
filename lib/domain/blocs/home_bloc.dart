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
    );
  }
}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final ApiService _apiService = GetIt.instance<ApiService>();
  final ArduinoService _arduinoService = GetIt.instance<ArduinoService>();
  final BluetoothService _bluetoothService = GetIt.instance<BluetoothService>();

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
    on<FetchBatchesEvent>(_onFetchBatches); // Thêm handler mới
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
      emit(state.copyWith(isLoading: true));

      // Reset device and firmware state
      emit(state.copyWith(
        selectedBatchId: event.batchId,
        devices: [],
        firmwares: [],
        selectedFirmwareId: null,
      ));

      if (event.batchId != null) {
        final batch = state.batches.firstWhere((b) => b.id == event.batchId);
        print('Selected batch template ID: ${batch.templateId}');

        // Fetch devices and firmwares in parallel
        print('Fetching devices and firmwares...');
        final devicesAndFirmwaresFuture = Future.wait([
          _apiService.fetchDevices(event.batchId as String),
          _apiService.fetchFirmwares(int.parse(batch.templateId)),
        ]);

        final results = await devicesAndFirmwaresFuture;
        final devices = results[0] as List<Device>;
        final firmwares = results[1] as List<Firmware>;

        // Get default firmware from batch or template rules
        final defaultFirmware = await _apiService.getDefaultFirmware(
          int.parse(batch.templateId),
          batch.firmwareId
        );

        print('Fetched ${devices.length} devices and ${firmwares.length} firmwares');

        emit(state.copyWith(
          devices: devices,
          firmwares: firmwares,
          selectedFirmwareId: defaultFirmware?.firmwareId.toString(),
          isLoading: false,
        ));
      } else {
        emit(state.copyWith(isLoading: false));
      }
    } catch (e) {
      print('Error selecting batch: $e');
      emit(state.copyWith(
        devices: [],
        firmwares: [],
        selectedFirmwareId: null,
        isLoading: false,
      ));
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
      orElse: () => Device(id: '', batchId: '', serial: ''),
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
    emit(state.copyWith(availablePorts: ports));
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
      // Update device status via API
      await _apiService.updateDeviceStatus(event.deviceId, event.status);

      if (state.selectedBatchId != null) {
        // Refresh devices list after status update
        final devices = await _apiService.fetchDevices(state.selectedBatchId!);
        emit(state.copyWith(devices: devices));
      }
    } catch (e) {
      print('Error updating device status: $e');
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
}
