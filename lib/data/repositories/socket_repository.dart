import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:esp_firmware_tool/data/models/device.dart';
import 'package:esp_firmware_tool/utils/app_config.dart';

abstract class ISocketRepository {
  Future<void> connect();
  Future<void> disconnect();
  Stream<List<Device>> getDevices();
  Stream<String> getStatus();
  Stream<String> getDeviceLogs(String deviceId);
  Future<void> startProcess(String? templatePath, {String? serialNumber, String? port});
  Future<void> stopProcess();
  Future<void> flashDevice(String deviceId, String firmwarePath);
  Future<Map<String, dynamic>> checkUsbConnection(String serialNumber);
  Future<Map<String, dynamic>> scanUsbPorts(); // New method for scanning USB ports
}

class SocketRepository implements ISocketRepository {
  final IO.Socket socket;
  final _devicesController = StreamController<List<Device>>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  final _deviceLogsController = StreamController<String>.broadcast();

  // Completers for async operations
  Completer<Map<String, dynamic>>? _usbConnectionCompleter;
  Completer<Map<String, dynamic>>? _scanPortsCompleter; // New completer for port scanning

  SocketRepository(this.socket) {
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    socket
      ..on('devices', _handleDevicesEvent)
      ..on('status', _handleStatusEvent)
      ..on('device_log', _handleDeviceLogEvent)
      ..on('device_status', _handleDeviceStatusEvent)
      ..on('usb_connection_result', _handleUsbConnectionResult)
      ..on('usb_ports_result', _handleUsbPortsResult) // New event handler
      ..on('error', _handleErrorEvent);
  }

  void _handleDevicesEvent(dynamic data) {
    if (data is List) {
      final devices = data.map((e) => Device.fromJson(e)).toList();
      _devicesController.add(devices);
    }
  }

  void _handleStatusEvent(dynamic data) {
    if (data is String) {
      _statusController.add(data);
    }
  }

  void _handleDeviceLogEvent(dynamic data) {
    if (data is Map<String, dynamic>) {
      final deviceId = data['deviceId'] as String?;
      final message = data['message'] as String?;
      if (deviceId != null && message != null) {
        _deviceLogsController.add('[$deviceId] $message');
      }
    }
  }

  void _handleDeviceStatusEvent(dynamic data) {
    if (data is Map<String, dynamic>) {
      final deviceId = data['deviceId'] as String?;
      final status = data['status'] as String?;
      if (deviceId != null && status != null) {
        _statusController.add('Device $deviceId: $status');
      }
    }
  }

  void _handleUsbConnectionResult(dynamic data) {
    if (_usbConnectionCompleter != null && !_usbConnectionCompleter!.isCompleted) {
      if (data is Map<String, dynamic>) {
        _usbConnectionCompleter!.complete(data);
      } else {
        _usbConnectionCompleter!.completeError('Invalid response format');
      }
    }
  }

  void _handleUsbPortsResult(dynamic data) {
    if (_scanPortsCompleter != null && !_scanPortsCompleter!.isCompleted) {
      if (data is Map<String, dynamic>) {
        _scanPortsCompleter!.complete(data);
      } else {
        _scanPortsCompleter!.completeError('Invalid response format');
      }
    }
  }

  void _handleErrorEvent(dynamic error) {
    final errorMessage = error is String ? error : 'An unknown error occurred';
    _statusController.add(AppConfig.errorOccurred + ': $errorMessage');
  }

  @override
  Future<void> connect() async {
    socket.connect();
    socket.emit('get_devices'); // Request initial device list
  }

  @override
  Future<void> disconnect() async {
    socket.disconnect();
    await _devicesController.close();
    await _statusController.close();
    await _deviceLogsController.close();
  }

  @override
  Stream<List<Device>> getDevices() {
    socket.emit('get_devices');
    return _devicesController.stream;
  }

  @override
  Stream<String> getStatus() {
    return _statusController.stream;
  }

  @override
  Stream<String> getDeviceLogs(String deviceId) {
    socket.emit('subscribe_device_logs', {'deviceId': deviceId});
    return _deviceLogsController.stream
        .where((log) => log.contains('[$deviceId]'));
  }

  @override
  Future<void> startProcess(String? templatePath, {String? serialNumber, String? port}) async {
    socket.emit('start_process', {
      'templatePath': templatePath,
      'serialNumber': serialNumber,
      'port': port
    });
  }

  @override
  Future<void> stopProcess() async {
    socket.emit('stop_process');
  }

  @override
  Future<void> flashDevice(String deviceId, String firmwarePath) async {
    socket.emit('flash_device', {
      'deviceId': deviceId,
      'firmwarePath': firmwarePath
    });
  }

  @override
  Future<Map<String, dynamic>> checkUsbConnection(String serialNumber) {
    _usbConnectionCompleter = Completer<Map<String, dynamic>>();
    socket.emit('check_usb_connection', {'serialNumber': serialNumber});

    // Set a timeout for the operation
    Future.delayed(const Duration(seconds: 5), () {
      if (_usbConnectionCompleter != null && !_usbConnectionCompleter!.isCompleted) {
        _usbConnectionCompleter!.completeError('USB connection check timed out');
      }
    });

    return _usbConnectionCompleter!.future;
  }

  @override
  Future<Map<String, dynamic>> scanUsbPorts() {
    _scanPortsCompleter = Completer<Map<String, dynamic>>();
    socket.emit('scan_usb_ports');

    // Set a timeout for the operation
    Future.delayed(const Duration(seconds: 5), () {
      if (_scanPortsCompleter != null && !_scanPortsCompleter!.isCompleted) {
        _scanPortsCompleter!.completeError('USB port scan timed out');
      }
    });

    return _scanPortsCompleter!.future;
  }
}