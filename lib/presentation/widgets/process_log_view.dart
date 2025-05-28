import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_event.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_state.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';

class ProcessLogView extends StatefulWidget {
  final String processId;
  final int maxLines;
  final bool autoScroll;

  const ProcessLogView({
    super.key,
    required this.processId,
    this.maxLines = 10,
    this.autoScroll = true,
  });

  @override
  State<ProcessLogView> createState() => _ProcessLogViewState();
}

class _ProcessLogViewState extends State<ProcessLogView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Set up filtering for logs related to this process
    context.read<LogBloc>().add(FilterLogEvent(deviceFilter: widget.processId));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (widget.autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LogBloc, LogState>(
      listenWhen: (previous, current) {
        // Listen for changes in the filtered logs which include our process ID
        return previous.filteredLogs != current.filteredLogs;
      },
      listener: (context, state) {
        // Scroll to bottom when log entries change
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      },
      builder: (context, state) {
        // Filter logs for this process ID if needed
        final processLogs = state.filteredLogs
            .where((log) => log.deviceId == widget.processId)
            .toList();

        return Container(
          height: widget.maxLines * 20.0, // Estimate height based on line count
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: processLogs.isEmpty
              ? const Center(
                  child: Text(
                    'No logs available',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: processLogs.length,
                    itemBuilder: (context, index) {
                      final entry = processLogs[index];
                      Color textColor;

                      // Color the log entries based on their level
                      if (entry.message.toLowerCase().contains('error')) {
                        textColor = AppColors.error;
                      } else if (entry.message.toLowerCase().contains('warning')) {
                        textColor = Colors.amber;
                      } else if (entry.message.toLowerCase().contains('success')) {
                        textColor = AppColors.success;
                      } else {
                        textColor = Colors.white;
                      }

                      return Text(
                        entry.message,
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}