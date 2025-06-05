import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:get_it/get_it.dart';

class ConsoleLineDisplay {
  final String timestamp;
  final String content;
  final LogLevel level;
  final String? origin;
  final bool isSystemMessage;

  ConsoleLineDisplay(
    this.timestamp,
    this.content, {
    this.level = LogLevel.info,
    this.origin,
    this.isSystemMessage = false,
  });

  Color getColor(bool isDarkTheme) {
    if (origin == 'arduino-cli') {
      if (content.contains('avrdude:')) return const Color(0xFF4CAF50);
      if (content.contains('Writing') || content.contains('Reading')) {
        return const Color(0xFF2196F3);
      }
      if (content.contains('bytes')) return const Color(0xFF9C27B0);
    }

    switch (level) {
      case LogLevel.error:
        return const Color(0xFFF44336);
      case LogLevel.warning:
        return const Color(0xFFFFA726);
      case LogLevel.success:
        return const Color(0xFF4CAF50);
      case LogLevel.info:
        return isDarkTheme ? Colors.lightGreenAccent : Colors.black;
      case LogLevel.verbose:
        return const Color(0xFF757575);
      default:
        return isDarkTheme ? Colors.grey[400]! : Colors.grey[600]!;
    }
  }

  IconData? getIcon() {
    if (origin == 'arduino-cli') {
      if (content.contains('Compiling')) return Icons.build;
      if (content.contains('Uploading') || content.contains('Writing')) {
        return Icons.upload;
      }
      if (content.contains('avrdude:')) return Icons.memory;
      if (content.contains('bytes')) return Icons.data_usage;
    }

    switch (level) {
      case LogLevel.error:
        return Icons.not_interested_rounded;
      case LogLevel.warning:
        return Icons.warning;
      case LogLevel.success:
        return Icons.check_circle;
      case LogLevel.info:
        return Icons.info;
      default:
        return null;
    }
  }
}

class ConsoleTerminalWidget extends StatefulWidget {
  final List<LogEntry> logs;
  final ScrollController scrollController;
  final bool isActiveTab;

  const ConsoleTerminalWidget({
    super.key,
    required this.logs,
    required this.scrollController,
    this.isActiveTab = true,
  });

  @override
  State<ConsoleTerminalWidget> createState() => _ConsoleTerminalWidgetState();
}

class _ConsoleTerminalWidgetState extends State<ConsoleTerminalWidget> {
  final List<ConsoleLineDisplay> _displayLines = [];
  bool _isAutoScrollEnabled = true;
  bool _isListening = false;
  StreamSubscription? _logsSubscription;
  late final LogService _logService;

  @override
  void initState() {
    super.initState();
    _logService = GetIt.instance<LogService>();
    if (widget.isActiveTab) {
      _startListening();
    }
  }

  @override
  void didUpdateWidget(ConsoleTerminalWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logs != oldWidget.logs) {
      _processLogs();
    }
    if (widget.isActiveTab != oldWidget.isActiveTab) {
      if (widget.isActiveTab) {
        _processLogs();
      }
    }
  }

  void _startListening() {
    if (_isListening) return;
    _isListening = true;
  }

  void _stopListening() {
    if (!_isListening) return;
    _isListening = false;
    _logsSubscription?.cancel();
    _logsSubscription = null;
  }

  void _scrollToBottom() {
    if (_isAutoScrollEnabled && widget.scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.scrollController.animateTo(
            widget.scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
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
                color: Colors.black,  // Consistent with SerialMonitorTerminalWidget
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: StreamBuilder<List<LogEntry>>(
                  stream: _logService.logStream.transform(
                    StreamTransformer<LogEntry, List<LogEntry>>.fromHandlers(
                      handleData: (log, sink) {
                        final currentLogs = [...widget.logs, log]; // Dùng widget.logs làm base
                        sink.add(currentLogs);
                      },
                    ),
                  ),
                  builder: (context, snapshot) {
                    final logs = snapshot.data ?? widget.logs;
                    print('DEBUG: StreamBuilder received ${logs.length} logs'); // Debug

                    _displayLines.clear(); // Clear display lines when new data arrives
                    for (var log in logs) {
                      _displayLines.add(ConsoleLineDisplay(
                        log.formattedTimestamp,
                        log.message,
                        level: log.level,
                        origin: log.origin,
                        isSystemMessage: log.origin == 'system',
                      ));
                    }

                    // Auto-scroll if enabled
                    if (_isAutoScrollEnabled) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && widget.scrollController.hasClients) {
                          widget.scrollController.animateTo(
                            widget.scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          );
                        }
                      });
                    }

                    // Display terminal content
                    return _displayLines.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.terminal, size: 48, color: Colors.grey[700]),
                                const SizedBox(height: 16),
                                Text(
                                  'No console output',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            controller: widget.scrollController,
                            child: SizedBox(
                              width: double.infinity,
                              child: SelectableText.rich(
                                TextSpan(
                                  children: _displayLines.map((line) {
                                    final icon = line.getIcon();
                                    return TextSpan(
                                      children: [
                                        // Icon for message type
                                        if (icon != null)
                                          WidgetSpan(
                                            alignment: PlaceholderAlignment.middle,
                                            child: Padding(
                                              padding: const EdgeInsets.only(right: 8),
                                              child: Icon(
                                                icon,
                                                size: 14,
                                                color: line.getColor(isDarkTheme),
                                              ),
                                            ),
                                          ),
                                        // Timestamp
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
                                        // Message content
                                        TextSpan(
                                          text: '${line.content}\n',
                                          style: TextStyle(
                                            color: line.isSystemMessage
                                                ? Colors.yellow
                                                : line.getColor(true), // Always use dark theme colors
                                            fontFamily: 'Courier New',
                                            fontSize: 14.0,
                                            height: 1.5,
                                            fontWeight: _getLineWeight(line),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          );
                  },
                ),
              ),
            ),
          ),

          // Control bar
          Container(
            margin: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
                const SizedBox(width: 8),
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
                        widget.logs.clear(); // Clear the underlying log list
                        _displayLines.clear(); // Clear display lines
                      });
                    },
                    icon: const Icon(Icons.clear_all),
                    tooltip: 'Clear console',
                    color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _processLogs() {
    if (!mounted) return;
    setState(() {
      _displayLines.clear();
      for (var log in widget.logs) {
        _displayLines.add(ConsoleLineDisplay(
          log.formattedTimestamp,
          log.message,
          level: log.level,
          origin: log.origin,
          isSystemMessage: log.origin == 'system',
        ));
      }
    });
    _scrollToBottom();
  }

  FontWeight _getLineWeight(ConsoleLineDisplay line) {
    if (line.level == LogLevel.success || line.level == LogLevel.error) {
      return FontWeight.w600;
    }
    if (line.origin == 'arduino-cli' &&
        (line.content.contains('Sketch uses') ||
         line.content.contains('bytes written') ||
         line.content.contains('Upload complete'))) {
      return FontWeight.w600;
    }
    return FontWeight.normal;
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
}
