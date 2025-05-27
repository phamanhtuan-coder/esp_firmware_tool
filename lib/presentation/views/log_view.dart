import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_event.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/log_entry.dart';

class LogView extends StatelessWidget {
  final String deviceId;

  const LogView({Key? key, required this.deviceId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              context.read<LogBloc>().add(ClearLogsEvent());
            },
            tooltip: 'Clear all logs',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(context),
          Expanded(
            child: _buildLogList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return BlocBuilder<LogBloc, LogState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search logs...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        context.read<LogBloc>().add(FilterLogEvent(textFilter: value));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () => _showFilterOptions(context),
                    tooltip: 'Filter options',
                  ),
                ],
              ),
              if (state.deviceFilter.isNotEmpty || state.stepFilter != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      if (state.deviceFilter.isNotEmpty)
                        _buildFilterChip(
                          context,
                          'Device: ${state.deviceFilter}',
                          () {
                            context.read<LogBloc>().add(
                                const FilterLogEvent(deviceFilter: ''));
                          },
                        ),
                      if (state.stepFilter != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: _buildFilterChip(
                            context,
                            'Step: ${_stepToString(state.stepFilter!)}',
                            () {
                              context.read<LogBloc>().add(
                                  FilterLogEvent(
                                      stepFilter: null,
                                      clearFilters: false));
                            },
                          ),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          context.read<LogBloc>().add(
                              const FilterLogEvent(clearFilters: true));
                        },
                        child: const Text('Clear All Filters'),
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

  Widget _buildFilterChip(BuildContext context, String label, VoidCallback onRemove) {
    return Chip(
      label: Text(label),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onRemove,
    );
  }

  Widget _buildLogList() {
    return BlocBuilder<LogBloc, LogState>(
      builder: (context, state) {
        if (state.filteredLogs.isEmpty) {
          return const Center(
            child: Text('No logs to display'),
          );
        }

        return ListView.builder(
          itemCount: state.filteredLogs.length,
          itemBuilder: (context, index) {
            final log = state.filteredLogs[state.filteredLogs.length - 1 - index]; // Reverse chronological
            return _buildLogItem(log);
          },
        );
      },
    );
  }

  Widget _buildLogItem(LogEntry log) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: _buildLogLevelIndicator(log.level),
        title: Text(log.message),
        subtitle: Row(
          children: [
            Text(
              _formatTimestamp(log.timestamp),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getStepColor(log.step),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _stepToString(log.step),
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueGrey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Device: ${log.deviceId}',
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogLevelIndicator(LogLevel level) {
    IconData icon;
    Color color;

    switch (level) {
      case LogLevel.info:
        icon = Icons.info_outline;
        color = Colors.blue;
        break;
      case LogLevel.warning:
        icon = Icons.warning_amber_outlined;
        color = Colors.orange;
        break;
      case LogLevel.error:
        icon = Icons.error_outline;
        color = Colors.red;
        break;
      case LogLevel.success:
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha(25),
      ),
      child: Icon(icon, color: color),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  Color _getStepColor(ProcessStep step) {
    switch (step) {
      case ProcessStep.usbCheck:
        return Colors.blue;
      case ProcessStep.compile:
        return Colors.purple;
      case ProcessStep.flash:
        return Colors.teal;
      case ProcessStep.error:
        return Colors.red;
      case ProcessStep.other:
        return Colors.grey;
    }
  }

  String _stepToString(ProcessStep step) {
    switch (step) {
      case ProcessStep.usbCheck:
        return 'USB Check';
      case ProcessStep.compile:
        return 'Compile';
      case ProcessStep.flash:
        return 'Flash';
      case ProcessStep.error:
        return 'Error';
      case ProcessStep.other:
        return 'Other';
    }
  }

  void _showFilterOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Logs'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter by device:'),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Enter device ID',
                border: OutlineInputBorder(),
              ),
              onChanged: (deviceId) {
                context.read<LogBloc>().add(FilterLogEvent(deviceFilter: deviceId));
              },
            ),
            const SizedBox(height: 16),
            const Text('Filter by process step:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ProcessStep.values.map((step) {
                return FilterChip(
                  label: Text(_stepToString(step)),
                  selected: context.read<LogBloc>().state.stepFilter == step,
                  onSelected: (selected) {
                    if (selected) {
                      context.read<LogBloc>().add(FilterLogEvent(stepFilter: step));
                    } else {
                      context.read<LogBloc>().add(const FilterLogEvent(stepFilter: null));
                    }
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<LogBloc>().add(const FilterLogEvent(clearFilters: true));
              Navigator.of(context).pop();
            },
            child: const Text('CLEAR FILTERS'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}