import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/domain/blocs/logging_bloc.dart';

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
  final bool isActiveTab;

  const ConsoleTerminalWidget({
    super.key,
    this.isActiveTab = true,
  });

  @override
  State<ConsoleTerminalWidget> createState() => _ConsoleTerminalWidgetState();
}

class _ConsoleTerminalWidgetState extends State<ConsoleTerminalWidget> with AutomaticKeepAliveClientMixin {
  final List<ConsoleLineDisplay> _displayLines = [];
  bool _isAutoScrollEnabled = true;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true; // Keep state when tab is inactive

  void _scrollToBottom() {
    if (_isAutoScrollEnabled && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.position.pixels;
        setState(() {
          _isAutoScrollEnabled = (maxScroll - currentScroll) <= 50;
        });
      }
    });
  }

  @override
  void didUpdateWidget(ConsoleTerminalWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle tab activation
    if (widget.isActiveTab && !oldWidget.isActiveTab) {
      // Tab became active
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isAutoScrollEnabled) {
          _scrollToBottom();
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.maxHeight;
        return SizedBox(
          height: minHeight,
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
                  child: Scrollbar(
                    thumbVisibility: true,
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: BlocBuilder<LoggingBloc, LoggingState>(
                          buildWhen: (previous, current) {
                            return previous.logs != current.logs ||
                                previous.filter != current.filter;
                          },
                          builder: (context, state) {
                            final logsToDisplay =
                                state.filter != null && state.filter!.isNotEmpty
                                    ? state.logs
                                        .where(
                                          (log) => log.message.toLowerCase().contains(
                                            state.filter!.toLowerCase(),
                                          ),
                                        )
                                        .toList()
                                    : state.logs;

                            _displayLines.clear();
                            for (var log in logsToDisplay) {
                              _displayLines.add(
                                ConsoleLineDisplay(
                                  log.formattedTimestamp,
                                  log.message,
                                  level: log.level,
                                  origin: log.origin,
                                  isSystemMessage: log.origin == 'system',
                                ),
                              );
                            }

                            if (_isAutoScrollEnabled) {
                              _scrollToBottom();
                            }

                            return _displayLines.isEmpty
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.terminal,
                                        size: 48,
                                        color: Colors.grey[700],
                                      ),
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
                                : SelectableText.rich(
                                    TextSpan(
                                      children:
                                          _displayLines.map((line) {
                                            final icon = line.getIcon();
                                            return TextSpan(
                                              children: [
                                                if (icon != null)
                                                  WidgetSpan(
                                                    alignment:
                                                        PlaceholderAlignment.middle,
                                                    child: Padding(
                                                      padding: const EdgeInsets.only(
                                                        right: 8,
                                                      ),
                                                      child: Icon(
                                                        icon,
                                                        size: 14,
                                                        color: line.getColor(
                                                          isDarkTheme,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                TextSpan(
                                                  text: '[${line.timestamp}] ',
                                                  style: TextStyle(
                                                    color:
                                                        line.isSystemMessage
                                                            ? Colors.yellow.withValues(alpha: 0.8)
                                                            : Colors.grey.withValues(alpha: 0.7),
                                                    fontFamily: 'Courier New',
                                                    fontSize: 12.0,
                                                    height: 1.5,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: '${line.content}\n',
                                                  style: TextStyle(
                                                    color:
                                                        line.isSystemMessage
                                                            ? Colors.yellow
                                                            : line.getColor(true),
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
                                  );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
                              isDarkTheme
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () {
                          setState(() {
                            _isAutoScrollEnabled = !_isAutoScrollEnabled;
                            if (_isAutoScrollEnabled) {
                              _scrollToBottom();
                            }
                          });
                        },
                        icon: Icon(
                          _isAutoScrollEnabled
                              ? Icons.vertical_align_bottom
                              : Icons.vertical_align_center,
                          color: _isAutoScrollEnabled ? Colors.blue : Colors.grey,
                        ),
                        tooltip:
                            _isAutoScrollEnabled
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
                              isDarkTheme
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () {
                          context.read<LoggingBloc>().add(ClearLogsEvent());
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
      },
    );
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
}
