import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'dart:async';

class LogService {
  final StreamController<List<LogEntry>> _logStreamController =
      StreamController.broadcast();
  Stream<List<LogEntry>> get logStream => _logStreamController.stream;
  final List<LogEntry> _logs = [];
  bool _isDisposed = false;
  // Add a debouncer to batch log updates
  Timer? _debounceTimer;
  bool _pendingUpdate = false;

  Future<void> initialize() async {
    _logs.clear();
    _isDisposed = false;
    // Cancel any existing debounce timer
    _debounceTimer?.cancel();
    _debounceTimer = null;
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

      // Schedule update with debouncing to avoid UI flooding
      _scheduleLogUpdate();

      // Immediately dispatch critical logs (errors, success)
      if (level == LogLevel.error || level == LogLevel.success) {
        _dispatchLogsNow();
      }
    } catch (e) {
      // Silently catch errors during shutdown
      print('Error adding log: $e');
    }
  }

  void _scheduleLogUpdate() {
    if (_isDisposed || _pendingUpdate) return;

    _pendingUpdate = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), _dispatchLogsNow);
  }

  void _dispatchLogsNow() {
    if (_isDisposed) return;

    _pendingUpdate = false;
    _debounceTimer?.cancel();
    _debounceTimer = null;

    if (!_logStreamController.isClosed) {
      _logStreamController.add(List<LogEntry>.from(_logs));
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
    _debounceTimer?.cancel();
    if (!_logStreamController.isClosed) {
      _logStreamController.close();
    }
  }
}
