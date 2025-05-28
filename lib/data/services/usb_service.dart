import 'dart:async';
import 'package:flutter_libserialport/flutter_libserialport.dart';

/// Class to represent a USB device connection/disconnection event
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

/// Service to manage USB device connections and disconnections
class UsbService {
  // Stream controller for broadcasting USB device events
  final _deviceStreamController = StreamController<UsbDeviceEvent>.broadcast();

  // Map to store connected USB devices and their ports
  final Map<String, String> _connectedDevices = {};

  // Timer for periodic port scanning
  Timer? _portScanTimer;

  // Last known available ports to detect changes
  Set<String> _lastKnownPorts = {};

  /// Public stream for listening to USB device events
  Stream<UsbDeviceEvent> get deviceStream => _deviceStreamController.stream;

  UsbService() {
    // Initialize port scanning
    _initPortScanning();
  }

  void _initPortScanning() {
    // Initial port scan
    _scanForPorts();

    // Set up periodic port scanning (every 2 seconds)
    _portScanTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _scanForPorts();
    });
  }

  void _scanForPorts() {
    try {
      // Get currently available ports
      final currentPorts = SerialPort.availablePorts
          .where((port) => port.isNotEmpty)
          .toSet();

      print('Scanning ports: Found ${currentPorts.length} ports: $currentPorts');

      // Check for new ports (connections)
      for (final port in currentPorts) {
        if (!_lastKnownPorts.contains(port)) {
          // New port detected - device connected
          _registerDeviceConnection(_getDeviceIdFromPort(port), port);
        }
      }

      // Check for removed ports (disconnections)
      for (final port in _lastKnownPorts) {
        if (!currentPorts.contains(port)) {
          final deviceId = _connectedDevices.keys
              .firstWhere((id) => _connectedDevices[id] == port, orElse: () => '');

          if (deviceId.isNotEmpty) {
            _registerDeviceDisconnection(deviceId);
          }
        }
      }

      // Update last known ports
      _lastKnownPorts = currentPorts;
    } catch (e, stackTrace) {
      print('Error scanning ports: $e');
      print('Stack trace: $stackTrace');
    }
  }

  String _getDeviceIdFromPort(String portName) {
    SerialPort? port;
    try {
      port = SerialPort(portName);

      // Try to open the port with a timeout
      if (!port.openReadWrite()) {
        final errorCode = SerialPort.lastError;
        print('Error opening port: $portName - Error code: $errorCode');
        return 'unknown-$portName';
      }

      // Get port information
      final manufacturer = port.manufacturer ?? 'Unknown';
      final description = port.description ?? '';
      final serialNumber = port.serialNumber ?? '';

      print('Port $portName info: Manufacturer: $manufacturer, Description: $description, Serial: $serialNumber');

      // Create a unique ID based on available information
      if (serialNumber.isNotEmpty) {
        return serialNumber;
      }

      return '$manufacturer-$description-$portName'
          .replaceAll(' ', '_')
          .replaceAll('/', '_');

    } catch (e, stackTrace) {
      print('Error getting device ID for $portName: $e');
      print('Stack trace: $stackTrace');
      return 'unknown-$portName';
    } finally {
      try {
        port?.close();
      } catch (e) {
        print('Error closing port: $e');
      }
    }
  }

  /// Register a new USB device connection
  void _registerDeviceConnection(String deviceId, String port) {
    _connectedDevices[deviceId] = port;
    _deviceStreamController.add(
      UsbDeviceEvent(
        deviceId: deviceId,
        port: port,
        connected: true,
      ),
    );

    print('USB device connected: $deviceId on port $port');
  }

  /// Register a USB device disconnection
  void _registerDeviceDisconnection(String deviceId) {
    final port = _connectedDevices.remove(deviceId) ?? 'unknown';
    _deviceStreamController.add(
      UsbDeviceEvent(
        deviceId: deviceId,
        port: port,
        connected: false,
      ),
    );

    print('USB device disconnected: $deviceId from port $port');
  }

  /// Allow manually registering a device connection (for testing)
  void registerDeviceConnection(String deviceId, String port) {
    _registerDeviceConnection(deviceId, port);
  }

  /// Allow manually registering a device disconnection (for testing)
  void registerDeviceDisconnection(String deviceId) {
    _registerDeviceDisconnection(deviceId);
  }

  /// Get the port for a specific device ID
  String? getDevicePort(String deviceId) {
    return _connectedDevices[deviceId];
  }

  /// Check if a device is connected
  bool isDeviceConnected(String deviceId) {
    return _connectedDevices.containsKey(deviceId);
  }

  /// Get all available ports
  List<String> getAvailablePorts() {
    try {
      return SerialPort.availablePorts;
    } catch (e) {
      print('Error getting available ports: $e');
      return [];
    }
  }

  /// Connect to a specific port
  bool connectToPort(String portName) {
    try {
      final port = SerialPort(portName);
      final success = port.openReadWrite();
      if (success) {
        port.close(); // Just testing connectivity, close immediately
        return true;
      }
      return false;
    } catch (e) {
      print('Error connecting to port $portName: $e');
      return false;
    }
  }

  /// Get all connected devices
  Map<String, String> getConnectedDevices() {
    return Map.from(_connectedDevices);
  }

  /// Clean up resources
  Future<void> dispose() async {
    _portScanTimer?.cancel();
    await _deviceStreamController.close();
  }
}