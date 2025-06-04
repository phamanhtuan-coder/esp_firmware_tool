import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:smart_net_firmware_loader/utils/debug_logger.dart';

class BluetoothServer {
  final LogService logService;
  ServerSocket? _server;
  bool _isRunning = false;
  int _port = 12345;
  Function(String)? _onSerialReceived;
  Timer? _scanTimeoutTimer;
  static const Duration scanTimeout = Duration(seconds: 60); // 60 seconds timeout

  BluetoothServer({required this.logService});

  bool get isRunning => _isRunning;
  int get port => _port;
  String get serverAddress => _server?.address.address ?? 'not running';

  /// Starts the Bluetooth server to listen for incoming connections
  Future<bool> start({
    required void Function(String) onSerialReceived,
    int port = 12345,
  }) async {
    DebugLogger.d('Starting Bluetooth server on port $port', className: 'BluetoothServer', methodName: 'start');

    if (_isRunning) {
      DebugLogger.i('Server already running on $serverAddress:$_port');
      logService.addLog(
        message: '🔵 Server already running on $serverAddress:$_port',
        level: LogLevel.info,
        step: ProcessStep.scanQrCode,
        origin: 'bluetooth-server',
      );
      return true;
    }

    try {
      // Check if port is available first
      try {
        final socket = await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
        await socket.close();
      } catch (e) {
        DebugLogger.w('Port $port is not available, trying alternative port');
        // Try an alternative port
        port = 12346;
      }

      _port = port;
      _onSerialReceived = onSerialReceived;

      // Try to bind with more detailed error logging
      try {
        _server = await ServerSocket.bind(
          InternetAddress.anyIPv4,
          port,
          shared: true, // Allow port sharing
        );
      } catch (e) {
        throw Exception('Failed to bind to port $port. Please check if the port is available and not blocked by firewall. Error: $e');
      }

      _isRunning = true;

      final localAddresses = await NetworkInterface.list();
      String addressInfo = 'Available on:\n';
      for (var interface in localAddresses) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            addressInfo += '  http://${addr.address}:$port\n';
          }
        }
      }

      DebugLogger.i('Server started successfully.\n$addressInfo');
      logService.addLog(
        message: '🟢 Server listening on multiple addresses:\n$addressInfo',
        level: LogLevel.success,
        step: ProcessStep.scanQrCode,
        origin: 'bluetooth-server',
      );

      // Start scan timeout timer
      _startScanTimeoutTimer();

      _server!.listen(_handleClient);
      return true;
    } catch (e) {
      DebugLogger.e('Failed to start server', error: e);
      logService.addLog(
        message: '❌ Server error: $e\nPlease check your firewall settings and make sure port $port is not blocked.',
        level: LogLevel.error,
        step: ProcessStep.scanQrCode,
        origin: 'bluetooth-server',
      );
      return false;
    }
  }

  void _startScanTimeoutTimer() {
    // Cancel any existing timer
    _scanTimeoutTimer?.cancel();

    // Start a new timer
    _scanTimeoutTimer = Timer(scanTimeout, () {
      logService.addLog(
        message: '⏱️ QR scan timed out after ${scanTimeout.inSeconds} seconds',
        level: LogLevel.warning,
        step: ProcessStep.scanQrCode,
        origin: 'bluetooth-server',
      );
      // Stop the server after timeout
      stop();
    });
  }

  void _resetScanTimeoutTimer() {
    _startScanTimeoutTimer();
  }

  void _handleClient(Socket client) {
    DebugLogger.d('Client connected: ${client.remoteAddress.address}:${client.remotePort}',
      className: 'BluetoothServer', methodName: '_handleClient');

    logService.addLog(
      message: '📡 Client connected from ${client.remoteAddress.address}',
      level: LogLevel.info,
      step: ProcessStep.scanQrCode,
      origin: 'bluetooth-server',
    );

    client.listen(
      (data) {
        final message = utf8.decode(data).trim();

        DebugLogger.d('Received data from ${client.remoteAddress.address}: $message',
          className: 'BluetoothServer', methodName: '_handleClient');

        logService.addLog(
          message: '📥 Received data: $message',
          level: LogLevel.info,
          step: ProcessStep.scanQrCode,
          origin: 'bluetooth-server',
        );

        _handleReceivedData(client, message);
      },
      onError: (error) {
        DebugLogger.e('Client error', error: error);
        logService.addLog(
          message: '❌ Client error: $error',
          level: LogLevel.error,
          step: ProcessStep.scanQrCode,
          origin: 'bluetooth-server',
        );
      },
      onDone: () {
        DebugLogger.d('Client disconnected: ${client.remoteAddress.address}',
          className: 'BluetoothServer', methodName: '_handleClient');

        logService.addLog(
          message: '🔌 Client disconnected: ${client.remoteAddress.address}',
          level: LogLevel.info,
          step: ProcessStep.scanQrCode,
          origin: 'bluetooth-server',
        );
        client.destroy();
      },
    );
  }

  void _handleReceivedData(Socket client, String message) {
    String? serialNumber;
    bool isValid = false;

    try {
      // Try to parse as JSON and extract serial number
      Map<String, dynamic> jsonData = json.decode(message);
      if (jsonData.containsKey('type') && jsonData['type'] == 'serial_data' &&
          jsonData.containsKey('data')) {
        serialNumber = jsonData['data'].toString();
        isValid = serialNumber.isNotEmpty && serialNumber.length >= 3;
      }
    } catch (e) {
      // If parsing fails, use the raw message as fallback
      serialNumber = message;
      isValid = serialNumber.isNotEmpty && serialNumber.length >= 3;
    }

    // Reset the timer whenever we receive any data to extend the timeout
    _resetScanTimeoutTimer();

    if (isValid && serialNumber != null) {
      DebugLogger.i('Valid serial received: $serialNumber');
      logService.addLog(
        message: '✅ Valid serial received: $serialNumber',
        level: LogLevel.success,
        step: ProcessStep.scanQrCode,
        origin: 'bluetooth-server',
      );

      if (_onSerialReceived != null) {
        DebugLogger.d('Calling onSerialReceived callback with extracted serial: $serialNumber',
          className: 'BluetoothServer');
        _onSerialReceived!(serialNumber);

        // Cancel the timeout timer when we successfully receive a valid serial
        _scanTimeoutTimer?.cancel();
        _scanTimeoutTimer = null;
      }

      // Send acknowledgment back to client
      _sendAcknowledgment(client, true, 'Serial received successfully');
    } else {
      DebugLogger.w('Invalid serial format received: $message');
      logService.addLog(
        message: '❌ Invalid serial format: $message',
        level: LogLevel.warning,
        step: ProcessStep.scanQrCode,
        origin: 'bluetooth-server',
      );

      // Send error response back to client
      _sendAcknowledgment(client, false, 'Invalid serial format');

      // Note: We DO NOT stop listening for data here, we continue until timeout
    }
  }

  void _sendAcknowledgment(Socket client, bool success, String message) {
    try {
      final response = jsonEncode({
        'success': success,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      });

      DebugLogger.d('Sending acknowledgment: $response',
        className: 'BluetoothServer', methodName: '_sendAcknowledgment');

      client.write(response);
    } catch (e) {
      DebugLogger.e('Error sending acknowledgment', error: e);
      logService.addLog(
        message: '❌ Error sending acknowledgment: $e',
        level: LogLevel.error,
        step: ProcessStep.scanQrCode,
        origin: 'bluetooth-server',
      );
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    DebugLogger.d('Stopping server', className: 'BluetoothServer', methodName: 'stop');

    try {
      // Cancel any active timeout timer
      _scanTimeoutTimer?.cancel();
      _scanTimeoutTimer = null;

      await _server?.close();
      _server = null;
      _isRunning = false;
      _onSerialReceived = null;

      DebugLogger.i('Server stopped successfully');
      logService.addLog(
        message: '🔴 Server stopped',
        level: LogLevel.info,
        step: ProcessStep.scanQrCode,
        origin: 'bluetooth-server',
      );
    } catch (e) {
      DebugLogger.e('Error stopping server', error: e);
      logService.addLog(
        message: '❌ Error stopping server: $e',
        level: LogLevel.error,
        step: ProcessStep.scanQrCode,
        origin: 'bluetooth-server',
      );
    }
  }
}
