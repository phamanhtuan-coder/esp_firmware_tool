import 'dart:convert';
import 'dart:io';
import 'package:esp_firmware_tool/data/models/log_entry.dart';
import 'package:esp_firmware_tool/data/services/log_service.dart';
import 'package:esp_firmware_tool/utils/debug_logger.dart';

class BluetoothServer {
  final LogService logService;
  ServerSocket? _server;
  bool _isRunning = false;
  int _port = 12345;
  Function(String)? _onSerialReceived;

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
      _port = port;
      _onSerialReceived = onSerialReceived;
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _isRunning = true;

      DebugLogger.i('Server started successfully on ${_server!.address.address}:$port');
      logService.addLog(
        message: '🟢 Server listening on ${_server!.address.address}:$port',
        level: LogLevel.success,
        step: ProcessStep.scanQrCode,
        origin: 'bluetooth-server',
      );

      _server!.listen(_handleClient);
      return true;
    } catch (e) {
      DebugLogger.e('Failed to start server', error: e);
      logService.addLog(
        message: '❌ Server error: $e',
        level: LogLevel.error,
        step: ProcessStep.scanQrCode,
        origin: 'bluetooth-server',
      );
      return false;
    }
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

        if (_isValidSerial(message)) {
          DebugLogger.i('Valid serial received: $message');
          logService.addLog(
            message: '✅ Valid serial received: $message',
            level: LogLevel.success,
            step: ProcessStep.scanQrCode,
            origin: 'bluetooth-server',
          );

          if (_onSerialReceived != null) {
            DebugLogger.d('Calling onSerialReceived callback', className: 'BluetoothServer');
            _onSerialReceived!(message);
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
        }
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

  bool _isValidSerial(String serial) {
    // Add your validation logic here
    // For example, checking format, length, or pattern
    DebugLogger.d('Validating serial: $serial',
      className: 'BluetoothServer', methodName: '_isValidSerial');

    return serial.isNotEmpty && serial.length >= 3;
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    DebugLogger.d('Stopping server', className: 'BluetoothServer', methodName: 'stop');

    try {
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
