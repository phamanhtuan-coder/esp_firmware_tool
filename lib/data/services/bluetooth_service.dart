import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:smart_net_firmware_loader/core/utils/debug_logger.dart';


class BluetoothService {
  ServerSocket? _tcpServer;
  RawDatagramSocket? _udpSocket;
  StreamSubscription? _tcpSubscription;
  StreamSubscription? _udpSubscription;
  Function(String)? _onSerialReceived;

  Future<void> start({required Function(String) onSerialReceived}) async {
    _onSerialReceived = onSerialReceived;

    DebugLogger.d('🔄 Khởi động dịch vụ nhận QR code...', className: 'BluetoothService', methodName: 'start');

    await _startTcpServer();
    await _startUdpServer();

    DebugLogger.d('✅ Đã sẵn sàng nhận dữ liệu từ QR code', className: 'BluetoothService', methodName: 'start');
  }

  Future<void> _startTcpServer() async {
    try {
      _tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, 12345);
      DebugLogger.d('✅ TCP server đang chạy trên cổng 12345', className: 'BluetoothService', methodName: '_startTcpServer');

      _tcpSubscription = _tcpServer!.listen((socket) {
        socket
            .transform(utf8.decoder as StreamTransformer<Uint8List, dynamic>)
            .listen(
              (data) {
                final serial = data.trim();
                if (serial.isNotEmpty) {
                  DebugLogger.d('📱 Đã nhận serial qua TCP: $serial', className: 'BluetoothService', methodName: '_startTcpServer');
                  _onSerialReceived?.call(serial);
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
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 12345);
      DebugLogger.d('✅ UDP server đang chạy trên cổng 12345', className: 'BluetoothService', methodName: '_startUdpServer');

      _udpSubscription = _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            final serial = utf8.decode(datagram.data).trim();
            if (serial.isNotEmpty) {
              DebugLogger.d('📱 Đã nhận serial qua UDP: $serial', className: 'BluetoothService', methodName: '_startUdpServer');
              _onSerialReceived?.call(serial);
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
