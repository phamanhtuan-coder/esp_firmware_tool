import 'dart:async';
import 'dart:convert';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:get_it/get_it.dart';

class SerialMonitorService {
  final LogService _logService = GetIt.instance<LogService>();
  SerialPort? _serialPort;
  StreamController<String>? _outputController;
  StreamSubscription<List<int>>? _serialSubscription;

  Stream<String> get outputStream =>
      _outputController?.stream ?? const Stream.empty();

  Future<bool> startMonitor(String port, int baudRate) async {
    try {
      stopMonitor();

      // Verify port exists
      if (!SerialPort.availablePorts.contains(port)) {
        _logService.addLog(
          message: 'Port $port not found',
          level: LogLevel.error,
          step: ProcessStep.serialMonitor,
          origin: 'serial-monitor',
        );
        return false;
      }

      _outputController = StreamController<String>.broadcast();
      _serialPort = SerialPort(port);

      // Configure port
      final config =
          SerialPortConfig()
            ..baudRate = baudRate
            ..bits = 8
            ..parity = SerialPortParity.none
            ..stopBits = 1
            ..rts = 0
            ..cts = 0
            ..dsr = 0
            ..dtr = 0;

      _serialPort!.config = config;

      // Open port
      if (!_serialPort!.openReadWrite()) {
        _logService.addLog(
          message: 'Failed to open port $port',
          level: LogLevel.error,
          step: ProcessStep.serialMonitor,
          origin: 'serial-monitor',
        );
        return false;
      }

      // Listen to incoming data using SerialPort reader
      final reader = SerialPortReader(_serialPort!);
      _serialSubscription = reader.stream.listen(
        (data) {
          final message = utf8.decode(data, allowMalformed: true).trim();
          if (message.isNotEmpty) {
            _outputController?.add(message);
            _logService.addLog(
              message: message,
              level: LogLevel.serialOutput,
              step: ProcessStep.serialMonitor,
              origin: 'serial-monitor',
            );
          }
        },
        onError: (e) {
          _logService.addLog(
            message: 'Serial port error: $e',
            level: LogLevel.error,
            step: ProcessStep.serialMonitor,
            origin: 'serial-monitor',
          );
          _outputController?.addError(e);
        },
      );

      _logService.addLog(
        message: 'Started serial monitor on $port at $baudRate baud',
        level: LogLevel.success,
        step: ProcessStep.serialMonitor,
        origin: 'serial-monitor',
      );
      return true;
    } catch (e) {
      _logService.addLog(
        message: 'Failed to start serial monitor: $e',
        level: LogLevel.error,
        step: ProcessStep.serialMonitor,
        origin: 'serial-monitor',
      );
      return false;
    }
  }

  void sendCommand(String command) {
    if (_serialPort != null && _serialPort!.isOpen) {
      _serialPort!.write(utf8.encode('$command\r\n'));
      _logService.addLog(
        message: 'Sent command: $command',
        level: LogLevel.input,
        step: ProcessStep.serialMonitor,
        origin: 'user-input',
      );
    } else {
      _logService.addLog(
        message: 'Cannot send command: Serial port not open',
        level: LogLevel.error,
        step: ProcessStep.serialMonitor,
        origin: 'serial-monitor',
      );
    }
  }

  void stopMonitor() {
    _serialSubscription?.cancel();
    if (_serialPort != null && _serialPort!.isOpen) {
      _serialPort!.close();
    }
    _outputController?.close();
    _serialPort = null;
    _outputController = null;
    _serialSubscription = null;
    _logService.addLog(
      message: 'Serial monitor stopped',
      level: LogLevel.info,
      step: ProcessStep.serialMonitor,
      origin: 'serial-monitor',
    );
  }

  void dispose() {
    stopMonitor();
  }
}
