import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';

class USBService {
  SerialPort? _currentPort;
  final StreamController<List<String>> _portUpdateController = StreamController.broadcast();

  Stream<List<String>> get portUpdates => _portUpdateController.stream;

  USBService() {
    // Start monitoring USB ports
    _startPortMonitoring();
  }

  void _startPortMonitoring() {
    Timer.periodic(const Duration(seconds: 2), (timer) {
      updateAvailablePorts();
    });
  }

  void updateAvailablePorts() {
    var ports = SerialPort.availablePorts;
    _portUpdateController.add(ports);
  }

  bool connectToPort(String portName) {
    try {
      _currentPort?.close();
      _currentPort = SerialPort(portName);

      if (!_currentPort!.openReadWrite()) {
        throw Exception('Failed to open port');
      }

      // Configure port for ESP32
      _currentPort!.config = SerialPortConfig()
        ..baudRate = 115200
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none
        ..setFlowControl(SerialPortFlowControl.none);

      return true;
    } catch (e) {
      _currentPort = null;
      return false;
    }
  }

  Future<bool> flashFirmware(String firmwarePath, String portName) async {
    try {
      if (_currentPort == null || !_currentPort!.isOpen) {
        if (!connectToPort(portName)) {
          throw Exception('Failed to connect to port');
        }
      }

      // TODO: Implement ESP32-specific flashing logic using esptool.py
      // This would typically involve calling esptool.py through process_run

      return true;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _currentPort?.close();
    _portUpdateController.close();
  }

  bool isPortConnected(String portName) {
    return _currentPort != null &&
           _currentPort!.isOpen &&
           _currentPort!.name == portName;
  }

  List<String> getAvailablePorts() {
    return SerialPort.availablePorts;
  }

  Future<String> readFromPort() async {
    if (_currentPort == null || !_currentPort!.isOpen) {
      throw Exception('Port not connected');
    }

    try {
      var reader = SerialPortReader(_currentPort!);
      var data = await reader.stream.first;
      return String.fromCharCodes(data);
    } catch (e) {
      throw Exception('Failed to read from port: $e');
    }
  }

  Future<void> writeToPort(String data) async {
    if (_currentPort == null || !_currentPort!.isOpen) {
      throw Exception('Port not connected');
    }

    try {
      final Uint8List bytes = Uint8List.fromList(data.codeUnits);
      _currentPort!.write(bytes);
    } catch (e) {
      throw Exception('Failed to write to port: $e');
    }
  }
}