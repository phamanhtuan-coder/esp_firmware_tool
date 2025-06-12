import 'dart:async';
import 'dart:convert';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:smart_net_firmware_loader/core/utils/debug_logger.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:get_it/get_it.dart';

class SerialMonitorService {
  SerialPort? _serialPort;
  StreamController<String>? _outputController;
  StreamController<bool>? _statusController;
  Timer? _reconnectTimer;
  bool _isReconnecting = false;
  bool _isDisposed = false;

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

  // Safe method to add data to output controller
  void _safeAddOutput(String data) {
    if (!_isDisposed && _outputController != null && !_outputController!.isClosed) {
      try {
        _outputController!.add(data);
      } catch (e) {
        print('Error adding to output controller: $e');
      }
    }
  }

  // Safe method to add data to status controller
  void _safeAddStatus(bool status) {
    if (!_isDisposed && _statusController != null && !_statusController!.isClosed) {
      try {
        _statusController!.add(status);
      } catch (e) {
        print('Error adding to status controller: $e');
      }
    }
  }

  Future<bool> startMonitor(String port, int baudRate) async {
    try {
      if (_isDisposed) {
        DebugLogger.e(
          '❌ Cannot start monitor: Service is disposed',
          className: 'SerialMonitorService',
          methodName: 'startMonitor'
        );
        return false;
      }

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
            _processSerialData(data);
          },
          onError: (error) {
            DebugLogger.e('❌ Lỗi đọc dữ liệu Serial: $error', className: 'SerialMonitorService', methodName: 'startMonitor');
            _attemptRecovery();
          },
          cancelOnError: false,
        );

        // Update status
        _safeAddStatus(true);
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
    if (_isDisposed) return;

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
    if (_isDisposed || _dataBuffer.isEmpty) return;

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
          _safeAddOutput(line);
        }
      }

    } catch (e) {
      DebugLogger.e('❌ Lỗi khi làm sạch bộ đệm: $e', className: 'SerialMonitorService', methodName: '_flushBuffer');
      _dataBuffer.clear(); // Clear buffer on error
    }
  }

  void sendCommand(String command) {
    if (_isDisposed) return;

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
    if (_isDisposed) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_serialPort != null) {
      try {
        if (_serialPort!.isOpen) {
          _serialPort!.close();
        }
      } catch (e) {
        print('Error closing serial port: $e');
      }
      _serialPort = null;
    }

    _safeAddStatus(false);

    try {
      DebugLogger.d('🛑 Đã dừng Serial Monitor', className: 'SerialMonitorService', methodName: 'stopMonitor');
    } catch (e) {
      // Ignore logging errors during shutdown
      print('Error logging during stopMonitor: $e');
    }
  }

  void _attemptRecovery() {
    if (_isDisposed || _currentPort == null || _currentBaudRate == null) return;

    try {
      DebugLogger.w('⚠️ Đang thử kết nối lại Serial...');

      stopMonitor();
      _scheduleReconnect(immediateAttempt: true);
    } catch (e) {
      print('Error during _attemptRecovery: $e');
    }
  }

  void _scheduleReconnect({bool immediateAttempt = false}) {
    if (_isDisposed || _isReconnecting || _currentPort == null || _currentBaudRate == null) return;

    _reconnectTimer?.cancel();
    final delay = immediateAttempt ? const Duration(milliseconds: 500) : const Duration(seconds: 2);
    _reconnectTimer = Timer(delay, _attemptReconnect);
  }

  Future<void> _attemptReconnect() async {
    if (_isDisposed || _isReconnecting || _currentPort == null || _currentBaudRate == null) return;

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
    _isDisposed = true;

    // Cancel all timers first
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _flushTimer?.cancel();
    _flushTimer = null;

    // Close port
    stopMonitor();

    // Clear data buffer
    _dataBuffer.clear();

    // Finally close controllers
    try {
      if (_outputController != null && !_outputController!.isClosed) {
        _outputController?.close();
      }
    } catch (e) {
      print('Error closing output controller: $e');
    }

    try {
      if (_statusController != null && !_statusController!.isClosed) {
        _statusController?.close();
      }
    } catch (e) {
      print('Error closing status controller: $e');
    }

    _outputController = null;
    _statusController = null;
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
