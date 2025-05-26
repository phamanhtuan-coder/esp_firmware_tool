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
  Future<void> startProcess(String? templatePath);
  Future<void> stopProcess();
  Future<void> flashDevice(String deviceId, String firmwarePath);
}

class SocketRepository implements ISocketRepository {
  final IO.Socket socket;
  final _devicesController = StreamController<List<Device>>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  final _deviceLogsController = StreamController<String>.broadcast();

  SocketRepository(this.socket) {
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    socket
      ..on('devices', _handleDevicesEvent)
      ..on('status', _handleStatusEvent)
      ..on('device_log', _handleDeviceLogEvent)
      ..on('device_status', _handleDeviceStatusEvent)
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
  Future<void> startProcess(String? templatePath) async {
    socket.emit('start_process', {'templatePath': templatePath});
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
}