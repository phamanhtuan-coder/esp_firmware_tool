import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/data/repositories/socket_repository.dart';
import 'package:esp_firmware_tool/utils/enums.dart';
import 'package:esp_firmware_tool/data/models/device.dart';
import 'package:esp_firmware_tool/presentation/blocs/device/device_event.dart';
import 'package:esp_firmware_tool/presentation/blocs/device/device_state.dart';

class DeviceBloc extends Bloc<DeviceEvent, DeviceState> {
  final ISocketRepository socketRepository;
  StreamSubscription? _devicesSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _deviceLogsSubscription;

  // Timer for continuous USB port scanning
  Timer? _usbScanTimer;
  final Duration _scanInterval = const Duration(seconds: 10); // Scan every 10 seconds

  DeviceBloc({required this.socketRepository}) : super(const DeviceState()) {
    on<StartProcess>(_onStartProcess);
    on<StopProcess>(_onStopProcess);
    on<FetchDevices>(_onFetchDevices);
    on<UpdateStatus>(_onUpdateStatus);
    on<SelectTemplate>(_onSelectTemplate);
    on<ViewDeviceLogs>(_onViewDeviceLogs);
    on<CheckUsbConnection>(_onCheckUsbConnection);
    on<SetSerialNumber>(_onSetSerialNumber);
    on<ScanUsbPorts>(_onScanUsbPorts);
    on<SelectUsbPort>(_onSelectUsbPort);

    // Initialize connection and start listening to device updates
    _initialize();
  }

  void _initialize() {
    socketRepository.connect();

    // Listen to status updates
    _statusSubscription = socketRepository.getStatus().listen((status) {
      add(UpdateStatus(status));
    });

    // Start fetching devices
    add(FetchDevices());

    // Initial USB port scan when the app starts
    add(const ScanUsbPorts());

    // Start the timer for continuous USB scanning
    _startUsbScanTimer();
  }

  void _startUsbScanTimer() {
    // Cancel any existing timer
    _usbScanTimer?.cancel();

    // Create a new periodic timer
    _usbScanTimer = Timer.periodic(_scanInterval, (_) {
      add(const ScanUsbPorts()); // Use silent mode to avoid showing loading indicators for background scans
    });
  }

  void _onSetSerialNumber(SetSerialNumber event, Emitter<DeviceState> emit) {
    emit(state.copyWith(serialNumber: event.serialNumber));
    // When a serial number is set, try to scan USB ports
    add(const ScanUsbPorts());
  }

  Future<void> _onScanUsbPorts(ScanUsbPorts event, Emitter<DeviceState> emit) async {
    try {
      // Only update status to checking if not in silent mode
      if (!event.silent) {
        emit(state.copyWith(status: DeviceStatus.checking, isScanning: true));
      } else {
        emit(state.copyWith(isScanning: true));
      }

      // Call the repository to scan for USB ports
      final result = await socketRepository.scanUsbPorts()
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => {
            'success': true,
            'ports': state.availablePorts,
            'message': 'Using cached ports (scan timed out)'
          },
        );

      if (result['success'] == true) {
        final ports = (result['ports'] as List<dynamic>).map((e) => e.toString()).toList();
        String? selectedPort = state.selectedPort;

        // If we have a current selection, try to keep it if it's still valid
        if (selectedPort != null && !ports.contains(selectedPort) && ports.isNotEmpty) {
          selectedPort = ports[0]; // Fall back to first available port if current selection is no longer valid
        } else if (selectedPort == null && ports.isNotEmpty) {
          selectedPort = ports[0]; // Select first port by default if none was selected before
        }

        emit(state.copyWith(
          availablePorts: ports,
          selectedPort: selectedPort,
          status: !event.silent ? DeviceStatus.connected : state.status, // Only update status if not silent
          isScanning: false,
          error: null,
          lastScanTime: DateTime.now(),
        ));
      } else {
        final errorMessage = result['error'] as String? ?? 'Failed to scan USB ports';

        if (!event.silent) {
          emit(state.copyWith(
            status: DeviceStatus.error,
            isScanning: false,
            error: errorMessage,
            lastScanTime: DateTime.now(),
          ));
        } else {
          emit(state.copyWith(
            isScanning: false,
            lastScanTime: DateTime.now(),
          ));
        }
      }
    } catch (e) {
      if (!event.silent) {
        emit(state.copyWith(
          status: DeviceStatus.error,
          isScanning: false,
          error: 'Failed to scan USB ports: ${e.toString()}',
          lastScanTime: DateTime.now(),
        ));
      } else {
        emit(state.copyWith(
          isScanning: false,
          lastScanTime: DateTime.now(),
        ));
      }
    }
  }

  void _onSelectUsbPort(SelectUsbPort event, Emitter<DeviceState> emit) {
    emit(state.copyWith(selectedPort: event.port));
  }

  Future<void> _onStartProcess(StartProcess event, Emitter<DeviceState> emit) async {
    // Check if we have all the necessary information
    if (state.serialNumber == null || state.serialNumber!.isEmpty) {
      emit(state.copyWith(
        status: DeviceStatus.error,
        error: 'Please enter a device serial number',
      ));
      return;
    }

    if (state.selectedTemplate == null || state.selectedTemplate!.isEmpty) {
      emit(state.copyWith(
        status: DeviceStatus.error,
        error: 'Please select a template file',
      ));
      return;
    }

    if (state.selectedPort == null || state.selectedPort!.isEmpty) {
      emit(state.copyWith(
        status: DeviceStatus.error,
        error: 'No USB port selected or available',
      ));
      return;
    }

    emit(state.copyWith(status: DeviceStatus.compiling));
    try {
      // Now include the serial number and port information when starting the process
      await socketRepository.startProcess(
        state.selectedTemplate,
        serialNumber: state.serialNumber,
        port: state.selectedPort,
      );
    } catch (e) {
      emit(state.copyWith(
        status: DeviceStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onStopProcess(StopProcess event, Emitter<DeviceState> emit) async {
    try {
      await socketRepository.stopProcess();
      emit(state.copyWith(status: DeviceStatus.connected));
    } catch (e) {
      emit(state.copyWith(
        status: DeviceStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onFetchDevices(FetchDevices event, Emitter<DeviceState> emit) async {
    try {
      _devicesSubscription?.cancel();
      _devicesSubscription = socketRepository.getDevices().listen((devices) {
        emit(state.copyWith(devices: devices));
      });
    } catch (e) {
      emit(state.copyWith(
        status: DeviceStatus.error,
        error: e.toString(),
      ));
    }
  }

  void _onUpdateStatus(UpdateStatus event, Emitter<DeviceState> emit) {
    DeviceStatus newStatus;

    switch (event.status.toLowerCase()) {
      case 'connected':
        newStatus = DeviceStatus.connected;
        break;
      case 'compiling':
        newStatus = DeviceStatus.compiling;
        break;
      case 'flashing':
        newStatus = DeviceStatus.flashing;
        break;
      case 'done':
        newStatus = DeviceStatus.done;
        break;
      default:
        newStatus = DeviceStatus.error;
    }

    emit(state.copyWith(status: newStatus));
  }

  void _onSelectTemplate(SelectTemplate event, Emitter<DeviceState> emit) {
    emit(state.copyWith(selectedTemplate: event.path));
  }

  Future<void> _onViewDeviceLogs(ViewDeviceLogs event, Emitter<DeviceState> emit) async {
    emit(state.copyWith(selectedDeviceId: event.deviceId));

    // Switch log subscription to the selected device
    _deviceLogsSubscription?.cancel();
    _deviceLogsSubscription = socketRepository.getDeviceLogs(event.deviceId).listen((log) {
      // Handle logs in the LogView
    });
  }

  Future<void> _onCheckUsbConnection(CheckUsbConnection event, Emitter<DeviceState> emit) async {
    try {
      emit(state.copyWith(status: DeviceStatus.checking));

      final result = await socketRepository.checkUsbConnection(event.serialNumber);

      if (result['success'] == true) {
        // Device found, create a Device object from the result
        if (result.containsKey('device')) {
          final deviceData = result['device'] as Map<String, dynamic>;
          final device = Device.fromJson(deviceData);

          // Add the found device to the devices list if not already present
          final updatedDevices = List<Device>.from(state.devices);
          final existingDeviceIndex = updatedDevices.indexWhere((d) => d.id == device.id);

          if (existingDeviceIndex >= 0) {
            updatedDevices[existingDeviceIndex] = device;
          } else {
            updatedDevices.add(device);
          }

          emit(state.copyWith(
            devices: updatedDevices,
            status: DeviceStatus.connected,
            selectedDeviceId: device.id,
            error: null,
          ));
        } else {
          emit(state.copyWith(
            status: DeviceStatus.connected,
            error: null,
          ));
        }
      } else {
        // Device not found or error occurred
        final errorMessage = result['error'] as String? ?? 'Device not found';
        emit(state.copyWith(
          status: DeviceStatus.error,
          error: errorMessage,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: DeviceStatus.error,
        error: 'Failed to check USB connection: ${e.toString()}',
      ));
    }
  }

  @override
  Future<void> close() {
    _devicesSubscription?.cancel();
    _statusSubscription?.cancel();
    _deviceLogsSubscription?.cancel();
    _usbScanTimer?.cancel();
    socketRepository.disconnect();
    return super.close();
  }
}