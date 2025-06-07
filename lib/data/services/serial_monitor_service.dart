import 'dart:async';
import 'dart:convert';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:get_it/get_it.dart';
import 'package:smart_net_firmware_loader/data/services/arduino_service.dart';

class SerialMonitorService {
  final LogService _logService = GetIt.instance<LogService>();
  final ArduinoService _arduinoService = GetIt.instance<ArduinoService>();
  SerialPort? _serialPort;
  StreamController<String>? _outputController;
  StreamController<bool>? _statusController;
  Timer? _reconnectTimer;
  bool _isReconnecting = false;

  // Current connection info
  String? _currentPort;
  int? _currentBaudRate;

  Stream<String> get outputStream => _outputController?.stream ?? const Stream.empty();
  Stream<bool> get statusStream => _statusController?.stream ?? const Stream.empty();
  bool get isActive => _serialPort != null && _serialPort!.isOpen;

  SerialMonitorService() {
    _outputController = StreamController<String>.broadcast();
    _statusController = StreamController<bool>.broadcast();
  }

  Future<bool> startMonitor(String port, int baudRate) async {
    try {
      // Cancel any active reconnection attempts
      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      // Store connection parameters
      _currentPort = port;
      _currentBaudRate = baudRate;

      stopMonitor();

      _logService.addLog(
        message: 'Starting monitor on $port at $baudRate baud',
        level: LogLevel.info,
        step: ProcessStep.serialMonitor,
        origin: 'serial-monitor',
      );

      // Try to open the port
      try {
        _serialPort = SerialPort(port);
        final config = SerialPortConfig()
          ..baudRate = baudRate
          ..bits = 8
          ..parity = SerialPortParity.none
          ..stopBits = 1
          ..rts = 0
          ..cts = 0
          ..dsr = 0
          ..dtr = 1;

        _serialPort!.config = config;

        if (!_serialPort!.openReadWrite()) {
          throw Exception('Failed to open port: ${SerialPort.lastError}');
        }

        // Set up reader
        final reader = SerialPortReader(_serialPort!);
        reader.stream.listen(
          (data) {
            if (_outputController != null && !_outputController!.isClosed) {
              final message = _decodeBytes(data);
              if (message.isNotEmpty) {
                _outputController!.add(message);
              }
            }
          },
          onError: (error) {
            _logService.addLog(
              message: 'Serial read error: $error',
              level: LogLevel.error,
              step: ProcessStep.serialMonitor,
              origin: 'serial-monitor',
            );
            _attemptRecovery();
          },
          cancelOnError: false,
        );

        // Update status
        _statusController?.add(true);
        return true;

      } catch (e) {
        _logService.addLog(
          message: 'Failed to open serial port: $e',
          level: LogLevel.error,
          step: ProcessStep.serialMonitor,
          origin: 'serial-monitor',
        );
        _scheduleReconnect();
        return false;
      }

    } catch (e) {
      _logService.addLog(
        message: 'Error in startMonitor: $e',
        level: LogLevel.error,
        step: ProcessStep.serialMonitor,
        origin: 'serial-monitor',
      );
      return false;
    }
  }

  void sendCommand(String command) {
    if (_serialPort != null && _serialPort!.isOpen) {
      try {
        _serialPort!.write(utf8.encode('$command\r\n'));
      } catch (e) {
        _logService.addLog(
          message: 'Error sending command: $e',
          level: LogLevel.error,
          step: ProcessStep.serialMonitor,
          origin: 'serial-monitor',
        );
      }
    }
  }

  void stopMonitor() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_serialPort != null) {
      if (_serialPort!.isOpen) {
        _serialPort!.close();
      }
      _serialPort = null;
    }

    _statusController?.add(false);

    _logService.addLog(
      message: 'Serial monitor stopped',
      level: LogLevel.info,
      step: ProcessStep.serialMonitor,
      origin: 'serial-monitor',
    );
  }

  void _attemptRecovery() {
    if (_currentPort == null || _currentBaudRate == null) return;

    _logService.addLog(
      message: 'Attempting to recover serial connection...',
      level: LogLevel.warning,
      step: ProcessStep.serialMonitor,
      origin: 'serial-monitor',
    );

    stopMonitor();
    _scheduleReconnect(immediateAttempt: true);
  }

  void _scheduleReconnect({bool immediateAttempt = false}) {
    if (_isReconnecting || _currentPort == null || _currentBaudRate == null) return;

    _reconnectTimer?.cancel();
    final delay = immediateAttempt ? const Duration(milliseconds: 500) : const Duration(seconds: 2);
    _reconnectTimer = Timer(delay, _attemptReconnect);
  }

  Future<void> _attemptReconnect() async {
    if (_isReconnecting || _currentPort == null || _currentBaudRate == null) return;

    _isReconnecting = true;
    try {
      final ports = SerialPort.availablePorts;
      if (ports.contains(_currentPort)) {
        final success = await startMonitor(_currentPort!, _currentBaudRate!);
        if (success) {
          _logService.addLog(
            message: 'Successfully reconnected to $_currentPort',
            level: LogLevel.success,
            step: ProcessStep.serialMonitor,
            origin: 'serial-monitor',
          );
          _isReconnecting = false;
          return;
        }
      }

      // Schedule another attempt if unsuccessful
      _reconnectTimer = Timer(const Duration(seconds: 3), _attemptReconnect);
    } catch (e) {
      _logService.addLog(
        message: 'Error during reconnection: $e',
        level: LogLevel.error,
        step: ProcessStep.serialMonitor,
        origin: 'serial-monitor',
      );
      _reconnectTimer = Timer(const Duration(seconds: 3), _attemptReconnect);
    } finally {
      _isReconnecting = false;
    }
  }

  void dispose() {
    stopMonitor();
    _outputController?.close();
    _statusController?.close();
  }

  String _decodeBytes(List<int> data) {
    try {
      return utf8.decode(data, allowMalformed: true);
    } catch (e) {
      try {
        return String.fromCharCodes(data.map((byte) {
          return (byte < 32 || byte > 126) && byte != 10 && byte != 13 ? 32 : byte;
        }));
      } catch (e) {
        return data.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ');
      }
    }
  }
}
