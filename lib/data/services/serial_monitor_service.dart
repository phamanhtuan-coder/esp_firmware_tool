import 'dart:async';
import 'dart:io' as io;
import 'package:cli_util/cli_logging.dart';
import 'package:process_run/shell.dart';

class SerialMonitorService {
  final _controller = StreamController<String>.broadcast();
  io.Process? _process;
  bool _isRunning = false;
  Logger? _logger;

  Stream<String> get outputStream => _controller.stream;
  bool get isRunning => _isRunning;

  SerialMonitorService() {
    _logger = Logger.standard();
  }

  Future<void> startMonitor(String port, int baudRate) async {
    if (_isRunning) {
      await stopMonitor();
    }

    _isRunning = true;
    String buffer = '';

    try {
      // Create a process using Shell with proper stream handling
      final shell = Shell();
      final command = 'arduino-cli monitor --port $port --config baudrate=$baudRate';

      _controller.add('Starting monitor on $port at $baudRate baud...');
      _logger?.trace('Starting monitor on $port at $baudRate baud...');

      // Run command in shell with manual output handling
      shell.run(command, onProcess: (process) {
        _process = process;

        // Handle stdout with improved line buffering
        process.stdout.listen((data) {
          final output = String.fromCharCodes(data);

          if (output.contains('\n')) {
            // Process complete lines
            final lines = (buffer + output).split('\n');
            // Last element might be incomplete
            buffer = lines.removeLast();

            // Send complete lines
            for (final line in lines) {
              if (line.trim().isNotEmpty) {
                _controller.add(line.trim());
                _logger?.stdout(line.trim());
              }
            }
          } else {
            // Add to buffer for incomplete lines
            buffer += output;

            // If buffer contains a complete message but no newline
            if (buffer.length > 80 || buffer.contains('.') || buffer.endsWith('}')) {
              _controller.add(buffer.trim());
              _logger?.stdout(buffer.trim());
              buffer = '';
            }
          }
        });

        // Handle stderr
        process.stderr.listen((data) {
          final error = String.fromCharCodes(data).trim();
          if (error.isNotEmpty) {
            _controller.add('Error: $error');
            _logger?.stderr(error);
          }
        });
      }).then((_) {
        _isRunning = false;
        _process = null;
        _controller.add('Monitor stopped');
        _logger?.trace('Monitor stopped');
      }).catchError((e) {
        _controller.add('Error: $e');
        _logger?.stderr('Error: $e');
        _isRunning = false;
        _process = null;
      });

      _logger?.trace('Started serial monitor on port $port at $baudRate baud');
    } catch (e) {
      _controller.add('Failed to start monitor: $e');
      _logger?.stderr('Error starting serial monitor: $e');
      _isRunning = false;
    }
  }

  Future<void> stopMonitor() async {
    if (!_isRunning) return;

    try {
      _process?.kill();
      _logger?.trace('Stopped serial monitor');
    } catch (e) {
      _logger?.stderr('Error stopping serial monitor: $e');
    } finally {
      _isRunning = false;
      _process = null;
    }
  }

  Future<void> sendCommand(String command) async {
    if (!_isRunning || _process == null) {
      _controller.add('Cannot send command: monitor not running');
      return;
    }

    try {
      _process?.stdin.writeln(command);
      _logger?.trace('Sent command: $command');
    } catch (e) {
      _controller.add('Failed to send command: $e');
      _logger?.stderr('Error sending command: $e');
    }
  }

  void dispose() {
    stopMonitor();
    _controller.close();
  }
}