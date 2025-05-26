import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../widgets/rounded_button.dart';

class LogView extends StatefulWidget {
  const LogView({super.key});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  final List<LogEntry> _logs = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Sample logs for UI preview
    _logs.addAll([
      LogEntry(message: 'Application started', type: LogType.info, timestamp: DateTime.now()),
      LogEntry(message: 'Connecting to device...', type: LogType.info, timestamp: DateTime.now().add(const Duration(seconds: 1))),
      LogEntry(message: 'Device connected: ESP32-123456', type: LogType.success, timestamp: DateTime.now().add(const Duration(seconds: 2))),
      LogEntry(message: 'Reading firmware version...', type: LogType.info, timestamp: DateTime.now().add(const Duration(seconds: 3))),
      LogEntry(message: 'Firmware version: v1.2.3', type: LogType.info, timestamp: DateTime.now().add(const Duration(seconds: 4))),
    ]);

    // In real app, subscribe to log stream from a service
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Console Log'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Export logs',
            onPressed: () {
              // TODO: Implement log export functionality
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        'No logs available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '[${log.formattedTime}] ',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                  ),
                                ),
                                TextSpan(
                                  text: '${log.typeLabel}: ',
                                  style: TextStyle(
                                    color: log.typeColor,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                TextSpan(
                                  text: log.message,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                RoundedButton(
                  label: 'Clear Logs',
                  color: AppColors.error,
                  onPressed: _clearLogs,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum LogType { info, success, warning, error }

class LogEntry {
  final String message;
  final LogType type;
  final DateTime timestamp;

  LogEntry({
    required this.message,
    required this.type,
    required this.timestamp,
  });

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  String get typeLabel {
    switch (type) {
      case LogType.info:
        return 'INFO';
      case LogType.success:
        return 'SUCCESS';
      case LogType.warning:
        return 'WARNING';
      case LogType.error:
        return 'ERROR';
    }
  }

  Color get typeColor {
    switch (type) {
      case LogType.info:
        return Colors.blue;
      case LogType.success:
        return Colors.green;
      case LogType.warning:
        return Colors.orange;
      case LogType.error:
        return Colors.red;
    }
  }
}