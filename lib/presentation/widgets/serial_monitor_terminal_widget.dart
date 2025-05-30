import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:get_it/get_it.dart';
import '../../data/services/serial_monitor_service.dart';

// Đối tượng để lưu trữ dữ liệu hiển thị
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

  const SerialMonitorTerminalWidget({
    Key? key,
    this.initialPort,
    this.initialBaudRate = 115200,
    this.autoStart = false,
  }) : super(key: key);

  @override
  State<SerialMonitorTerminalWidget> createState() => _SerialMonitorTerminalWidgetState();
}

class _SerialMonitorTerminalWidgetState extends State<SerialMonitorTerminalWidget> {
  final SerialMonitorService _monitorService = GetIt.instance<SerialMonitorService>();
  final List<LineDisplay> _lines = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final Ansi _ansi;
  bool _isAutoScrollEnabled = true;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _ansi = Ansi(Ansi.terminalSupportsAnsi);

    // Thêm welcome message
    final timestamp = DateTime.now().toString().split('.').first;
    _lines.add(LineDisplay(timestamp, 'Welcome to Serial Monitor', isSystemMessage: true));
    _lines.add(LineDisplay(timestamp, 'Select COM port and baud rate to start monitoring', isSystemMessage: true));

    // Cancel any existing subscription
    _subscription?.cancel();

    // Listen to the broadcast stream
    _subscription = _monitorService.outputStream.listen(
      (data) {
        if (mounted) {
          _addLine(data);
        }
      },
      onError: (error) {
        if (mounted) {
          _addLine('Error: $error', isSystemMessage: true);
        }
      },
    );

    // Start monitor if port is available
    _initializeMonitor();
  }

  void _initializeMonitor() {
    if (widget.initialPort != null && widget.initialPort!.isNotEmpty && widget.initialBaudRate > 0) {
      // Add slight delay to ensure port is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _monitorService.stopMonitor(); // Stop any existing monitor
          _monitorService.startMonitor(widget.initialPort!, widget.initialBaudRate);
          _addLine('Starting monitor on ${widget.initialPort} at ${widget.initialBaudRate} baud...', isSystemMessage: true);
        }
      });
    }
  }

  @override
  void didUpdateWidget(SerialMonitorTerminalWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Restart monitor if port or baud rate changes
    if (oldWidget.initialPort != widget.initialPort ||
        oldWidget.initialBaudRate != widget.initialBaudRate) {
      _initializeMonitor();
    }
  }

  void _addLine(String line, {bool isSystemMessage = false}) {
    if (!mounted) return;

    setState(() {
      final timestamp = DateTime.now().toString().split('.').first;
      final processedLine = _processAnsiCodes(line);

      // Thêm dòng mới với timestamp và nội dung
      _lines.add(LineDisplay(timestamp, processedLine, isSystemMessage: isSystemMessage));

      // Giữ kích thước buffer trong giới hạn
      while (_lines.length > 1000) {
        _lines.removeAt(0);
      }
    });

    // Auto scroll to bottom if enabled
    if (_isAutoScrollEnabled) {
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

  String _processAnsiCodes(String text) {
    // Simple ANSI code removal implementation
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
    if (command.isNotEmpty) {
      _monitorService.sendCommand(command);
      _inputController.clear();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _monitorService.stopMonitor(); // Make sure to stop monitor when disposing
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Terminal output area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: SizedBox(
                    width: double.infinity,
                    child: SelectableText.rich(
                      TextSpan(
                        children: _lines.map((line) {
                          return TextSpan(
                            children: [
                              // Timestamp with slight opacity
                              TextSpan(
                                text: '[${line.timestamp}] ',
                                style: TextStyle(
                                  color: line.isSystemMessage ? Colors.yellow.withOpacity(0.8) : Colors.grey.withOpacity(0.7),
                                  fontFamily: 'Courier New',
                                  fontSize: 12.0,
                                  height: 1.5,
                                ),
                              ),
                              // Actual content
                              TextSpan(
                                text: '${line.content}\n',
                                style: TextStyle(
                                  color: line.isSystemMessage ? Colors.yellow : Colors.lightGreenAccent,
                                  fontFamily: 'Courier New',
                                  fontSize: 14.0,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Command input area
          Container(
            margin: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
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
                          color: isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      fillColor: isDarkTheme ? Colors.grey.shade800 : Colors.white,
                      filled: true,
                    ),
                    onSubmitted: (_) => _sendCommand(),
                  ),
                ),
                const SizedBox(width: 8.0),
                Container(
                  decoration: BoxDecoration(
                    color: isDarkTheme ? Colors.grey.shade800 : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _isAutoScrollEnabled = !_isAutoScrollEnabled;
                      });
                    },
                    icon: Icon(
                      _isAutoScrollEnabled ? Icons.vertical_align_bottom : Icons.vertical_align_center,
                      color: _isAutoScrollEnabled ? Colors.blue : Colors.grey,
                    ),
                    tooltip: _isAutoScrollEnabled ? 'Auto-scroll enabled' : 'Auto-scroll disabled',
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: _sendCommand,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}