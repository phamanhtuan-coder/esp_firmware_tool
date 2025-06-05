import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:get_it/get_it.dart';

class BluetoothService {
  final LogService _logService = GetIt.instance<LogService>();
  ServerSocket? _tcpServer;
  RawDatagramSocket? _udpSocket;
  StreamSubscription? _tcpSubscription;
  StreamSubscription? _udpSubscription;
  Function(String)? _onSerialReceived;

  Future<void> start({required Function(String) onSerialReceived}) async {
    _onSerialReceived = onSerialReceived;
    await _startTcpServer();
    await _startUdpServer();
  }

  Future<void> _startTcpServer() async {
    try {
      _tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, 12345);
      _logService.addLog(
        message: 'TCP server started on port 12345',
        level: LogLevel.success,
        step: ProcessStep.scanQrCode,
        origin: 'bluetooth',
      );
      _tcpSubscription = _tcpServer!.listen((socket) {
        socket
            .transform(utf8.decoder as StreamTransformer<Uint8List, dynamic>)
            .listen(
              (data) {
                final serial = data.trim();
                if (serial.isNotEmpty) {
                  _logService.addLog(
                    message: 'Received serial via TCP: $serial',
                    level: LogLevel.info,
                    step: ProcessStep.scanQrCode,
                    origin: 'bluetooth',
                  );
                  _onSerialReceived?.call(serial);
                }
              },
              onError: (e) {
                _logService.addLog(
                  message: 'TCP error: $e',
                  level: LogLevel.error,
                  step: ProcessStep.scanQrCode,
                  origin: 'bluetooth',
                );
              },
            );
      });
    } catch (e) {
      _logService.addLog(
        message: 'Failed to start TCP server: $e',
        level: LogLevel.error,
        step: ProcessStep.scanQrCode,
        origin: 'bluetooth',
      );
    }
  }

  Future<void> _startUdpServer() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 12345);
      _logService.addLog(
        message: 'UDP server started on port 12345',
        level: LogLevel.success,
        step: ProcessStep.scanQrCode,
        origin: 'bluetooth',
      );
      _udpSubscription = _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            final serial = utf8.decode(datagram.data).trim();
            if (serial.isNotEmpty) {
              _logService.addLog(
                message: 'Received serial via UDP: $serial',
                level: LogLevel.info,
                step: ProcessStep.scanQrCode,
                origin: 'bluetooth',
              );
              _onSerialReceived?.call(serial);
            }
          }
        }
      });
    } catch (e) {
      _logService.addLog(
        message: 'Failed to start UDP server: $e',
        level: LogLevel.error,
        step: ProcessStep.scanQrCode,
        origin: 'bluetooth',
      );
    }
  }

  Future<void> stop() async {
    await _tcpSubscription?.cancel();
    await _tcpServer?.close();
    await _udpSubscription?.cancel();
    _udpSocket?.close();
    _tcpServer = null;
    _udpSocket = null;
    _tcpSubscription = null;
    _udpSubscription = null;
    _logService.addLog(
      message: 'Bluetooth server stopped',
      level: LogLevel.info,
      step: ProcessStep.scanQrCode,
      origin: 'bluetooth',
    );
  }
}
