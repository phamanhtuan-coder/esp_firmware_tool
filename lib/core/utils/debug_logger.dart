import 'package:flutter/foundation.dart';

/// Utility class for debugging with print statements
/// This class provides methods to print debug information with customized format
class DebugLogger {
  /// Whether debug mode is enabled
  static bool _debugMode = true;

  /// Set debug mode on/off
  static void setDebugMode(bool enabled) {
    _debugMode = enabled;
  }

  /// Print debug message with class name and method name
  static void d(String message, {String? className, String? methodName}) {
    if (_debugMode) {
      final now = DateTime.now();
      final timeStr =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}";

      String location = '';
      if (className != null) {
        location += '[$className]';
      }
      if (methodName != null) {
        location += '.$methodName()';
      }

      debugPrint('⚡ DEBUG $timeStr $location: $message');
    }
  }

  /// Print info message
  static void i(String message) {
    if (_debugMode) {
      debugPrint('📘 INFO: $message');
    }
  }

  /// Print warning message
  static void w(String message) {
    if (_debugMode) {
      debugPrint('⚠️ WARNING: $message');
    }
  }

  /// Print error message
  static void e(String message, {dynamic error, StackTrace? stackTrace}) {
    if (_debugMode) {
      debugPrint('🔴 ERROR: $message');
      if (error != null) {
        debugPrint('🔴 $error');
      }
      if (stackTrace != null) {
        debugPrint('🔴 $stackTrace');
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
      debugPrint('📡 HTTP $method: $url');
      if (body != null) {
        debugPrint('📡 Request: $body');
      }
      if (response != null) {
        debugPrint('📡 Response: $response');
      }
    }
  }

  /// Print lifecycle events
  static void lifecycle(String message) {
    if (_debugMode) {
      debugPrint('🔄 LIFECYCLE: $message');
    }
  }

  /// Print server events
  static void server(String message) {
    if (_debugMode) {
      debugPrint('🖧 SERVER: $message');
    }
  }
}
