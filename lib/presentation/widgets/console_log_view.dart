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

  Color _getLogColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return AppColors.info;
      case LogLevel.warning:
        return AppColors.warning;
      case LogLevel.error:
        return AppColors.error;
      case LogLevel.success:
        return AppColors.success;
      case LogLevel.input:
        return AppColors.connected;
      case LogLevel.system:
        return AppColors.idle;
      default:
        return AppColors.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: logs.isEmpty
          ? const Center(child: Text('No logs to display', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        controller: scrollController,
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          return Text(
            '[${log.timestamp.toIso8601String()}] ${log.message}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: _getLogColor(log.level),
            ),
          );
        },
      ),
    );
  }
}