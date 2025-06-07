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

  static LoggingBloc get _loggingBloc => GetIt.instance<LoggingBloc>();

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

      _loggingBloc.add(
        AddLogEvent(
          LogEntry(
            message: '$location: $message',
            timestamp: DateTime.now(),
            level: LogLevel.verbose,
            step: ProcessStep.other,
            origin: 'debug',
          ),
        ),
      );
    }
  }

  /// Print info message
  static void i(String message) {
    if (_debugMode) {
      _loggingBloc.add(
        AddLogEvent(
          LogEntry(
            message: message,
            timestamp: DateTime.now(),
            level: LogLevel.info,
            step: ProcessStep.other,
            origin: 'debug',
          ),
        ),
      );
    }
  }

  /// Print warning message
  static void w(String message) {
    if (_debugMode) {
      _loggingBloc.add(
        AddLogEvent(
          LogEntry(
            message: message,
            timestamp: DateTime.now(),
            level: LogLevel.warning,
            step: ProcessStep.other,
            origin: 'debug',
          ),
        ),
      );
    }
  }

  /// Print error message
  static void e(String message, {dynamic error, StackTrace? stackTrace}) {
    if (_debugMode) {
      _loggingBloc.add(
        AddLogEvent(
          LogEntry(
            message: message,
            timestamp: DateTime.now(),
            level: LogLevel.error,
            step: ProcessStep.other,
            origin: 'debug',
          ),
        ),
      );

      if (error != null) {
        _loggingBloc.add(
          AddLogEvent(
            LogEntry(
              message: error.toString(),
              timestamp: DateTime.now(),
              level: LogLevel.error,
              step: ProcessStep.other,
              origin: 'debug',
            ),
          ),
        );
      }

      if (stackTrace != null) {
        _loggingBloc.add(
          AddLogEvent(
            LogEntry(
              message: stackTrace.toString(),
              timestamp: DateTime.now(),
              level: LogLevel.error,
              step: ProcessStep.other,
              origin: 'debug',
            ),
          ),
        );
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
      _loggingBloc.add(
        AddLogEvent(
          LogEntry(
            message: 'HTTP $method: $url',
            timestamp: DateTime.now(),
            level: LogLevel.verbose,
            step: ProcessStep.other,
            origin: 'network',
          ),
        ),
      );

      if (body != null) {
        _loggingBloc.add(
          AddLogEvent(
            LogEntry(
              message: 'Request: $body',
              timestamp: DateTime.now(),
              level: LogLevel.verbose,
              step: ProcessStep.other,
              origin: 'network',
            ),
          ),
        );
      }

      if (response != null) {
        _loggingBloc.add(
          AddLogEvent(
            LogEntry(
              message: 'Response: $response',
              timestamp: DateTime.now(),
              level: LogLevel.verbose,
              step: ProcessStep.other,
              origin: 'network',
            ),
          ),
        );
      }
    }
  }

  /// Print lifecycle events
  static void lifecycle(String message) {
    if (_debugMode) {
      _loggingBloc.add(
        AddLogEvent(
          LogEntry(
            message: message,
            timestamp: DateTime.now(),
            level: LogLevel.info,
            step: ProcessStep.other,
            origin: 'lifecycle',
          ),
        ),
      );
    }
  }

  /// Print server events
  static void server(String message) {
    if (_debugMode) {
      _loggingBloc.add(
        AddLogEvent(
          LogEntry(
            message: message,
            timestamp: DateTime.now(),
            level: LogLevel.info,
            step: ProcessStep.other,
            origin: 'server',
          ),
        ),
      );
    }
  }
}
