import 'dart:async';
import 'package:esp_firmware_tool/data/services/log_service.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:esp_firmware_tool/data/models/log_entry.dart';
import 'package:esp_firmware_tool/di/service_locator.dart';

class UsbDeviceEvent {
  final String deviceId;
  final String port;
  final bool connected;

  UsbDeviceEvent({
    required this.deviceId,
    required this.port,
    required this.connected,
  });
}

class UsbService {
  final StreamController<UsbDeviceEvent> _deviceStreamController = StreamController<UsbDeviceEvent>.broadcast();
  final Map<String, String> _connectedDevices = {};
  Timer? _portScanTimer;
  Set<String> _lastKnownPorts = {};
  final LogService _logService = serviceLocator<LogService>();

  Stream<UsbDeviceEvent> get deviceStream => _deviceStreamController.stream;

  UsbService() {
    _initPortScanning();
  }

  void _initPortScanning() {
    _scanForPorts();
    _portScanTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _scanForPorts();
    });
  }

  void _scanForPorts() {
    try {
      final currentPorts = SerialPort.availablePorts.where((port) => port.isNotEmpty).toSet();
      _logService.addLog(
        message: 'Scanning ports: Found ${currentPorts.length} ports: $currentPorts',
        level: LogLevel.info,
        step: ProcessStep.usbCheck,
        origin: 'system',
      );

      // Detect new connections
      for (final port in currentPorts) {
        if (!_lastKnownPorts.contains(port)) {
          final deviceId = _getDeviceIdFromPort(port);
          _registerDeviceConnection(deviceId, port);
        }
      }

      // Detect disconnections
      for (final port in _lastKnownPorts) {
        if (!currentPorts.contains(port)) {
          final deviceId = _connectedDevices.keys.firstWhere(
                (id) => _connectedDevices[id] == port,
            orElse: () => '',
          );
          if (deviceId.isNotEmpty) {
            _registerDeviceDisconnection(deviceId);
          }
        }
      }

      _lastKnownPorts = currentPorts;
    } catch (e) {
      _logService.addLog(
        message: 'Error scanning ports: $e',
        level: LogLevel.error,
        step: ProcessStep.usbCheck,
        origin: 'system',
      );
    }
  }

  String _getDeviceIdFromPort(String portName) {
    try {
      final port = SerialPort(portName);
      final serialNumber = port.serialNumber ?? 'unknown-$portName';
      port.close();
      return serialNumber;
    } catch (e) {
      _logService.addLog(
        message: 'Error getting device ID for $portName: $e',
        level: LogLevel.error,
        step: ProcessStep.usbCheck,
        origin: 'system',
      );
      return 'unknown-$portName';
    }
  }

  void _registerDeviceConnection(String deviceId, String port) {
    _connectedDevices[deviceId] = port;
    _deviceStreamController.add(
      UsbDeviceEvent(deviceId: deviceId, port: port, connected: true),
    );
    _logService.addLog(
      message: 'USB device connected: $deviceId on port $port',
      level: LogLevel.info,
      step: ProcessStep.systemEvent,
      deviceId: deviceId,
      origin: 'system',
    );
  }

  void _registerDeviceDisconnection(String deviceId) {
    final port = _connectedDevices.remove(deviceId) ?? 'unknown';
    _deviceStreamController.add(
      UsbDeviceEvent(deviceId: deviceId, port: port, connected: false),
    );
    _logService.addLog(
      message: 'USB device disconnected: $deviceId from port $port',
      level: LogLevel.info,
      step: ProcessStep.systemEvent,
      deviceId: deviceId,
      origin: 'system',
    );
  }

  bool connectToPort(String portName) {
    try {
      final port = SerialPort(portName);
      if (!port.openReadWrite()) {
        _logService.addLog(
          message: 'Failed to open port $portName',
          level: LogLevel.error,
          step: ProcessStep.usbCheck,
          origin: 'system',
        );
        return false;
      }

      // Configure port for Arduino CLI compatibility
      port.config = SerialPortConfig()
        ..baudRate = 115200
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none
        ..setFlowControl(SerialPortFlowControl.none);

      _logService.addLog(
        message: 'Connected to port $portName',
        level: LogLevel.success,
        step: ProcessStep.usbCheck,
        origin: 'system',
      );
      return true;
    } catch (e) {
      _logService.addLog(
        message: 'Error connecting to port $portName: $e',
        level: LogLevel.error,
        step: ProcessStep.usbCheck,
        origin: 'system',
      );
      return false;
    } finally {
      // Do not close the port immediately to allow Arduino CLI access
    }
  }

  String? getDevicePort(String deviceId) {
    // Trước hết, tìm trong map đã lưu
    final port = _connectedDevices[deviceId];
    if (port != null) {
      _logService.addLog(
        message: 'Device $deviceId found on port $port',
        level: LogLevel.info,
        step: ProcessStep.usbCheck,
        origin: 'system',
      );
      return port;
    }

    // Nếu không tìm thấy trong map, trả về port đầu tiên được tìm thấy
    final availablePorts = getAvailablePorts();
    if (availablePorts.isNotEmpty) {
      final selectedPort = availablePorts.first;
      _logService.addLog(
        message: 'Device $deviceId not registered but port $selectedPort is available. Using it.',
        level: LogLevel.warning,
        step: ProcessStep.usbCheck,
        origin: 'system',
      );
      // Lưu lại để sử dụng sau này
      _connectedDevices[deviceId] = selectedPort;
      return selectedPort;
    }

    // Nếu không có port nào, trả về null
    _logService.addLog(
      message: 'No ports available for device $deviceId',
      level: LogLevel.error,
      step: ProcessStep.usbCheck,
      origin: 'system',
    );
    return null;
  }

  bool isDeviceConnected(String deviceId) {
    return _connectedDevices.containsKey(deviceId);
  }

  List<String> getAvailablePorts() {
    try {
      return SerialPort.availablePorts;
    } catch (e) {
      _logService.addLog(
        message: 'Error getting available ports: $e',
        level: LogLevel.error,
        step: ProcessStep.usbCheck,
        origin: 'system',
      );
      return [];
    }
  }

  Future<void> dispose() async {
    _portScanTimer?.cancel();
    await _deviceStreamController.close();
  }
}