import 'dart:async';
import 'package:flutter/material.dart';
import 'package:esp_firmware_tool/data/models/log_entry.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';

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
        return isDarkTheme ? Colors.white : Colors.black;
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
        return Icons.error_outline;
      case LogLevel.warning:
        return Icons.warning_amber;
      case LogLevel.success:
        return Icons.check_circle_outline;
      case LogLevel.info:
        return Icons.info_outline;
      default:
        return null;
    }
  }
}

class ConsoleTerminalWidget extends StatefulWidget {
  final List<LogEntry> logs;
  final ScrollController scrollController;

  const ConsoleTerminalWidget({
    super.key,
    required this.logs,
    required this.scrollController,
  });

  @override
  State<ConsoleTerminalWidget> createState() => _ConsoleTerminalWidgetState();
}

class _ConsoleTerminalWidgetState extends State<ConsoleTerminalWidget> {
  final List<ConsoleLineDisplay> _displayLines = [];
  bool _isAutoScrollEnabled = true;

  @override
  void initState() {
    super.initState();
    _processLogs();
  }

  @override
  void didUpdateWidget(ConsoleTerminalWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logs != oldWidget.logs) {
      _processLogs();
    }
  }

  void _processLogs() {
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
                color: isDarkTheme ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _displayLines.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.terminal,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No output to display',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        controller: widget.scrollController,
                        child: SelectableText.rich(
                          TextSpan(
                            children: _displayLines.map((line) {
                              final icon = line.getIcon();
                              return TextSpan(
                                children: [
                                  // Icon if available
                                  if (icon != null)
                                    WidgetSpan(
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Icon(
                                          icon,
                                          size: 16,
                                          color: line.getColor(isDarkTheme),
                                        ),
                                      ),
                                    ),
                                  // Timestamp
                                  TextSpan(
                                    text: '[${line.timestamp}] ',
                                    style: TextStyle(
                                      color: isDarkTheme
                                          ? Colors.grey[500]
                                          : Colors.grey[600],
                                      fontFamily: 'Consolas',
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                  // Content
                                  TextSpan(
                                    text: '${line.content}\n',
                                    style: TextStyle(
                                      color: line.getColor(isDarkTheme),
                                      fontFamily: 'Consolas',
                                      fontSize: 13,
                                      height: 1.5,
                                      fontWeight: line.level == LogLevel.success ||
                                              line.level == LogLevel.error ||
                                              (line.origin == 'arduino-cli' &&
                                                  (line.content
                                                          .contains('Sketch uses') ||
                                                      line.content.contains(
                                                          'bytes written')))
                                          ? FontWeight.bold
                                          : FontWeight.normal,
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
                      color:
                          isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _isAutoScrollEnabled = !_isAutoScrollEnabled;
                      });
                    },
                    icon: Icon(
                      _isAutoScrollEnabled
                          ? Icons.vertical_align_bottom
                          : Icons.vertical_align_center,
                      color: _isAutoScrollEnabled ? Colors.blue : Colors.grey,
                    ),
                    tooltip: _isAutoScrollEnabled
                        ? 'Auto-scroll enabled'
                        : 'Auto-scroll disabled',
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: isDarkTheme ? Colors.grey.shade800 : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _displayLines.clear();
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
}
