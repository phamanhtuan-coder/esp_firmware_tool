import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:smart_net_firmware_loader/core/utils/debug_logger.dart';
import 'package:get_it/get_it.dart';

import 'auth_service.dart';

class BluetoothService {
  ServerSocket? _tcpServer;
  RawDatagramSocket? _udpSocket;
  StreamSubscription? _tcpSubscription;
  StreamSubscription? _udpSubscription;
  Function(String)? _onSerialReceived;

  void _handleQrData(String data, Function(String) onSerialReceived) {
    try {
      final jsonData = jsonDecode(data);
      final username = jsonData['username'] as String?;
      final serialNumber = jsonData['serial_number'] as String?;

      if (username == null || serialNumber == null) {
        DebugLogger.e('❌ Dữ liệu QR không hợp lệ: thiếu username hoặc serial_number',
          className: 'BluetoothService',
          methodName: '_handleQrData');
        return;
      }

      final authService = GetIt.instance<AuthService>();
      final currentUsername = authService.getUsername();

      if (currentUsername != username) {
        DebugLogger.e('❌ Username không khớp với người dùng đang đăng nhập',
          className: 'BluetoothService',
          methodName: '_handleQrData');
        return;
      }

      onSerialReceived(serialNumber);
      DebugLogger.d('✅ Đã nhận serial hợp lệ: $serialNumber',
        className: 'BluetoothService',
        methodName: '_handleQrData');
    } catch (e) {
      DebugLogger.e('❌ Lỗi xử lý dữ liệu QR: $e',
        className: 'BluetoothService',
        methodName: '_handleQrData');
    }
  }

  Future<void> start({required Function(String) onSerialReceived}) async {
    _onSerialReceived = onSerialReceived;

    DebugLogger.d('🔄 Khởi động dịch vụ nhận QR code...', className: 'BluetoothService', methodName: 'start');

    await _startTcpServer();
    await _startUdpServer();

    DebugLogger.d('✅ Đã sẵn sàng nhận dữ liệu từ QR code', className: 'BluetoothService', methodName: 'start');
  }

  Future<void> _startTcpServer() async {
    try {
      _tcpServer = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        12345,
        shared: true, // Enable port sharing
      );
      DebugLogger.d('✅ TCP server đang chạy trên cổng 12345',
        className: 'BluetoothService',
        methodName: '_startTcpServer');

      _tcpSubscription = _tcpServer!.listen((socket) {
        socket
            .transform(utf8.decoder as StreamTransformer<Uint8List, dynamic>)
            .listen(
              (data) {
                if (data.trim().isNotEmpty) {
                  _handleQrData(data.trim(), _onSerialReceived!);
                }
              },
              onError: (e) {
                DebugLogger.e('❌ Lỗi TCP: $e', className: 'BluetoothService', methodName: '_startTcpServer');
              },
            );
      });
    } catch (e) {
      DebugLogger.e('❌ Không thể khởi động TCP server: $e',
        className: 'BluetoothService',
        methodName: '_startTcpServer');
    }
  }

  Future<void> _startUdpServer() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        12345,
        reuseAddress: true, // Enable port sharing
        reusePort: true, // Enable port sharing on supported platforms
      );
      DebugLogger.d('✅ UDP server đang chạy trên cổng 12345',
        className: 'BluetoothService',
        methodName: '_startUdpServer');

      _udpSubscription = _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            final data = utf8.decode(datagram.data).trim();
            if (data.isNotEmpty) {
              _handleQrData(data, _onSerialReceived!);
            }
          }
        }
      });
    } catch (e) {
      DebugLogger.e('❌ Không thể khởi động UDP server: $e',
        className: 'BluetoothService',
        methodName: '_startUdpServer');
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

    DebugLogger.d('🛑 Đã dừng dịch vụ nhận QR code', className: 'BluetoothService', methodName: 'stop');
  }
}
