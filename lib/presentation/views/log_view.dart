import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';
import 'package:esp_firmware_tool/presentation/widgets/rounded_button.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_event.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_state.dart';

class LogView extends StatefulWidget {
  final String? deviceId;
  const LogView({super.key, this.deviceId});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.deviceId != null) {
      context.read<LogBloc>().add(StartLogging(widget.deviceId!));
    }
  }

  @override
  void dispose() {
    if (widget.deviceId != null) {
      context.read<LogBloc>().add(StopLogging());
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceId != null ? 'Device Logs' : 'System Logs'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear logs',
            onPressed: () => context.read<LogBloc>().add(ClearLogs()),
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Export logs',
            onPressed: () {
              // TODO: Implement log export
            },
          ),
        ],
      ),
      body: BlocBuilder<LogBloc, LogState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                    size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    state.error!,
                    style: TextStyle(color: AppColors.error),
                  ),
                ],
              ),
            );
          }

          return Column(
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
                  child: state.logs.isEmpty
                      ? const Center(
                          child: Text(
                            'No logs available',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: state.logs.length,
                          itemBuilder: (context, index) {
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) => _scrollToBottom());
                            return LogEntry(log: state.logs[index]);
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class LogEntry extends StatelessWidget {
  final String log;

  const LogEntry({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        log,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      ),
    );
  }
}