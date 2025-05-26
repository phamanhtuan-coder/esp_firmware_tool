import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/device.dart';

abstract class ISocketRepository {
  Future<void> connect();
  Future<void> disconnect();
  Stream<List<Device>> getDevices();
  Stream<String> getStatus();
  Future<void> startProcess(String? templatePath);
  Future<void> stopProcess();
}

class SocketRepository implements ISocketRepository {
  final IO.Socket socket;

  SocketRepository(this.socket);

  final _devicesController = StreamController<List<Device>>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  @override
  Future<void> connect() async {
    socket.connect();

    socket.on('devices', (data) {
      final devices = (data as List).map((e) => Device.fromJson(e)).toList();
      _devicesController.add(devices);
    });

    socket.on('status', (data) {
      _statusController.add(data);
    });
  }

  @override
  Future<void> disconnect() async {
    socket.disconnect();
    await _devicesController.close();
    await _statusController.close();
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
  Future<void> startProcess(String? templatePath) async {
    socket.emit('start_process', {'templatePath': templatePath});
  }

  @override
  Future<void> stopProcess() async {
    socket.emit('stop_process');
  }
}