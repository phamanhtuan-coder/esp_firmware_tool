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
  bool _isAutoScrollEnabled = true;
  final ScrollController _scrollController = ScrollController();
  static const maxLines = 1000; // Giới hạn số dòng để tránh memory leak

  @override
  bool get wantKeepAlive => true;

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
  void didUpdateWidget(ConsoleTerminalWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActiveTab && !oldWidget.isActiveTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isAutoScrollEnabled && mounted) {
          _scrollToBottom();
        }
      });
    }
  }

  TextStyle _getLogStyle(ConsoleLineDisplay line, bool isDarkTheme) {
    final baseStyle = TextStyle(
      fontFamily: 'Courier New',
      fontSize: 14.0,
      height: 1.5,
      color: line.getColor(isDarkTheme),
    );

    if (line.level == LogLevel.error || line.level == LogLevel.success) {
      return baseStyle.copyWith(fontWeight: FontWeight.w600);
    }

    if (line.origin == 'arduino-cli') {
      if (line.content.contains('Sketch uses') ||
          line.content.contains('bytes written') ||
          line.content.contains('Upload complete')) {
        return baseStyle.copyWith(fontWeight: FontWeight.w600);
      }
    }

    return baseStyle;
  }

  Widget _buildLogLine(ConsoleLineDisplay line, bool isDarkTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (line.getIcon() != null)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Icon(
                line.getIcon(),
                size: 14,
                color: line.getColor(isDarkTheme),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '[${line.timestamp}] ',
                        style: TextStyle(
                          color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                          fontFamily: 'Courier New',
                          fontSize: 12.0,
                        ),
                      ),
                      TextSpan(
                        text: line.content,
                        style: _getLogStyle(line, isDarkTheme),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<LoggingBloc, LoggingState>(
      listenWhen: (previous, current) =>
        previous.logs.length != current.logs.length ||
        previous.filter != current.filter,
      listener: (context, state) {
        if (_isAutoScrollEnabled && mounted) {
          _scrollToBottom();
        }

        // Trim logs if exceeding maxLines
        if (state.logs.length > maxLines) {
          context.read<LoggingBloc>().add(
            TrimLogsEvent(maxLines),
          );
        }
      },
      buildWhen: (previous, current) =>
        previous.logs != current.logs ||
        previous.filter != current.filter,
      builder: (context, state) {
        final filteredLogs = state.filter != null && state.filter!.isNotEmpty
          ? state.logs.where(
              (log) => log.message.toLowerCase().contains(
                state.filter!.toLowerCase(),
              ),
            ).toList()
          : state.logs;

        return Column(
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
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8.0),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      final line = ConsoleLineDisplay(
                        log.formattedTimestamp,
                        log.message,
                        level: log.level,
                        origin: log.origin,
                        isSystemMessage: log.origin == 'system',
                      );
                      return _buildLogLine(line, isDarkTheme);
                    },
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
                        color: isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade300,
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
                        color: isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade300,
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
        );
      },
    );
  }
}

