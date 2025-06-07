import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:get_it/get_it.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:smart_net_firmware_loader/data/services/serial_monitor_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/domain/blocs/logging_bloc.dart';

class LineDisplay {
  final String timestamp;
  final String content;
  bool isSystemMessage;

  LineDisplay(this.timestamp, this.content, {this.isSystemMessage = false});
}

class SerialMonitorTerminalWidget extends StatefulWidget {
  final String? initialPort;
  final int initialBaudRate;
  final bool autoStart;
  final bool isActiveTab;

  const SerialMonitorTerminalWidget({
    super.key,
    this.initialPort,
    this.initialBaudRate = 115200,
    this.autoStart = false,
    this.isActiveTab = true,
  });

  @override
  State<SerialMonitorTerminalWidget> createState() =>
      _SerialMonitorTerminalWidgetState();
}

class _SerialMonitorTerminalWidgetState
    extends State<SerialMonitorTerminalWidget> {
  final SerialMonitorService _monitorService =
      GetIt.instance<SerialMonitorService>();
  final List<LineDisplay> _lines = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final Ansi _ansi;
  final bool _isAutoScrollEnabled = true;
  StreamSubscription? _subscription;
  StreamSubscription? _statusSubscription;
  bool _isMonitorActive = false;

  // Keep track of last used port and baud rate
  String? _lastPort;
  int? _lastBaudRate;

  final List<int> _baudRates = [
    300,
    1200,
    2400,
    4800,
    9600,
    19200,
    38400,
    57600,
    74880,
    115200,
    230400,
    250000,
    500000,
    921600,
    1000000,
    2000000,
  ];
  int _selectedBaudRate = 115200;

  @override
  void initState() {
    super.initState();
    _ansi = Ansi(Ansi.terminalSupportsAnsi);
    _selectedBaudRate = widget.initialBaudRate;

    final timestamp = DateTime.now().toString().split('.').first;
    _lines.add(
      LineDisplay(
        timestamp,
        'Welcome to Serial Monitor',
        isSystemMessage: true,
      ),
    );
    _lines.add(
      LineDisplay(
        timestamp,
        'Select COM port and baud rate to start monitoring',
        isSystemMessage: true,
      ),
    );

    _setupSerialMonitor();
  }

  void _setupSerialMonitor() {
    if (!mounted) return;

    // Setup output stream subscription
    _subscription = _monitorService.outputStream.listen(
      (data) {
        if (mounted) {
          _addLine(data);
          context.read<LoggingBloc>().add(
            AddLogEvent(
              LogEntry(
                message: data,
                timestamp: DateTime.now(),
                level: LogLevel.serialOutput,
                step: ProcessStep.serialMonitor,
                origin: 'serial-monitor',
                rawOutput: data,
              ),
            ),
          );
        }
      },
      onError: (error) {
        if (mounted) {
          _addLine('Error: $error', isSystemMessage: true);
          context.read<LoggingBloc>().add(
            AddLogEvent(
              LogEntry(
                message: 'Error: $error',
                timestamp: DateTime.now(),
                level: LogLevel.error,
                step: ProcessStep.serialMonitor,
                origin: 'serial-monitor',
              ),
            ),
          );
        }
      },
      cancelOnError: false,
    );

    // Setup status stream subscription
    _statusSubscription = _monitorService.statusStream.listen(
      (status) {
        if (mounted) {
          _handleStatusUpdate(status);
        }
      },
      onError: (error) {
        if (mounted) {
          _addLine('Status Error: $error', isSystemMessage: true);
        }
      },
      cancelOnError: false,
    );

    // Start monitor if conditions are met
    if (widget.isActiveTab && widget.initialPort != null) {
      _initializeMonitor();
    }
  }

  void _handleStatusUpdate(bool status) {
    setState(() {
      _isMonitorActive = status;
    });

    if (status) {
      _addLine('Serial monitor connected and active', isSystemMessage: true);
    } else {
      _addLine('Serial monitor disconnected', isSystemMessage: true);
    }
  }

  void _initializeMonitor() {
    if (!widget.isActiveTab || !mounted) {
      _addLine('Not starting monitor - tab not active', isSystemMessage: true);
      return;
    }

    if (widget.initialPort != null &&
        widget.initialPort!.isNotEmpty &&
        _selectedBaudRate > 0) {
      _stopMonitor();

      // Add a delay before starting to allow port to stabilize
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && widget.isActiveTab) {
          _addLine(
            'Starting monitor on ${widget.initialPort} at $_selectedBaudRate baud...',
            isSystemMessage: true,
          );
          _monitorService.startMonitor(widget.initialPort!, _selectedBaudRate);
          _isMonitorActive = true;
        }
      });
    }
  }

  void _stopMonitor() {
    if (_isMonitorActive && mounted) {
      _monitorService.stopMonitor();
      _isMonitorActive = false;
      _addLine('Serial monitor stopped', isSystemMessage: true);
    }
  }

  void _restartMonitor() {
    if (widget.initialPort != null &&
        widget.initialPort!.isNotEmpty &&
        mounted) {
      _stopMonitor();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && widget.isActiveTab) {
          _monitorService.startMonitor(widget.initialPort!, _selectedBaudRate);
          _isMonitorActive = true;
          _addLine(
            'Restarting monitor on ${widget.initialPort} at $_selectedBaudRate baud...',
            isSystemMessage: true,
          );
        }
      });
    }
  }

  void _addLine(String line, {bool isSystemMessage = false}) {
    if (!mounted) return;

    setState(() {
      final timestamp = DateTime.now().toString().split('.').first;
      final processedLine = _processAnsiCodes(line);
      _lines.add(
        LineDisplay(timestamp, processedLine, isSystemMessage: isSystemMessage),
      );
      while (_lines.length > 1000) {
        _lines.removeAt(0);
      }
    });

    if (_isAutoScrollEnabled && mounted && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _updateLines(String data) {
    if (!mounted) return;
    setState(() {
      _lines.add(LineDisplay(
        DateTime.now().toString().split('.').first,
        data,
      ));
      while (_lines.length > 1000) {
        _lines.removeAt(0);
      }
    });

    if (_isAutoScrollEnabled && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  String _processAnsiCodes(String text) {
    return text
        .replaceAll(_ansi.bold, '')
        .replaceAll(_ansi.none, '')
        .replaceAll(_ansi.red, '')
        .replaceAll(_ansi.green, '')
        .replaceAll(_ansi.yellow, '')
        .replaceAll(_ansi.blue, '')
        .replaceAll(_ansi.magenta, '')
        .replaceAll(_ansi.cyan, '')
        .replaceAll(_ansi.gray, '');
  }

  void _sendCommand() {
    final command = _inputController.text.trim();
    if (command.isNotEmpty && mounted) {
      _monitorService.sendCommand(command);
      _inputController.clear();
      context.read<LoggingBloc>().add(
        AddLogEvent(
          LogEntry(
            message: 'Sent command: $command',
            timestamp: DateTime.now(),
            level: LogLevel.input,
            step: ProcessStep.serialMonitor,
            origin: 'user-input',
          ),
        ),
      );
    }
  }

  void _stopMonitorAndCleanup() {
    if (mounted) {
      final logService = GetIt.instance<LogService>();
      logService.stopSerialMonitor();
      _stopMonitor();
    }
  }

  @override
  void didUpdateWidget(SerialMonitorTerminalWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!mounted) return;

    // Handle tab activation/deactivation
    if (widget.isActiveTab != oldWidget.isActiveTab) {
      if (widget.isActiveTab) {
        _addLine('Tab activated - initializing monitor...', isSystemMessage: true);
        Future.delayed(const Duration(milliseconds: 500), () {
          _stopMonitor();
          Future.delayed(const Duration(milliseconds: 300), _initializeMonitor);
        });
      } else {
        _addLine('Tab deactivated - stopping monitor...', isSystemMessage: true);
        _stopMonitor();
      }
    }
    // Handle port/baud rate changes
    else if (widget.isActiveTab &&
             (oldWidget.initialPort != widget.initialPort ||
              oldWidget.initialBaudRate != widget.initialBaudRate)) {
      _addLine(
        'Port or baud rate changed - restarting monitor...',
        isSystemMessage: true
      );
      _stopMonitor();
      Future.delayed(const Duration(milliseconds: 300), _initializeMonitor);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
    _stopMonitor();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkTheme ? Colors.black : AppColors.componentBackground,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  child: StreamBuilder<String>(
                    stream: _monitorService.outputStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        // Schedule update for next frame
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _updateLines(snapshot.data!);
                        });
                      }

                      return Scrollbar(
                        thumbVisibility: true,
                        controller: _scrollController,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SelectableText.rich(
                              TextSpan(
                                children: List<TextSpan>.from(_lines.map((line) =>
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '[${line.timestamp}] ',
                                        style: TextStyle(
                                          color: line.isSystemMessage
                                              ? Colors.yellow.withOpacity(0.8)
                                              : Colors.grey.withOpacity(0.7),
                                          fontFamily: 'Courier New',
                                          fontSize: 12.0,
                                          height: 1.5,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '${line.content}\n',
                                        style: TextStyle(
                                          color: line.isSystemMessage
                                              ? Colors.yellow
                                              : isDarkTheme
                                                  ? Colors.lightGreenAccent
                                                  : const Color(0xFF2E7D32),
                                          fontFamily: 'Courier New',
                                          fontSize: 14.0,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  )
                                ).toList()),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkTheme ? Colors.grey.shade800 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: StreamBuilder<bool>(
                        stream: _monitorService.statusStream,
                        initialData: false,
                        builder: (context, snapshot) {
                          final isConnected = snapshot.data ?? false;
                          return Row(
                            children: [
                              Icon(
                                isConnected ? Icons.circle : Icons.circle_outlined,
                                color: isConnected ? Colors.green : Colors.red,
                                size: 12,
                              ),
                              const SizedBox(width: 8),
                              DropdownButton<int>(
                                value: _selectedBaudRate,
                                dropdownColor:
                                    isDarkTheme ? Colors.grey.shade800 : Colors.white,
                                style: TextStyle(
                                  color: isDarkTheme ? Colors.white : Colors.black,
                                  fontSize: 14,
                                ),
                                underline: Container(),
                                items: _baudRates.map((rate) {
                                  return DropdownMenuItem<int>(
                                    value: rate,
                                    child: Text('$rate'),
                                  );
                                }).toList(),
                                onChanged: isConnected ? null : (value) {
                                  if (value != null && value != _selectedBaudRate && mounted) {
                                    setState(() {
                                      _selectedBaudRate = value;
                                    });
                                    _restartMonitor();
                                  }
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        style: TextStyle(
                          fontFamily: 'Courier New',
                          color: isDarkTheme ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter command...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color:
                                  isDarkTheme
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color:
                                  isDarkTheme
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.blue,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          fillColor:
                              isDarkTheme ? Colors.grey.shade800 : Colors.white,
                          filled: true,
                        ),
                        onSubmitted: (_) => _sendCommand(),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    StreamBuilder<bool>(
                      stream: _monitorService.statusStream,
                      initialData: false,
                      builder: (context, snapshot) {
                        return ElevatedButton(
                          onPressed: snapshot.data! ? _sendCommand : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Send'),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
