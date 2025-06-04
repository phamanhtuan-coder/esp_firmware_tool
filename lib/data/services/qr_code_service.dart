import 'dart:async';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/bluetooth_server.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:smart_net_firmware_loader/utils/debug_logger.dart';

// Enum để đại diện cho trạng thái quét QR
enum QrScanStatus {
  idle,       // Chưa quét
  scanning,   // Đang quét
  success,    // Quét thành công
  timeout,    // Hết thời gian
  error       // Lỗi
}

class QrCodeService {
  final LogService _logService;
  final BluetoothServer _bluetoothServer;
  bool _isScanning = false;

  // Thêm các callback và controller để thông báo khi có thay đổi trạng thái
  final _statusController = StreamController<QrScanStatus>.broadcast();
  Stream<QrScanStatus> get statusStream => _statusController.stream;
  QrScanStatus _currentStatus = QrScanStatus.idle;

  QrCodeService({
    required LogService logService,
    required BluetoothServer bluetoothServer,
  }) : _logService = logService,
       _bluetoothServer = bluetoothServer {
    DebugLogger.d('QrCodeService initialized', className: 'QrCodeService', methodName: 'constructor');
  }

  bool get isScanning => _isScanning;
  QrScanStatus get currentStatus => _currentStatus;

  void _updateStatus(QrScanStatus newStatus) {
    DebugLogger.d('Scan status changed: $_currentStatus -> $newStatus',
        className: 'QrCodeService', methodName: '_updateStatus');

    _currentStatus = newStatus;
    _statusController.add(newStatus);
  }

  /// Bắt đầu quét mã QR, tạo server và đợi kết nối từ app di động
  /// Trả về số serial nếu nhận được, ngược lại trả về null
  /// Callback onStatusChanged được gọi khi trạng thái quét thay đổi
  Future<String?> scanQrCode({
    int timeoutSeconds = 60,
    int port = 12345,
    Function(QrScanStatus status)? onStatusChanged,
  }) async {
    DebugLogger.d('scanQrCode called with timeout: $timeoutSeconds, port: $port',
      className: 'QrCodeService', methodName: 'scanQrCode');

    if (_isScanning) {
      DebugLogger.w('QR scanning process is already in progress');
      _logService.addLog(
        message: '⚠️ Quá trình quét QR đang diễn ra',
        level: LogLevel.warning,
        step: ProcessStep.scanQrCode,
        origin: 'qr-service',
      );
      return null;
    }

    _isScanning = true;
    _updateStatus(QrScanStatus.scanning);
    if (onStatusChanged != null) onStatusChanged(QrScanStatus.scanning);

    DebugLogger.i('Starting QR code scanning process');
    _logService.addLog(
      message: '🔍 Bắt đầu quét mã QR code...',
      level: LogLevel.info,
      step: ProcessStep.scanQrCode,
      origin: 'qr-service',
    );

    final Completer<String?> completer = Completer<String?>();

    // Khởi động server lắng nghe kết nối
    DebugLogger.d('Starting Bluetooth server for QR scanning', className: 'QrCodeService', methodName: 'scanQrCode');
    final success = await _bluetoothServer.start(
      onSerialReceived: (serial) {
        DebugLogger.d('Serial received from QR code: $serial', className: 'QrCodeService', methodName: 'scanQrCode');
        if (!completer.isCompleted) {
          _logService.addLog(
            message: '✅ Đã nhận được serial từ QR code: $serial',
            level: LogLevel.success,
            step: ProcessStep.scanQrCode,
            origin: 'qr-service',
          );

          _updateStatus(QrScanStatus.success);
          if (onStatusChanged != null) onStatusChanged(QrScanStatus.success);

          completer.complete(serial);
        }
      },
      port: port,
    );

    if (!success) {
      _isScanning = false;
      _updateStatus(QrScanStatus.error);
      if (onStatusChanged != null) onStatusChanged(QrScanStatus.error);

      DebugLogger.e('Failed to start QR code server');
      _logService.addLog(
        message: '❌ Không thể khởi động server QR code',
        level: LogLevel.error,
        step: ProcessStep.scanQrCode,
        origin: 'qr-service',
      );
      return null;
    }

    DebugLogger.i('QR code server listening at address: http://${_bluetoothServer.serverAddress}:${_bluetoothServer.port}');
    _logService.addLog(
      message: '🌐 Server đang lắng nghe kết nối tại địa chỉ: ' 'http://${_bluetoothServer.serverAddress}:${_bluetoothServer.port}',
      level: LogLevel.info,
      step: ProcessStep.scanQrCode,
      origin: 'qr-service',
    );

    DebugLogger.i('Waiting for serial data from mobile app (timeout: ${timeoutSeconds}s)');
    _logService.addLog(
      message: '⏱️ Đang đợi dữ liệu serial từ app mobile (timeout: ${timeoutSeconds}s)...',
      level: LogLevel.info,
      step: ProcessStep.scanQrCode,
      origin: 'qr-service',
    );

    // Đặt timeout và đợi kết quả
    String? result;
    try {
      DebugLogger.d('Setting up timeout: $timeoutSeconds seconds', className: 'QrCodeService', methodName: 'scanQrCode');
      result = await completer.future.timeout(Duration(seconds: timeoutSeconds), onTimeout: () {
        DebugLogger.w('QR code scanning timeout after $timeoutSeconds seconds');
        _logService.addLog(
          message: '⏰ Hết thời gian chờ quét QR code',
          level: LogLevel.warning,
          step: ProcessStep.scanQrCode,
          origin: 'qr-service',
        );

        _updateStatus(QrScanStatus.timeout);
        if (onStatusChanged != null) onStatusChanged(QrScanStatus.timeout);

        return null;
      });
    } finally {
      // Dừng server sau khi hoàn thành hoặc timeout
      _isScanning = false;

      // Nếu kết thúc mà không phải do success/timeout/error (ví dụ: user cancel)
      if (_currentStatus == QrScanStatus.scanning) {
        _updateStatus(QrScanStatus.idle);
        if (onStatusChanged != null) onStatusChanged(QrScanStatus.idle);
      }

      DebugLogger.d('Cleaning up after QR scan (success: ${result != null})', className: 'QrCodeService', methodName: 'scanQrCode');
      await _bluetoothServer.stop();
    }

    DebugLogger.d('scanQrCode finished with result: $result', className: 'QrCodeService', methodName: 'scanQrCode');
    return result;
  }

  /// Starts the QR code scanning service by initializing the Bluetooth server
  /// to listen for incoming connections from mobile app scanners
  Future<bool> startQrScanServer({
    required Function(String) onSerialReceived,
    int port = 12345,
  }) async {
    DebugLogger.d('startQrScanServer called', className: 'QrCodeService', methodName: 'startQrScanServer');
    _logService.addLog(
      message: 'Starting QR code scan server...',
      level: LogLevel.info,
      step: ProcessStep.scanQrCode,
      origin: 'qr-service',
    );

    final success = await _bluetoothServer.start(
      onSerialReceived: onSerialReceived,
      port: port,
    );

    if (success) {
      DebugLogger.i('QR code scan server started on ${_bluetoothServer.serverAddress}:${_bluetoothServer.port}');
      _logService.addLog(
        message: 'QR code scan server started on ${_bluetoothServer.serverAddress}:${_bluetoothServer.port}',
        level: LogLevel.success,
        step: ProcessStep.scanQrCode,
        origin: 'qr-service',
      );
      return true;
    } else {
      DebugLogger.e('Failed to start QR code scan server');
      _logService.addLog(
        message: 'Failed to start QR code scan server',
        level: LogLevel.error,
        step: ProcessStep.scanQrCode,
        origin: 'qr-service',
      );
      return false;
    }
  }

  /// Stops the QR code scanning service
  Future<void> stopQrScanServer() async {
    DebugLogger.d('stopQrScanServer called', className: 'QrCodeService', methodName: 'stopQrScanServer');
    _logService.addLog(
      message: 'Stopping QR code scan server...',
      level: LogLevel.info,
      step: ProcessStep.scanQrCode,
      origin: 'qr-service',
    );

    await _bluetoothServer.stop();
  }

  /// Gets the server URL that should be encoded in the QR code
  /// This is what the mobile app will connect to
  String getQrCodeUrl() {
    final ipAddress = _bluetoothServer.isRunning
        ? _bluetoothServer.serverAddress
        : 'localhost';
    final port = _bluetoothServer.port;

    final url = 'http://$ipAddress:$port';
    DebugLogger.d('Generated QR code URL: $url', className: 'QrCodeService', methodName: 'getQrCodeUrl');
    return url;
  }

  /// Kiểm tra trạng thái server
  bool isServerRunning() {
    final status = _bluetoothServer.isRunning;
    DebugLogger.d('Server status check: $status', className: 'QrCodeService', methodName: 'isServerRunning');
    return status;
  }

  /// Dừng quá trình quét QR
  Future<void> stopScanning() async {
    DebugLogger.d('stopScanning called', className: 'QrCodeService', methodName: 'stopScanning');
    if (_isScanning) {
      _logService.addLog(
        message: '🛑 Dừng quá trình quét QR code',
        level: LogLevel.info,
        step: ProcessStep.scanQrCode,
        origin: 'qr-service',
      );

      _updateStatus(QrScanStatus.idle);
      _isScanning = false;
      await _bluetoothServer.stop();
    }
  }

  /// Dispose resources
  void dispose() {
    _statusController.close();
  }
}
