import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'dart:async';

class LogService {
  final StreamController<List<LogEntry>> _logStreamController =
      StreamController.broadcast();
  Stream<List<LogEntry>> get logStream => _logStreamController.stream;
  final List<LogEntry> _logs = [];
  bool _isDisposed = false;

  Future<void> initialize() async {
    _logs.clear();
    _isDisposed = false;
    addLog(
      message: 'Log service initialized',
      level: LogLevel.info,
      step: ProcessStep.systemEvent,
      origin: 'system',
    );
  }

  void addLog({
    required String message,
    required LogLevel level,
    required ProcessStep step,
    required String origin,
    String? deviceId,
    String? rawOutput,
  }) {
    if (_isDisposed) {
      // Skip adding logs if the service is already disposed
      return;
    }

    try {
      final log = LogEntry(
        message: message,
        timestamp: DateTime.now(),
        level: level,
        step: step,
        origin: origin,
        deviceId: deviceId ?? '',
        rawOutput: rawOutput,
      );
      _logs.add(log);
      if (_logs.length > 1000) {
        _logs.removeAt(0);
      }

      if (!_logStreamController.isClosed) {
        _logStreamController.add(_logs);
      }
    } catch (e) {
      // Silently catch errors during shutdown
    }
  }

  List<LogEntry> getFilteredLogs(String? filter) {
    if (filter == null || filter.isEmpty) return _logs;
    return _logs
        .where(
          (log) => log.message.toLowerCase().contains(filter.toLowerCase()),
        )
        .toList();
  }

  void stopSerialMonitor() {
    if (!_isDisposed) {
      addLog(
        message: 'Serial monitor stopped by user or system',
        level: LogLevel.info,
        step: ProcessStep.serialMonitor,
        origin: 'system',
      );
    }
  }

  void dispose() {
    _isDisposed = true;
    if (!_logStreamController.isClosed) {
      _logStreamController.close();
    }
  }
}
