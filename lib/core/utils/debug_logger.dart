import 'package:get_it/get_it.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/domain/blocs/logging_bloc.dart';

/// Utility class for debugging with print statements
/// This class provides methods to print debug information with customized format
class DebugLogger {
  /// Whether debug mode is enabled
  static bool _debugMode = true;

  /// Set debug mode on/off
  static void setDebugMode(bool enabled) {
    _debugMode = enabled;
  }

  /// Safely get the logging bloc if available
  static LoggingBloc? _getLoggingBloc() {
    try {
      if (!GetIt.instance.isRegistered<LoggingBloc>()) {
        return null;
      }
      return GetIt.instance<LoggingBloc>();
    } catch (e) {
      print('Error accessing LoggingBloc: $e');
      return null;
    }
  }

  /// Safely add a log entry to the bloc
  static void _safeAddLog(LogEntry log) {
    try {
      final bloc = _getLoggingBloc();
      if (bloc != null && !bloc.isDisposed) {
        bloc.add(AddLogEvent(log));
      } else {
        // Fallback to console if bloc is not available
        print('${log.formattedTimestamp} [${log.level}] ${log.message}');
      }
    } catch (e) {
      // If anything goes wrong, just print to console
      print('Logger error: $e');
      print('Original log: ${log.message}');
    }
  }

  /// Print debug message with class name and method name
  static void d(String message, {String? className, String? methodName}) {
    if (_debugMode) {
      final now = DateTime.now();
      final _ =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}";

      String location = '';
      if (className != null) {
        location += '[$className]';
      }
      if (methodName != null) {
        location += '.$methodName()';
      }

      _safeAddLog(
        LogEntry(
          message: '$location: $message',
          timestamp: DateTime.now(),
          level: LogLevel.verbose,
          step: ProcessStep.other,
          origin: 'debug',
        ),
      );
    }
  }

  /// Print info message
  static void i(String message) {
    if (_debugMode) {
      _safeAddLog(
        LogEntry(
          message: message,
          timestamp: DateTime.now(),
          level: LogLevel.info,
          step: ProcessStep.other,
          origin: 'debug',
        ),
      );
    }
  }

  /// Print warning message
  static void w(String message) {
    if (_debugMode) {
      _safeAddLog(
        LogEntry(
          message: message,
          timestamp: DateTime.now(),
          level: LogLevel.warning,
          step: ProcessStep.other,
          origin: 'debug',
        ),
      );
    }
  }

  /// Print error message
  static void e(String message, {String? className, String? methodName, dynamic error, StackTrace? stackTrace}) {
    if (_debugMode) {
      String location = '';
      if (className != null) {
        location += '[$className]';
      }
      if (methodName != null) {
        location += '.$methodName()';
      }

      _safeAddLog(
        LogEntry(
          message: location.isNotEmpty ? '$location: $message' : message,
          timestamp: DateTime.now(),
          level: LogLevel.error,
          step: ProcessStep.other,
          origin: 'debug',
        ),
      );

      // Also print to console for critical errors
      print('ERROR: $message');
      if (error != null) {
        print('Exception: $error');
      }
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
  }

  /// Print network request details
  static void http(
    String method,
    String url, {
    dynamic body,
    dynamic response,
  }) {
    if (_debugMode) {
      _safeAddLog(
        LogEntry(
          message: 'HTTP $method: $url',
          timestamp: DateTime.now(),
          level: LogLevel.verbose,
          step: ProcessStep.other,
          origin: 'network',
        ),
      );

      if (body != null) {
        _safeAddLog(
          LogEntry(
            message: 'Request: $body',
            timestamp: DateTime.now(),
            level: LogLevel.verbose,
            step: ProcessStep.other,
            origin: 'network',
          ),
        );
      }

      if (response != null) {
        _safeAddLog(
          LogEntry(
            message: 'Response: $response',
            timestamp: DateTime.now(),
            level: LogLevel.verbose,
            step: ProcessStep.other,
            origin: 'network',
          ),
        );
      }
    }
  }

  /// Print lifecycle events
  static void lifecycle(String message) {
    if (_debugMode) {
      _safeAddLog(
        LogEntry(
          message: message,
          timestamp: DateTime.now(),
          level: LogLevel.info,
          step: ProcessStep.other,
          origin: 'lifecycle',
        ),
      );
    }
  }

  /// Print server events
  static void server(String message) {
    if (_debugMode) {
      _safeAddLog(
        LogEntry(
          message: message,
          timestamp: DateTime.now(),
          level: LogLevel.info,
          step: ProcessStep.other,
          origin: 'server',
        ),
      );
    }
  }
}
