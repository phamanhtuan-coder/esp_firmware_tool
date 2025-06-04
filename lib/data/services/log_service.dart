import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:libserialport/libserialport.dart';

import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class LogService {
  // Stream controller for broadcasting logs to UI
  final _logStreamController = StreamController<LogEntry>.broadcast();

  // Stream controller specifically for serial monitor data
  final _serialMonitorStreamController = StreamController<List<LogEntry>>.broadcast();

  // Current active process (compile, upload, etc.)
  Process? _activeProcess;

  // Serial monitor process
  Process? _serialMonitorProcess;

  // Console log process
  Process? _consoleLogProcess;

  // Whether console log is active
  bool _consoleLogActive = false;

  // Device currently being monitored
  String? _currentDeviceId;

  // Whether the serial monitor is active
  bool _serialMonitorActive = false;

  // Base directory for firmware templates
  String? _firmwareTemplatesDir;

  // Serial port instance for native serial monitor
  SerialPort? _serialPort;

  // Buffer for serial data with configurable maximum size
  final List<LogEntry> _serialBuffer = [];
  static const int _maxBufferSize = 5000; // Maximum number of entries to keep in buffer

  // Current display mode for serial data
  DataDisplayMode _serialDisplayMode = DataDisplayMode.ascii;

  // Auto-scroll flag
  bool _autoScroll = true;

  // Public stream for UI to listen to
  Stream<LogEntry> get logStream => _logStreamController.stream;

  // Public stream specifically for serial monitor data
  Stream<List<LogEntry>> get serialMonitorStream => _serialMonitorStreamController.stream;

  // Getter for current display mode
  DataDisplayMode get serialDisplayMode => _serialDisplayMode;

  // Getter for auto-scroll flag
  bool get autoScroll => _autoScroll;

  // Setter for auto-scroll
  set autoScroll(bool value) {
    _autoScroll = value;
  }

  // Get the current serial buffer
  List<LogEntry> getSerialBuffer() {
    return List<LogEntry>.from(_serialBuffer);
  }

  // Clear the serial buffer
  void clearSerialBuffer() {
    _serialBuffer.clear();
    _serialMonitorStreamController.add([]);
  }

  // Check if serial monitor is active
  bool isSerialMonitorActive() {
    return _serialMonitorActive;
  }

  // Set the display mode for serial data
  void setDisplayMode(DataDisplayMode mode) {
    _serialDisplayMode = mode;
    // Broadcast updated buffer with new display mode
    _serialMonitorStreamController.add(_serialBuffer);
  }

  // Constructor to initialize the service
  LogService() {
    _initFirmwareTemplatesDir();
  }

  // Initialize the service
  Future<void> initialize() async {
    await _initFirmwareTemplatesDir();

    // Add initial system log
    addLog(
      message: 'Log service initialized',
      level: LogLevel.info,
      step: ProcessStep.systemEvent,
      origin: 'system',
    );
  }

  // Initialize the firmware templates directory
  Future<void> _initFirmwareTemplatesDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    _firmwareTemplatesDir = path.join(appDir.path, 'firmware_templates');

    // Create directory if it doesn't exist
    final dir = Directory(_firmwareTemplatesDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  // Method to add a log entry from any source
  void addLog({
    required String message,
    required LogLevel level,
    required ProcessStep step,
    String deviceId = '',
    bool requiresInput = false,
    String? origin,
    String? rawOutput,
  }) {
    final entry = LogEntry(
      message: message,
      timestamp: DateTime.now(),
      level: level,
      step: step,
      deviceId: deviceId,
      requiresInput: requiresInput,
      origin: origin,
      rawOutput: rawOutput,
    );

    // Debug trace for all logs to help with troubleshooting
    if (level == LogLevel.serialOutput || level == LogLevel.debug) {
      print('LOG_TRACE [${entry.formattedTimestamp}] (${level.name}): $message');
    }

    _logStreamController.add(entry);
    print('DEBUG: LogService emitted log: ${entry.message}, level: ${entry.level}');

    // Add to serial buffer if it's serial output
    if (level == LogLevel.serialOutput) {
      _serialBuffer.add(entry);
      if (_serialBuffer.length > _maxBufferSize) {
        _serialBuffer.removeAt(0);
      }
      print('SERIAL_BUFFER_UPDATE: Added entry to buffer, length=${_serialBuffer.length}');
      _serialMonitorStreamController.add(_serialBuffer);
    }
  }

  // Handle process output and convert to log entries with improved Arduino CLI output parsing
  void _processOutput(String output, ProcessStep step, String deviceId, {String? origin}) {
    // Special handling for Arduino CLI output
    if (output.startsWith('[STDOUT]') || output.startsWith('[STDERR]')) {
      var logLevel = LogLevel.info;
      var message = output.substring(output.indexOf(']') + 1).trim();

      // Determine log level based on content
      if (output.toLowerCase().contains('error') || output.toLowerCase().contains('failed')) {
        logLevel = LogLevel.error;
      } else if (output.toLowerCase().contains('warning')) {
        logLevel = LogLevel.warning;
      } else if (output.contains('Sketch uses') ||
                 output.contains('bytes written') ||
                 output.contains('Uploading...done')) {
        logLevel = LogLevel.success;
      } else if (output.contains('avrdude:') ||
                 output.contains('Reading |') ||
                 output.contains('Writing |')) {
        logLevel = LogLevel.verbose;
      }

      // Always add logs to the stream instead of replacing
      addLog(
        message: message,
        level: logLevel,
        step: step,
        deviceId: deviceId,
        origin: 'arduino-cli',
        rawOutput: output,
      );
      return;
    }

    // Handle other output types based on content - always add to log stream
    if (output.toLowerCase().contains('error') || output.toLowerCase().contains('failed')) {
      addLog(
        message: output,
        level: LogLevel.error,
        step: step,
        deviceId: deviceId,
        origin: origin ?? 'system',
        rawOutput: output,
      );
    } else if (output.toLowerCase().contains('warning')) {
      addLog(
        message: output,
        level: LogLevel.warning,
        step: step,
        deviceId: deviceId,
        origin: origin ?? 'system',
        rawOutput: output,
      );
    } else if (output.contains('Success') ||
               output.contains('Done') ||
               output.contains('Uploaded') ||
               output.contains('bytes written')) {
      addLog(
        message: output,
        level: LogLevel.success,
        step: step,
        deviceId: deviceId,
        origin: origin ?? 'system',
        rawOutput: output,
      );
    } else if (output.contains('Starting upload') ||
               output.contains('Compiling') ||
               output.contains('Verifying') ||
               output.contains('Reading') ||
               output.contains('Writing')) {
      addLog(
        message: output,
        level: LogLevel.verbose,
        step: step,
        deviceId: deviceId,
        origin: origin ?? 'system',
        rawOutput: output,
      );
    } else {
      // For all other outputs, add as info level
      addLog(
        message: output,
        level: LogLevel.info,
        step: step,
        deviceId: deviceId,
        origin: origin ?? 'system',
        rawOutput: output,
      );
    }
  }

  // Run a process and stream its output as logs with improved error handling
  Future<int> runProcess(
    String executable,
    List<String> arguments, {
    required ProcessStep step,
    String workingDirectory = '',
    String deviceId = '',
    Map<String, String>? environment,
    bool showCommandInLogs = true,
  }) async {
    try {
      // Kill any existing process
      await killActiveProcess();

      // Start the new process
      _activeProcess = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory.isNotEmpty ? workingDirectory : null,
        environment: environment,
      );

      // Add log entry showing the command being executed if requested
      if (showCommandInLogs) {
        final commandString = '$executable ${arguments.join(' ')}';
        addLog(
          message: 'Running: $commandString',
          level: LogLevel.info,
          step: step,
          deviceId: deviceId,
          origin: 'system',
        );
      }

      // Stream stdout with improved line handling
      _activeProcess!.stdout
        .transform(utf8.decoder)
        .listen((data) {
          // Process line by line or handle as chunk if needed
          final lines = data.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              _processOutput(line.trim(), step, deviceId);
            }
          }
        });

      // Stream stderr
      _activeProcess!.stderr
        .transform(utf8.decoder)
        .listen((data) {
          final lines = data.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              _processOutput(line.trim(), step, deviceId);
            }
          }
        });

      // Wait for process to complete
      final exitCode = await _activeProcess!.exitCode;

      if (exitCode == 0) {
        addLog(
          message: 'Process completed successfully',
          level: LogLevel.success,
          step: step,
          deviceId: deviceId,
          origin: 'system',
        );
      } else {
        addLog(
          message: 'Process failed with exit code: $exitCode',
          level: LogLevel.error,
          step: step,
          deviceId: deviceId,
          origin: 'system',
        );
      }

      _activeProcess = null;
      return exitCode;
    } catch (e) {
      addLog(
        message: 'Failed to start process: $e',
        level: LogLevel.error,
        step: step,
        deviceId: deviceId,
        origin: 'system',
      );
      return -1;
    }
  }

  // Enhanced serial monitor with better input handling and debugging logs
  Future<bool> startSerialMonitor(String port, int baudRate, String deviceId) async {
    print('DEBUG: Starting serial monitor on port $port at $baudRate baud');
    await stopSerialMonitor();

    try {
      // Add debug log to track serial monitor start
      addLog(
        message: 'Attempting to start serial monitor on port $port at $baudRate baud',
        level: LogLevel.debug,
        step: ProcessStep.serialMonitor,
        deviceId: deviceId,
        origin: 'system',
      );

      // Start Arduino CLI monitor with specific configuration for better data handling
      _serialMonitorProcess = await Process.start(
        'arduino-cli',
        [
          'monitor',
          '--port', port,
          '--config', 'baudrate=$baudRate',
          '--config', 'parity=none',
          '--config', 'databits=8',
          '--config', 'stopbits=1',
        ],
      );

      print('DEBUG: Serial monitor process started with PID: ${_serialMonitorProcess?.pid}');

      _currentDeviceId = deviceId;
      _serialMonitorActive = true;

      // Set up stdout handler with detailed logging
      _serialMonitorProcess!.stdout.listen(
        (List<int> data) {
          print('DEBUG: Received raw data length: ${data.length}');
          try {
            final String text = utf8.decode(data);
            print('DEBUG: Decoded data: $text');
            if (text.trim().isNotEmpty) {
              addLog(
                message: text.trim(),
                level: LogLevel.serialOutput,
                step: ProcessStep.serialMonitor,
                deviceId: deviceId,
                origin: 'serial-monitor',
                rawOutput: text,
              );
            }
          } catch (e) {
            print('DEBUG: Error decoding serial data: $e');
            // Try hex output for debugging
            print('DEBUG: Raw hex data: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
          }
        },
        onError: (error) {
          print('DEBUG: Error in serial monitor stdout stream: $error');
          addLog(
            message: 'Serial monitor error: $error',
            level: LogLevel.error,
            step: ProcessStep.serialMonitor,
            deviceId: deviceId,
            origin: 'system',
          );
        },
        cancelOnError: false,
      );

      // Set up stderr handler with logging
      _serialMonitorProcess!.stderr.listen(
        (data) {
          print('DEBUG: Received stderr data');
          final text = utf8.decode(data);
          if (text.trim().isNotEmpty) {
            addLog(
              message: text.trim(),
              level: LogLevel.error,
              step: ProcessStep.serialMonitor,
              deviceId: deviceId,
              origin: 'serial-monitor',
            );
          }
        },
        onError: (error) {
          print('DEBUG: Error in serial monitor stderr stream: $error');
        },
        cancelOnError: false,
      );

      return true;
    } catch (e) {
      print('DEBUG: Exception starting serial monitor: $e');
      addLog(
        message: 'Failed to start serial monitor: $e',
        level: LogLevel.error,
        step: ProcessStep.serialMonitor,
        deviceId: deviceId,
        origin: 'system',
      );
      _serialMonitorActive = false;
      return false;
    }
  }

  Future<bool> startNativeSerialMonitor(String port, int baudRate, String deviceId) async {
    print('DEBUG: Starting native serial monitor on port $port at $baudRate baud');
    await stopSerialMonitor();

    try {
      // Add debug log to track native serial monitor start attempt
      addLog(
        message: 'Attempting to start native serial monitor on port $port at $baudRate baud',
        level: LogLevel.debug,
        step: ProcessStep.serialMonitor,
        deviceId: deviceId,
        origin: 'system',
      );

      // Create and configure serial port
      final serialPort = SerialPort(port);

      // Check if port exists before trying to open
      print('DEBUG: Available ports: ${SerialPort.availablePorts.join(", ")}');
      if (!SerialPort.availablePorts.contains(port)) {
        print('DEBUG: Port $port not found in available ports');
        addLog(
          message: 'Port $port not available. Available ports: ${SerialPort.availablePorts.join(", ")}',
          level: LogLevel.error,
          step: ProcessStep.serialMonitor,
          deviceId: deviceId,
          origin: 'system',
        );
        return false;
      }

      // Try to open the port with read/write permissions
      if (!serialPort.openReadWrite()) {
        final error = SerialPort.lastError;
        print('DEBUG: Failed to open port $port: $error');
        final errorMessage = error != null ?
            'Failed to open serial port: $error' :
            'Failed to open serial port (unknown error)';

        addLog(
          message: errorMessage,
          level: LogLevel.error,
          step: ProcessStep.serialMonitor,
          deviceId: deviceId,
          origin: 'system',
        );
        return false;
      }

      print('DEBUG: Successfully opened port $port');

      // Configure port parameters with proper settings for Arduino/ESP devices
      serialPort.config = SerialPortConfig()
        ..baudRate = baudRate
        ..bits = 8
        ..stopBits = 1
        ..parity = 0
        ..setFlowControl(SerialPortFlowControl.none);

      // Set DTR and RTS signals using direct control methods
      // These are critical for Arduino/ESP32 communication
      try {
        // The signals need to be set directly on the port, not on the config
        // For Arduino/ESP boards, we often need these signals enabled
        serialPort.write(Uint8List.fromList([
          0x80, // Enable DTR (sometimes helps with auto-reset)
          0x02  // RTS related command on some implementations
        ]));

        print('DEBUG: Control signals sent to port');
      } catch (e) {
        print('DEBUG: Failed to set control signals: $e');
      }

      print('DEBUG: Port configuration set');

      // Flush buffers to ensure clean start
      serialPort.flush();

      // Add a connection established message that mimics Arduino IDE style
      addLog(
        message: 'Serial monitor connection established',
        level: LogLevel.serialOutput,
        step: ProcessStep.serialMonitor,
        deviceId: deviceId,
        origin: 'serial-monitor',
        rawOutput: 'Serial monitor connection established',
      );

      // Create a reader for the port
      final reader = SerialPortReader(serialPort);

      print('DEBUG: Created SerialPortReader');

      // Create a buffer to handle data that spans multiple reads
      final StringBuffer lineBuffer = StringBuffer();

      // Start reading data with better error handling
      reader.stream.listen(
        (Uint8List data) {
          if (data.isNotEmpty) {
            try {
              // Convert byte data to string
              final String dataString = String.fromCharCodes(data);

              print('DEBUG: Received raw data (${data.length} bytes): ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
              print('DEBUG: Converted message: $dataString');

              // Add to line buffer
              lineBuffer.write(dataString);

              // Process the buffer content
              String bufferContent = lineBuffer.toString();

              // Check for line endings (CR, LF, or CRLF)
              if (bufferContent.contains('\n') || bufferContent.contains('\r')) {
                // Split by common line endings
                List<String> lines = bufferContent.split(RegExp(r'\r\n|\r|\n'));

                // Process complete lines (all except the last one)
                for (int i = 0; i < lines.length - 1; i++) {
                  String line = lines[i].trim();
                  if (line.isNotEmpty) {
                    print('DEBUG: Complete line found: $line');
                    addLog(
                      message: line,
                      level: LogLevel.serialOutput,
                      step: ProcessStep.serialMonitor,
                      deviceId: deviceId,
                      origin: 'serial-monitor',
                      rawOutput: line,
                    );
                  }
                }

                // Keep the last (potentially incomplete) line in the buffer
                lineBuffer.clear();
                lineBuffer.write(lines.last);
              }

              // For long content without line breaks, periodically flush the buffer
              if (lineBuffer.length > 1024) {
                String content = lineBuffer.toString().trim();
                if (content.isNotEmpty) {
                  print('DEBUG: Flushing large buffer content');
                  addLog(
                    message: content,
                    level: LogLevel.serialOutput,
                    step: ProcessStep.serialMonitor,
                    deviceId: deviceId,
                    origin: 'serial-monitor',
                    rawOutput: content,
                  );
                  lineBuffer.clear();
                }
              }
            } catch (e) {
              print('DEBUG: Error processing serial data: $e');
              addLog(
                message: 'Error processing serial data: $e',
                level: LogLevel.error,
                step: ProcessStep.serialMonitor,
                deviceId: deviceId,
                origin: 'system',
              );
            }
          }
        },
        onError: (error) {
          print('DEBUG: Error in SerialPortReader stream: $error');
          addLog(
            message: 'Serial port error: $error',
            level: LogLevel.error,
            step: ProcessStep.serialMonitor,
            deviceId: deviceId,
            origin: 'system',
          );
        },
        onDone: () {
          print('DEBUG: SerialPortReader stream closed');
          addLog(
            message: 'Serial port connection closed',
            level: LogLevel.info,
            step: ProcessStep.serialMonitor,
            deviceId: deviceId,
            origin: 'system',
          );
          if (serialPort.isOpen) {
            serialPort.close();
          }
        },
      );

      _serialMonitorActive = true;
      _currentDeviceId = deviceId;

      // Store the serial port instance for cleanup
      _serialPort = serialPort;

      return true;
    } catch (e) {
      print('DEBUG: Exception in startNativeSerialMonitor: $e');
      addLog(
        message: 'Failed to start native serial monitor: $e',
        level: LogLevel.error,
        step: ProcessStep.serialMonitor,
        deviceId: deviceId,
        origin: 'system',
      );
      return false;
    }
  }

  Future<bool> startAlternativeSerialMonitor(String port, int baudRate, String deviceId) async {
    await stopSerialMonitor();

    try {
      // Try using screen command for more reliable serial communication
      _serialMonitorProcess = await Process.start(
        'screen',
        [port, baudRate.toString()],
        mode: ProcessStartMode.inheritStdio,
      );

      _currentDeviceId = deviceId;
      _serialMonitorActive = true;

      addLog(
        message: 'Serial monitor started using screen on port $port at $baudRate baud',
        level: LogLevel.info,
        step: ProcessStep.serialMonitor,
        deviceId: deviceId,
        origin: 'system',
      );

      return true;
    } catch (e) {
      // If screen fails, try using minicom
      try {
        _serialMonitorProcess = await Process.start(
          'minicom',
          ['-D', port, '-b', baudRate.toString()],
          mode: ProcessStartMode.inheritStdio,
        );

        addLog(
          message: 'Serial monitor started using minicom on port $port at $baudRate baud',
          level: LogLevel.info,
          step: ProcessStep.serialMonitor,
          deviceId: deviceId,
          origin: 'system',
        );

        return true;
      } catch (e) {
        addLog(
          message: 'Failed to start alternative serial monitor: $e',
          level: LogLevel.error,
          step: ProcessStep.serialMonitor,
          deviceId: deviceId,
          origin: 'system',
        );
        return false;
      }
    }
  }

  // Start console log monitoring like in Arduino IDE
  Future<bool> startConsoleLog(String sketchPath, String deviceId) async {
    // Close any existing console log monitor
    await stopConsoleLog();

    try {
      final sketchDirectory = path.dirname(sketchPath);

      // Start Arduino CLI compilation process with verbose output
      _consoleLogProcess = await Process.start(
        'arduino-cli',
        ['compile', '--verbose', '--log-level', 'debug', '-b', getBoardFqbn(deviceId), sketchPath],
        workingDirectory: sketchDirectory,
      );

      _consoleLogActive = true;

      addLog(
        message: 'Console log monitor started for sketch: ${path.basename(sketchPath)}',
        level: LogLevel.info,
        step: ProcessStep.consoleLog,
        deviceId: deviceId,
        origin: 'system',
      );

      // Stream stdout from console log
      _consoleLogProcess!.stdout
        .transform(utf8.decoder)
        .listen((data) {
          final lines = data.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              _processOutput(
                line.trim(),
                ProcessStep.consoleLog,
                deviceId,
                origin: 'console-log'
              );
            }
          }
        });

      // Stream stderr from console log
      _consoleLogProcess!.stderr
        .transform(utf8.decoder)
        .listen((data) {
          final lines = data.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              _processOutput(
                line.trim(),
                ProcessStep.consoleLog,
                deviceId,
                origin: 'console-log'
              );
            }
          }
        });

      // Monitor the process exit
      _consoleLogProcess!.exitCode.then((exitCode) {
        _consoleLogActive = false;
        _consoleLogProcess = null;

        addLog(
          message: 'Console log monitor ended with exit code: $exitCode',
          level: exitCode == 0 ? LogLevel.success : LogLevel.error,
          step: ProcessStep.consoleLog,
          deviceId: deviceId,
          origin: 'system',
        );
      });

      return true;
    } catch (e) {
      addLog(
        message: 'Failed to start console log monitor: $e',
        level: LogLevel.error,
        step: ProcessStep.consoleLog,
        deviceId: deviceId,
        origin: 'system',
      );
      return false;
    }
  }

  // Stop console log monitoring
  Future<void> stopConsoleLog() async {
    if (_consoleLogProcess != null) {
      _consoleLogActive = false;

      try {
        _consoleLogProcess!.kill();
        await _consoleLogProcess!.exitCode;
      } catch (e) {
        addLog(
          message: 'Error stopping console log monitor: $e',
          level: LogLevel.error,
          step: ProcessStep.consoleLog,
          origin: 'system',
        );
      }

      _consoleLogProcess = null;
    }
  }

  // Determine board FQBN based on deviceId (simplified - in real code, look this up from device info)
  String getBoardFqbn(String deviceId) {
    if (deviceId.toLowerCase().contains('esp32')) {
      return 'esp32:esp32:esp32';
    } else if (deviceId.toLowerCase().contains('esp8266')) {
      return 'esp8266:esp8266:generic';
    } else if (deviceId.toLowerCase().contains('arduino_uno_r3')) {
      return 'arduino:avr:uno'; // Add Arduino UNO R3
    } else {
      return 'arduino:avr:uno'; // Default to Arduino Uno
    }
  }

  // Start both serial monitor and console log for combined Arduino IDE-like experience
  Future<bool> startArduinoIdeExperience(String port, int baudRate, String sketchPath, String deviceId) async {
    final serialStarted = await startSerialMonitor(port, baudRate, deviceId);
    final consoleStarted = await startConsoleLog(sketchPath, deviceId);

    return serialStarted && consoleStarted;
  }

  // Send data to the serial monitor with improved input handling
  void sendToSerialMonitor(String data) {
    if (_serialPort != null && _serialMonitorActive) {
      try {
        final bytes = Uint8List.fromList('$data\n'.codeUnits);
        _serialPort!.write(bytes);

        addLog(
          message: '> $data',
          level: LogLevel.input,
          step: ProcessStep.serialMonitor,
          deviceId: _currentDeviceId ?? '',
          origin: 'user-input',
        );
      } catch (e) {
        addLog(
          message: 'Failed to send data to serial port: $e',
          level: LogLevel.error,
          step: ProcessStep.serialMonitor,
          deviceId: _currentDeviceId ?? '',
          origin: 'system',
        );
      }
    } else {
      addLog(
        message: 'No active serial connection to send data to',
        level: LogLevel.warning,
        step: ProcessStep.serialMonitor,
        deviceId: _currentDeviceId ?? '',
        origin: 'system',
      );
    }
  }

  // Helper method to send data to serial port
  void sendToSerial(String port, String data) {
    try {
      final serialPort = SerialPort(port);
      if (!serialPort.openWrite()) {
        addLog(
          message: 'Failed to open port $port for writing',
          level: LogLevel.error,
          step: ProcessStep.serialMonitor,
          origin: 'system',
        );
        return;
      }

      // Add newline if not present
      final dataToSend = data.endsWith('\n') ? data : '$data\n';
      final bytes = utf8.encode(dataToSend);
      serialPort.write(Uint8List.fromList(bytes));

      // Log the sent command
      addLog(
        message: '> $data',
        level: LogLevel.input,
        step: ProcessStep.serialMonitor,
        origin: 'serial-monitor',
      );

      serialPort.close();
    } catch (e) {
      addLog(
        message: 'Error sending data to serial port: $e',
        level: LogLevel.error,
        step: ProcessStep.serialMonitor,
        origin: 'system',
      );
    }
  }

  // Stop the serial monitor with improved cleanup
  Future<void> stopSerialMonitor() async {
    if (_serialPort != null) {
      try {
        _serialPort!.close();
      } catch (e) {
        addLog(
          message: 'Error closing serial port: $e',
          level: LogLevel.error,
          step: ProcessStep.serialMonitor,
          deviceId: _currentDeviceId ?? '',
          origin: 'system',
        );
      }
      _serialPort = null;
    }

    if (_serialMonitorProcess != null) {
      _serialMonitorActive = false;

      // Send a final log if we know the device ID
      if (_currentDeviceId != null) {
        addLog(
          message: 'Closing serial monitor...',
          level: LogLevel.info,
          step: ProcessStep.serialMonitor,
          deviceId: _currentDeviceId!,
          origin: 'system',
        );
      }

      // Try to kill the process
      try {
        _serialMonitorProcess!.kill();
        await _serialMonitorProcess!.exitCode;
      } catch (e) {
        addLog(
          message: 'Error killing serial monitor: $e',
          level: LogLevel.error,
          step: ProcessStep.serialMonitor,
          deviceId: _currentDeviceId ?? '',
          origin: 'system',
        );
      }

      _serialMonitorProcess = null;
      _currentDeviceId = null;
    }
  }

  // Stop all monitors and close completely
  Future<void> stopAll() async {
    await stopSerialMonitor();
    await stopConsoleLog();
    await killActiveProcess();
  }

  // Kill any active process with improved cleanup
  Future<void> killActiveProcess() async {
    if (_activeProcess != null) {
      try {
        _activeProcess!.kill();
      } catch (e) {
        addLog(
          message: 'Error killing active process: $e',
          level: LogLevel.error,
          step: ProcessStep.systemEvent,
          origin: 'system',
        );
      }
      _activeProcess = null;
    }
  }

  // Dispose of resources
  Future<void> dispose() async {
    await stopAll();

    try {
      await _logStreamController.close();
    } catch (e) {
      print('Error closing log stream controller: $e');
    }
  }
}
