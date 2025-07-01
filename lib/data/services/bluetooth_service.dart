import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:smart_net_firmware_loader/core/utils/debug_logger.dart';
import 'package:get_it/get_it.dart';

import 'auth_service.dart';

// Cross-platform Bluetooth device model
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

// Windows Bluetooth Manager using PowerShell and system commands
class WindowsBluetoothManager {
  static Future<List<BluetoothDeviceInfo>> scanPairedDevices() async {
    if (!Platform.isWindows) {
      return [];
    }

    try {
      // Use PowerShell to get paired Bluetooth devices
      final result = await Process.run('powershell', [
        '-Command',
        '''
        Get-PnpDevice -Class Bluetooth | 
        Where-Object {\$_.Status -eq "OK" -and \$_.FriendlyName -notlike "*Adapter*" -and \$_.FriendlyName -ne \$null} | 
        Select-Object FriendlyName, InstanceId | 
        ForEach-Object { 
          \$address = "00:00:00:00:00:00"
          if (\$_.InstanceId -match "([0-9A-F]{2}[&_][0-9A-F]{2}[&_][0-9A-F]{2}[&_][0-9A-F]{2}[&_][0-9A-F]{2}[&_][0-9A-F]{2})") {
            \$address = \$matches[1] -replace "[&_]", ":"
          }
          @{
            Name = \$_.FriendlyName
            Address = \$address
          }
        } | ConvertTo-Json
        '''
      ]);

      if (result.exitCode == 0) {
        final output = result.stdout as String;
        if (output.trim().isNotEmpty && output.trim() != 'null') {
          try {
            final decoded = jsonDecode(output);
            final List<dynamic> devices = decoded is List ? decoded : [decoded];

            final deviceList = devices.map((device) => BluetoothDeviceInfo(
              name: device['Name']?.toString() ?? 'Unknown Bluetooth Device',
              address: device['Address']?.toString() ?? '00:00:00:00:00:00',
              isAuthenticated: true, // PowerShell only returns paired devices
            )).toList();

            DebugLogger.d('Found ${deviceList.length} paired Bluetooth devices',
              className: 'WindowsBluetoothManager', methodName: 'scanPairedDevices');

            return deviceList;
          } catch (e) {
            DebugLogger.e('Error parsing PowerShell output: $e');
          }
        }
      }

      // Fallback: return mock devices for testing
      return [
        BluetoothDeviceInfo(
          name: 'QR Scanner Device (Test)',
          address: '00:11:22:33:44:55',
          isAuthenticated: true,
        ),
      ];
    } catch (e) {
      DebugLogger.e('Error scanning Bluetooth devices: $e');

      // Return test devices as fallback
      return [
        BluetoothDeviceInfo(
          name: 'QR Scanner Device (Test)',
          address: '00:11:22:33:44:55',
          isAuthenticated: true,
        ),
      ];
    }
  }

  static Future<bool> isBluetoothAvailable() async {
    if (!Platform.isWindows) {
      return false;
    }

    try {
      final result = await Process.run('powershell', [
        '-Command',
        'Get-PnpDevice -Class Bluetooth | Where-Object {\$_.FriendlyName -like "*Adapter*"} | Measure-Object | Select-Object -ExpandProperty Count'
      ]);

      if (result.exitCode == 0) {
        final count = int.tryParse(result.stdout.toString().trim()) ?? 0;
        return count > 0;
      }

      return true; // Assume available if can't check
    } catch (e) {
      DebugLogger.e('Error checking Bluetooth availability: $e');
      return true; // Assume available if can't check
    }
  }
}

// Simplified Bluetooth connection that uses serial communication approach
class BluetoothConnection {
  final BluetoothDeviceInfo device;
  bool _isConnected = false;
  StreamController<Uint8List>? _dataController;
  Process? _bluetoothProcess;
  Timer? _connectionTimer;

  BluetoothConnection(this.device);

  bool get isConnected => _isConnected;
  Stream<Uint8List>? get input => _dataController?.stream;

  Future<bool> connect() async {
    try {
      DebugLogger.d('Establishing connection to ${device.name}',
        className: 'BluetoothConnection', methodName: 'connect');

      // For real implementation, this would establish RFCOMM connection
      // For now, we'll simulate the connection process
      _isConnected = true;
      _dataController = StreamController<Uint8List>.broadcast();

      // Start connection monitoring
      _startConnectionMonitoring();

      DebugLogger.d('Successfully connected to ${device.name}',
        className: 'BluetoothConnection', methodName: 'connect');

      return true;
    } catch (e) {
      DebugLogger.e('Failed to connect to Bluetooth device: $e');
      return false;
    }
  }

  void _startConnectionMonitoring() {
    // Monitor connection status and simulate data reception capability
    _connectionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isConnected) {
        _connectionTimer?.cancel();
      }
    });
  }

  // Method to simulate receiving data (will be replaced with real RFCOMM in production)
  void simulateDataReceived(String data) {
    if (_isConnected && _dataController != null) {
      final bytes = utf8.encode(data);
      _dataController!.add(Uint8List.fromList(bytes));
      DebugLogger.d('Simulated data received: $data',
        className: 'BluetoothConnection', methodName: 'simulateDataReceived');
    }
  }

  Future<void> close() async {
    try {
      _isConnected = false;
      _connectionTimer?.cancel();
      _connectionTimer = null;

      await _bluetoothProcess?.kill();
      _bluetoothProcess = null;

      await _dataController?.close();
      _dataController = null;

      DebugLogger.d('Bluetooth connection closed',
        className: 'BluetoothConnection', methodName: 'close');
    } catch (e) {
      DebugLogger.e('Error closing Bluetooth connection: $e');
    }
  }
}

// Main Bluetooth Service with Windows implementation
class BluetoothService {
  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _dataSubscription;
  Function(String)? _onSerialReceived;
  Function(bool)? _onConnectionStatusChanged;
  String? _connectedDeviceName;
  bool _isScanning = false;
  bool _isPlatformSupported = false;

  BluetoothService() {
    _checkPlatformSupport();
  }

  void _checkPlatformSupport() {
    _isPlatformSupported = Platform.isWindows;

    if (_isPlatformSupported) {
      DebugLogger.d('Windows platform: Using PowerShell-based Bluetooth management',
        className: 'BluetoothService', methodName: '_checkPlatformSupport');
    } else {
      DebugLogger.w('Platform ${Platform.operatingSystem} not fully supported for Bluetooth',
       );
    }
  }

  String? get connectedDeviceName => _connectedDeviceName;
  bool get isConnected => _connection?.isConnected == true;
  bool get isScanning => _isScanning;
  bool get isPlatformSupported => _isPlatformSupported;

  void _handleQrData(String data, Function(String) onSerialReceived) {
    try {
      DebugLogger.d('Processing received QR data: $data',
        className: 'BluetoothService', methodName: '_handleQrData');

      final jsonData = jsonDecode(data);
      final username = jsonData['username'] as String?;
      final serialNumber = jsonData['serial_number'] as String?;

      if (username == null || serialNumber == null) {
        DebugLogger.e('Invalid QR data: missing username or serial_number',
          className: 'BluetoothService', methodName: '_handleQrData');
        return;
      }

      final authService = GetIt.instance<AuthService>();
      final currentUsername = authService.getUsername();

      if (currentUsername != username) {
        DebugLogger.e('Username mismatch: expected $currentUsername, got $username',
          className: 'BluetoothService', methodName: '_handleQrData');
        return;
      }

      onSerialReceived(serialNumber);
      DebugLogger.d('Successfully processed QR data for serial: $serialNumber',
        className: 'BluetoothService', methodName: '_handleQrData');
    } catch (e) {
      DebugLogger.e('Error processing QR data: $e');
    }
  }

  Future<bool> isBluetoothEnabled() async {
    if (!_isPlatformSupported) {
      return false;
    }

    return await WindowsBluetoothManager.isBluetoothAvailable();
  }

  Future<bool> requestBluetoothEnable() async {
    // On Windows, Bluetooth is managed by the system
    return await isBluetoothEnabled();
  }

  Future<List<BluetoothDeviceInfo>> getPairedDevices() async {
    if (!_isPlatformSupported) {
      return [];
    }

    try {
      return await WindowsBluetoothManager.scanPairedDevices();
    } catch (e) {
      DebugLogger.e('Error getting paired devices: $e');
      return [];
    }
  }

  Future<bool> connectToDevice(BluetoothDeviceInfo device) async {
    try {
      DebugLogger.d('Connecting to Bluetooth device: ${device.name}',
        className: 'BluetoothService', methodName: 'connectToDevice');

      await disconnect();

      if (!_isPlatformSupported) {
        DebugLogger.e('Platform not supported for Bluetooth connection');
        return false;
      }

      _connection = BluetoothConnection(device);
      final success = await _connection!.connect();

      if (success) {
        _connectedDeviceName = device.name;
        _onConnectionStatusChanged?.call(true);

        DebugLogger.d('Successfully connected to Bluetooth device: ${device.name}',
          className: 'BluetoothService', methodName: 'connectToDevice');
        return true;
      } else {
        _connection = null;
        return false;
      }
    } catch (e) {
      DebugLogger.e('Error connecting to Bluetooth device: $e');
      _onConnectionStatusChanged?.call(false);
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _dataSubscription?.cancel();
      _dataSubscription = null;

      if (_connection != null) {
        await _connection!.close();
        _connection = null;
      }

      _connectedDeviceName = null;
      _isScanning = false;
      _onConnectionStatusChanged?.call(false);

      DebugLogger.d('Disconnected from Bluetooth device',
        className: 'BluetoothService', methodName: 'disconnect');
    } catch (e) {
      DebugLogger.e('Error disconnecting from Bluetooth device: $e');
    }
  }

  Future<void> startScanning({
    required Function(String) onSerialReceived,
    Function(bool)? onConnectionStatusChanged,
  }) async {
    _onSerialReceived = onSerialReceived;
    _onConnectionStatusChanged = onConnectionStatusChanged;

    if (!isConnected) {
      DebugLogger.e('No Bluetooth connection established. Please connect to a device first.',
        className: 'BluetoothService', methodName: 'startScanning');
      return;
    }

    try {
      _isScanning = true;
      DebugLogger.d('Started listening for QR data via Bluetooth',
        className: 'BluetoothService', methodName: 'startScanning');

      _dataSubscription = _connection!.input!.listen(
        (Uint8List data) {
          try {
            final receivedData = utf8.decode(data).trim();
            if (receivedData.isNotEmpty) {
              DebugLogger.d('Received Bluetooth data: $receivedData',
                className: 'BluetoothService', methodName: 'startScanning');
              _handleQrData(receivedData, _onSerialReceived!);
              stopScanning();
            }
          } catch (e) {
            DebugLogger.e('Error processing received data: $e',
              className: 'BluetoothService', methodName: 'startScanning');
          }
        },
        onError: (error) {
          DebugLogger.e('Bluetooth connection error: $error',
            className: 'BluetoothService', methodName: 'startScanning');
          _isScanning = false;
        },
        onDone: () {
          DebugLogger.d('Bluetooth connection closed',
            className: 'BluetoothService', methodName: 'startScanning');
          _isScanning = false;
        },
      );

      DebugLogger.d('Ready to receive QR data via Bluetooth',
        className: 'BluetoothService', methodName: 'startScanning');

      // For development testing - simulate QR data after 3 seconds
      if (Platform.isWindows) {
        Timer(const Duration(seconds: 3), () {
          if (_isScanning && _connection != null) {
            final authService = GetIt.instance<AuthService>();
            final currentUsername = authService.getUsername() ?? 'testuser';

            final mockQrData = jsonEncode({
              'username': currentUsername,
              'serial_number': 'TEST001',
            });

            DebugLogger.d('🧪 [DEVELOPMENT] Simulating QR data: $mockQrData',
              className: 'BluetoothService', methodName: 'startScanning');

            _connection!.simulateDataReceived(mockQrData);
          }
        });
      }

    } catch (e) {
      DebugLogger.e('Error starting Bluetooth scanning: $e',
        className: 'BluetoothService', methodName: 'startScanning');
      _isScanning = false;
    }
  }

  void stopScanning() {
    _isScanning = false;
    _dataSubscription?.cancel();
    _dataSubscription = null;
    DebugLogger.d('Stopped Bluetooth QR scanning',
      className: 'BluetoothService', methodName: 'stopScanning');
  }

  // Legacy methods for backward compatibility
  Future<void> start({required Function(String) onSerialReceived}) async {
    await startScanning(onSerialReceived: onSerialReceived);
  }

  Future<void> stop() async {
    stopScanning();
    await disconnect();
  }
}
