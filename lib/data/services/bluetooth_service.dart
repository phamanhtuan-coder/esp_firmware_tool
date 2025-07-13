import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:smart_net_firmware_loader/core/utils/debug_logger.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as bt; // Using flutter_bluetooth_serial for Windows

import 'auth_service.dart';

class BluetoothProtocol {
  static const String serviceUuid = "0000110E-0000-1000-8000-00805F9B34FB";
  static const String characteristicUuid = "0000110A-0000-1000-8000-00805F9B34FB";
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration dataTimeout = Duration(seconds: 5);
  static const int maxRetries = 3;
}

class BluetoothDeviceInfo {
  final String name;
  final String address;
  final bool isConnected;
  final bool isAuthenticated;

  BluetoothDeviceInfo({
    required this.name,
    required this.address,
    this.isConnected = false,
    this.isAuthenticated = false,
  });

  @override
  String toString() => 'BluetoothDevice(name: $name, address: $address)';
}

class QrDataValidator {
  static bool validatePayload(Map<String, dynamic> data) {
    final requiredFields = ['type', 'username', 'serial_number', 'timestamp', 'checksum'];
    for (final field in requiredFields) {
      if (!data.containsKey(field)) {
        DebugLogger.e('Missing required field: $field');
        return false;
      }
    }
    final username = data['username'] as String;
    final serialNumber = data['serial_number'] as String;
    final providedChecksum = data['checksum'] as String;
    final calculatedChecksum = (username + serialNumber).hashCode.abs().toRadixString(16);
    if (providedChecksum != calculatedChecksum) {
      DebugLogger.e('Checksum validation failed');
      return false;
    }
    return true;
  }
}

class BluetoothService {
  bt.BluetoothConnection? _connection;
  StreamController<String>? _dataController;
  Function(String)? _onSerialReceived;
  Function(bool)? _onConnectionStatusChanged;
  bool _isScanning = false;
  bool _isPlatformSupported = true; // Assume Windows support with flutter_bluetooth_serial
  String? _connectedDeviceName;

  BluetoothService() {
    DebugLogger.d('Initializing BluetoothService', className: 'BluetoothService');
  }

  String? get connectedDeviceName => _connectedDeviceName;
  bool get isConnected => _connection?.isConnected ?? false;
  bool get isScanning => _isScanning;
  bool get isPlatformSupported => _isPlatformSupported;

  Future<bool> isBluetoothEnabled() async {
    try {
      return await bt.FlutterBluetoothSerial.instance.state == bt.BluetoothState.STATE_ON;
    } catch (e) {
      DebugLogger.e('Error checking Bluetooth state: $e');
      return false;
    }
  }

  Future<bool> requestBluetoothEnable() async {
    try {
      await bt.FlutterBluetoothSerial.instance.requestEnable();
      return await isBluetoothEnabled();
    } catch (e) {
      DebugLogger.e('Error enabling Bluetooth: $e');
      return false;
    }
  }

  Future<List<BluetoothDeviceInfo>> getPairedDevices() async {
    try {
      final bondedDevices = await bt.FlutterBluetoothSerial.instance.getBondedDevices();
      final devices = bondedDevices
          .map((device) => BluetoothDeviceInfo(
        name: device.name ?? 'Unknown Device',
        address: device.address,
        isAuthenticated: device.isBonded,
      ))
          .toList();
      DebugLogger.d('Found ${devices.length} paired devices', className: 'BluetoothService', methodName: 'getPairedDevices');
      return devices;
    } catch (e) {
      DebugLogger.e('Error getting paired devices: $e');
      return [
        BluetoothDeviceInfo(
          name: 'QR Scanner Device (Test)',
          address: '00:11:22:33:44:55',
          isAuthenticated: true,
        ),
      ];
    }
  }

  Future<bool> connectToDevice(BluetoothDeviceInfo device) async {
    try {
      DebugLogger.d('Connecting to device: ${device.name}', className: 'BluetoothService', methodName: 'connectToDevice');
      await disconnect();
      _connection = await bt.BluetoothConnection.toAddress(device.address);
      _connectedDeviceName = device.name;
      _dataController = StreamController<String>.broadcast();

      // Fix the stream transformer issue
      _connection!.input!.listen(
        (Uint8List data) {
          try {
            final String decodedData = utf8.decode(data);
            final List<String> lines = const LineSplitter().convert(decodedData);
            for (String line in lines) {
              if (line.trim().isNotEmpty) {
                DebugLogger.d('Received data: $line', className: 'BluetoothService');
                _dataController?.add(line);
              }
            }
          } catch (e) {
            DebugLogger.e('Error decoding data: $e');
          }
        },
        onError: (e) {
          DebugLogger.e('Connection error: $e');
          _onConnectionStatusChanged?.call(false);
        },
        onDone: () {
          DebugLogger.d('Connection closed');
          _onConnectionStatusChanged?.call(false);
        },
      );
      _onConnectionStatusChanged?.call(true);
      DebugLogger.d('Connected to ${device.name}');
      return true;
    } catch (e) {
      DebugLogger.e('Error connecting to device: $e');
      _onConnectionStatusChanged?.call(false);
      return false;
    }
  }

  Future<void> startScanning({
    required Function(String) onSerialReceived,
    Function(bool)? onConnectionStatusChanged,
  }) async {
    _onSerialReceived = onSerialReceived;
    _onConnectionStatusChanged = onConnectionStatusChanged;
    if (!isConnected) {
      DebugLogger.e('No active connection. Please connect to a device first.');
      return;
    }
    try {
      _isScanning = true;
      DebugLogger.d('Started listening for QR data');
      _dataController!.stream.listen(
            (data) {
          try {
            if (data.trim().isNotEmpty) {
              DebugLogger.d('Received QR data: $data');
              _handleQrData(data.trim(), onSerialReceived);
              stopScanning();
            }
          } catch (e) {
            DebugLogger.e('Error processing data: $e');
          }
        },
        onError: (error) {
          DebugLogger.e('Data stream error: $error');
          _isScanning = false;
        },
        onDone: () {
          DebugLogger.d('Data stream closed');
          _isScanning = false;
        },
      );
      // Send ready signal
      final readyMessage = jsonEncode({
        'type': 'ready',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }) + '\n';
      _connection!.output.add(utf8.encode(readyMessage));
      DebugLogger.d('Sent ready signal');
    } catch (e) {
      DebugLogger.e('Error starting scanning: $e');
      _isScanning = false;
    }
  }

  void _handleQrData(String data, Function(String) onSerialReceived) {
    try {
      final jsonData = jsonDecode(data) as Map<String, dynamic>;
      if (!QrDataValidator.validatePayload(jsonData)) {
        DebugLogger.e('Invalid QR data payload');
        return;
      }
      final username = jsonData['username'] as String;
      final serialNumber = jsonData['serial_number'] as String;
      final authService = GetIt.instance<AuthService>();
      final currentUsername = authService.getUsername();
      if (currentUsername != username) {
        DebugLogger.e('Username mismatch: expected $currentUsername, got $username');
        return;
      }
      // Send acknowledgment
      final ackMessage = jsonEncode({
        'type': 'ack',
        'status': 'received',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }) + '\n';
      _connection!.output.add(utf8.encode(ackMessage));
      onSerialReceived(serialNumber);
      DebugLogger.d('Processed QR data for serial: $serialNumber');
    } catch (e) {
      DebugLogger.e('Error processing QR data: $e');
    }
  }

  void stopScanning() {
    _isScanning = false;
    DebugLogger.d('Stopped scanning');
  }

  Future<void> disconnect() async {
    try {
      await _connection?.finish();
      _connection = null;
      _connectedDeviceName = null;
      _isScanning = false;
      _onConnectionStatusChanged?.call(false);
      await _dataController?.close();
      _dataController = null;
      DebugLogger.d('Disconnected from Bluetooth device');
    } catch (e) {
      DebugLogger.e('Error disconnecting: $e');
    }
  }

  // Add the missing stop method
  Future<void> stop() async {
    try {
      stopScanning();
      await disconnect();
      DebugLogger.d('Bluetooth service stopped');
    } catch (e) {
      DebugLogger.e('Error stopping Bluetooth service: $e');
    }
  }

  void dispose() {
    stopScanning();
    disconnect();
  }
}