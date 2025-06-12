import 'dart:async';
import 'package:get_it/get_it.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/domain/blocs/logging_bloc.dart';

class LogService {
  final List<LogEntry> _logs = [];
  final _logController = StreamController<LogEntry>.broadcast();

  Stream<LogEntry> get logStream => _logController.stream;
  List<LogEntry> get logs => List.unmodifiable(_logs);

  LogService() {
    // Hook up stream to add logs to LoggingBloc
    _logController.stream.listen((log) {
      try {
        // Try to get LoggingBloc and add the log to it
        if (GetIt.instance.isRegistered<LoggingBloc>()) {
          final loggingBloc = GetIt.instance<LoggingBloc>();
          loggingBloc.add(AddLogEvent(log));
        }
      } catch (e) {
        print('Error sending log to LoggingBloc: $e');
      }
    });
  }

  void addLog({
    required String message,
    LogLevel level = LogLevel.info,
    ProcessStep step = ProcessStep.systemEvent,
    String origin = 'app',
    String? deviceId,
    String? rawOutput,
  }) {
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

    // Only add to stream if controller is still active
    if (!_logController.isClosed) {
      _logController.add(log);
    }
  }

  void dispose() {
    _logController.close();
  }
}
