import 'dart:async';
import 'dart:io' as io;
import 'package:cli_util/cli_logging.dart';
import 'package:process_run/shell.dart';

class SerialMonitorService {
  final _controller = StreamController<String>.broadcast();
  io.Process? _process;
  bool _isRunning = false;
  Logger? _logger;
  String? _currentPort;

  Stream<String> get outputStream => _controller.stream;
  bool get isRunning => _isRunning;

  SerialMonitorService() {
    _logger = Logger.standard();
  }

  Future<void> startMonitor(String port, int baudRate) async {
    // Check if already running on the same port with same baud rate
    if (_isRunning && _currentPort == port) {
      _logger?.trace('Monitor already running on port $port');
      return;
    }

    // Stop any existing monitor before starting new one
    await stopMonitor();

    _isRunning = true;
    String buffer = '';
    _currentPort = port;

    try {
      final shell = Shell();
      final command = 'arduino-cli monitor --port $port --config baudrate=$baudRate';

      _logger?.trace('Starting monitor on $port at $baudRate baud...');

      // Use a flag to prevent multiple process starts
      bool processStarted = false;

      shell.run(command, onProcess: (process) {
        if (processStarted) {
          _logger?.stderr('Process already started for port $port');
          return;
        }
        processStarted = true;
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
        _currentPort = null;
        _controller.add('Monitor stopped');
        _logger?.trace('Monitor stopped');
      }).catchError((e) {
        _controller.add('Error: $e');
        _logger?.stderr('Error: $e');
        _isRunning = false;
        _process = null;
        _currentPort = null;
      });

      _logger?.trace('Started serial monitor on port $port at $baudRate baud');
    } catch (e) {
      _controller.add('Failed to start monitor: $e');
      _logger?.stderr('Error starting serial monitor: $e');
      _isRunning = false;
      _process = null;
      _currentPort = null;
    }
  }

  Future<void> stopMonitor() async {
    if (!_isRunning) return;

    _isRunning = false;
    try {
      if (_process != null) {
        _process!.kill(io.ProcessSignal.sigterm);
        await _process!.exitCode.timeout(Duration(seconds: 3), onTimeout: () {
          _process!.kill(io.ProcessSignal.sigkill);
          return -1;
        });
      }

      if (io.Platform.isWindows && _currentPort != null) {
        try {
          final shell = Shell();
          await shell.run('mode $_currentPort BAUD=9600 PARITY=n DATA=8 STOP=1');
          await shell.run('taskkill /F /IM arduino-cli.exe');
        } catch (e) {
          _logger?.stderr('Error resetting port: $e');
        }
      }

      _logger?.trace('Stopped serial monitor');
    } catch (e) {
      _logger?.stderr('Error stopping serial monitor: $e');
    } finally {
      _process = null;
      _currentPort = null;
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

  Future<void> dispose() async {
    await stopMonitor();
    await _controller.close();
  }
}