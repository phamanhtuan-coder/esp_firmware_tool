import 'dart:async';
import 'dart:convert';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:smart_net_firmware_loader/core/utils/debug_logger.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:get_it/get_it.dart';

class SerialMonitorService {
  SerialPort? _serialPort;
  StreamController<String>? _outputController;
  StreamController<bool>? _statusController;
  Timer? _reconnectTimer;
  bool _isReconnecting = false;

  // Buffer để tích lũy dữ liệu chưa hoàn chỉnh
  StringBuffer _dataBuffer = StringBuffer();
  Timer? _flushTimer;
  static const _flushDelay = Duration(milliseconds: 50);

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

      DebugLogger.d(
        '🔄 Khởi động Serial Monitor trên cổng $port tốc độ $baudRate',
        className: 'SerialMonitorService',
        methodName: 'startMonitor'
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
          throw Exception('❌ Không thể mở cổng COM: ${SerialPort.lastError}');
        }

        // Set up reader with buffering
        final reader = SerialPortReader(_serialPort!);
        reader.stream.listen(
          (data) {
            if (_outputController != null && !_outputController!.isClosed) {
              _processSerialData(data);
            }
          },
          onError: (error) {
            DebugLogger.e('❌ Lỗi đọc dữ liệu Serial: $error', className: 'SerialMonitorService', methodName: 'startMonitor');
            _attemptRecovery();
          },
          cancelOnError: false,
        );

        // Update status
        _statusController?.add(true);
        return true;

      } catch (e) {
        DebugLogger.e('❌ Lỗi mở cổng Serial: $e', className: 'SerialMonitorService', methodName: 'startMonitor');
        _scheduleReconnect();
        return false;
      }

    } catch (e) {
      DebugLogger.e('❌ Lỗi trong startMonitor: $e', className: 'SerialMonitorService', methodName: 'startMonitor');
      return false;
    }
  }

  void _processSerialData(List<int> data) {
    try {
      // Decode bytes to string
      final String decodedData = _decodeBytes(data);

      // Add to buffer
      _dataBuffer.write(decodedData);

      // Cancel any existing flush timer
      _flushTimer?.cancel();

      // Schedule a new flush
      _flushTimer = Timer(_flushDelay, () {
        _flushBuffer();
      });

    } catch (e) {
      DebugLogger.e('❌ Lỗi xử lý dữ liệu Serial: $e',
        className: 'SerialMonitorService',
        methodName: '_processSerialData');
    }
  }

  void _flushBuffer() {
    if (_dataBuffer.isEmpty) return;

    try {
      // Get the buffered data
      String bufferedData = _dataBuffer.toString();

      // Clear the buffer
      _dataBuffer.clear();

      // Split into lines, keeping any partial line in the buffer
      List<String> lines = bufferedData.split('\n');

      if (!bufferedData.endsWith('\n')) {
        // Keep the last partial line in buffer
        String partial = lines.removeLast();
        _dataBuffer.write(partial);
      }

      // Output complete lines
      for (String line in lines) {
        // Trim carriage return and any whitespace
        line = line.trim();
        if (line.isNotEmpty) {
          _outputController?.add(line);
        }
      }

    } catch (e) {
      DebugLogger.e('❌ Lỗi khi làm sạch bộ đệm: $e', className: 'SerialMonitorService', methodName: '_flushBuffer');
      _dataBuffer.clear(); // Clear buffer on error
    }
  }

  void sendCommand(String command) {
    if (_serialPort != null && _serialPort!.isOpen) {
      try {
        _serialPort!.write(utf8.encode('$command\r\n'));
      } catch (e) {
        DebugLogger.e('❌ Lỗi khi gửi lệnh: $e',
          className: 'SerialMonitorService',
          methodName: 'sendCommand');
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

    DebugLogger.d('🛑 Đã dừng Serial Monitor', className: 'SerialMonitorService', methodName: 'stopMonitor');
  }

  void _attemptRecovery() {
    if (_currentPort == null || _currentBaudRate == null) return;

    DebugLogger.w('⚠️ Đang thử kết nối lại Serial...');

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
          DebugLogger.d(
            '✅ Đã kết nối lại thành công với $_currentPort',
            className: 'SerialMonitorService',
            methodName: '_attemptReconnect'
          );
          _isReconnecting = false;
          return;
        }
      }

      // Schedule another attempt if unsuccessful
      _reconnectTimer = Timer(const Duration(seconds: 3), _attemptReconnect);
    } catch (e) {
      DebugLogger.e(
        '❌ Lỗi trong quá trình kết nối lại: $e',
        className: 'SerialMonitorService',
        methodName: '_attemptReconnect'
      );
      _reconnectTimer = Timer(const Duration(seconds: 3), _attemptReconnect);
    } finally {
      _isReconnecting = false;
    }
  }

  void dispose() {
    stopMonitor();
    _flushTimer?.cancel();
    _dataBuffer.clear();
    _outputController?.close();
    _statusController?.close();
  }

  String _decodeBytes(List<int> data) {
    try {
      return utf8.decode(data, allowMalformed: true);
    } catch (e) {
      try {
        // Replace non-printable characters with space
        return String.fromCharCodes(data.map((byte) {
          if ((byte < 32 || byte > 126) && byte != 10 && byte != 13) {
            return 32; // space
          }
          return byte;
        }));
      } catch (e) {
        // Fallback: show hex values
        return data.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ');
      }
    }
  }
}

