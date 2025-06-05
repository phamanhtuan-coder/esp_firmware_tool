import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/data/models/batch.dart';
import 'package:smart_net_firmware_loader/data/models/device.dart';
import 'package:smart_net_firmware_loader/data/models/firmware.dart';
import 'package:smart_net_firmware_loader/data/services/api_client.dart';
import 'package:smart_net_firmware_loader/data/services/arduino_service.dart';
import 'package:smart_net_firmware_loader/data/services/bluetooth_service.dart';
import 'package:get_it/get_it.dart';

abstract class HomeEvent {}

class LoadInitialDataEvent extends HomeEvent {}

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

class FlashFirmwareEvent extends HomeEvent {}

class HomeState {
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

  HomeState({
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
  });

  HomeState copyWith({
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
  }) {
    return HomeState(
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
    );
  }
}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final ApiService _apiService = GetIt.instance<ApiService>();
  final ArduinoService _arduinoService = GetIt.instance<ArduinoService>();
  final BluetoothService _bluetoothService = GetIt.instance<BluetoothService>();

  HomeBloc() : super(HomeState()) {
    on<LoadInitialDataEvent>(_onLoadInitialData);
    on<SelectBatchEvent>(_onSelectBatch);
    on<RefreshBatchDevicesEvent>(_onRefreshBatchDevices);
    on<SelectFirmwareEvent>(_onSelectFirmware);
    on<SubmitSerialEvent>(_onSubmitSerial);
    on<SelectLocalFileEvent>(_onSelectLocalFile);
    on<RefreshPortsEvent>(_onRefreshPorts);
    on<SelectPortEvent>(_onSelectPort);
    on<StartQrScanEvent>(_onStartQrScan);
    on<FlashFirmwareEvent>(_onFlashFirmware);
  }

  Future<void> _onLoadInitialData(
    LoadInitialDataEvent event,
    Emitter<HomeState> emit,
  ) async {
    final batches = await _apiService.fetchBatches();
    final ports = await _arduinoService.getAvailablePorts();
    emit(state.copyWith(batches: batches, availablePorts: ports));
  }

  Future<void> _onSelectBatch(
    SelectBatchEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(selectedBatchId: event.batchId));
    if (event.batchId != null) {
      final batch = state.batches.firstWhere((b) => b.id == event.batchId);
      final devices = await _apiService.fetchDevices(event.batchId!);
      final firmwares = await _apiService.fetchFirmwares(
        batch.templateId as int,
      );
      final defaultFirmwareId = batch.firmwareId?.toString();
      emit(
        state.copyWith(
          devices: devices,
          firmwares: firmwares,
          selectedFirmwareId: defaultFirmwareId,
        ),
      );
    }
  }

  Future<void> _onRefreshBatchDevices(
    RefreshBatchDevicesEvent event,
    Emitter<HomeState> emit,
  ) async {
    final devices = await _apiService.fetchDevices(event.batchId);
    emit(state.copyWith(devices: devices));
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
