import 'package:flutter/material.dart';
import 'package:esp_firmware_tool/data/models/log_entry.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';

class ConsoleLogView extends StatelessWidget {
  final List<LogEntry> logs;
  final ScrollController scrollController;

  const ConsoleLogView({
    super.key,
    required this.logs,
    required this.scrollController,
  });

  Color _getLogColor(LogLevel level, LogEntry log) {
    // Special coloring for Arduino CLI output
    if (log.origin == 'arduino-cli') {
      if (log.message.contains('avrdude:')) return const Color(0xFF4CAF50); // Green for avrdude
      if (log.message.contains('Writing') || log.message.contains('Reading')) {
        return const Color(0xFF2196F3); // Blue for progress
      }
      if (log.message.contains('bytes')) return const Color(0xFF9C27B0); // Purple for memory info
    }

    // Default coloring based on level
    switch (level) {
      case LogLevel.info:
        return AppColors.info;
      case LogLevel.warning:
        return const Color(0xFFFFA726); // Orange for warnings
      case LogLevel.error:
        return const Color(0xFFF44336); // Bright red for errors
      case LogLevel.success:
        return const Color(0xFF4CAF50); // Green for success
      case LogLevel.verbose:
        return const Color(0xFF757575); // Gray for verbose
      case LogLevel.input:
        return AppColors.connected;
      case LogLevel.system:
        return AppColors.idle;
      default:
        return AppColors.text;
    }
  }

  TextStyle _getLogStyle(LogEntry log) {
    final baseStyle = TextStyle(
      fontFamily: 'Consolas',
      fontSize: 13,
      height: 1.3,
      color: _getLogColor(log.level, log),
    );

    // Bold important messages
    if (log.level == LogLevel.success ||
        log.level == LogLevel.error ||
        (log.origin == 'arduino-cli' &&
         (log.message.contains('Sketch uses') ||
          log.message.contains('bytes written')))) {
      return baseStyle.copyWith(fontWeight: FontWeight.bold);
    }

    return baseStyle;
  }

  Widget _buildLogEntry(LogEntry log) {
    final timestamp = '[${log.formattedTimestamp}]';
    final icon = _getLogIcon(log);
    final message = log.message.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: _getLogColor(log.level, log)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (!message.startsWith('[STDOUT]') && !message.startsWith('[STDERR]')) ...[
                    TextSpan(
                      text: '$timestamp ',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontFamily: 'Consolas',
                        fontSize: 12,
                      ),
                    ),
                  ],
                  TextSpan(
                    text: message,
                    style: _getLogStyle(log),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData? _getLogIcon(LogEntry log) {
    if (log.origin == 'arduino-cli') {
      if (log.message.contains('Compiling')) return Icons.build;
      if (log.message.contains('Uploading') || log.message.contains('Writing')) {
        return Icons.upload;
      }
      if (log.message.contains('avrdude:')) return Icons.memory;
      if (log.message.contains('bytes')) return Icons.data_usage;
    }

    switch (log.level) {
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: logs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.terminal, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No logs to display',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              controller: scrollController,
              itemCount: logs.length,
              itemBuilder: (context, index) => _buildLogEntry(logs[index]),
            ),
    );
  }
}

