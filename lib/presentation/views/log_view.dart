import 'package:esp_firmware_tool/data/models/log_entry.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_event.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LogView extends StatefulWidget {
  final String deviceId;

  const LogView({super.key, required this.deviceId});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  bool _autoScroll = true;
  final FocusNode _inputFocusNode = FocusNode();

  // Controller for firmware version dropdown
  String? _selectedFirmwareVersion;
  String? _selectedDeviceType;
  String? _selectedBatch;
  String? _scannedSerial;

  @override
  void initState() {
    super.initState();
    // Initial fetch of firmware versions, device types and batches would happen here
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Firmware Deployment Tool'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.fullscreen),
              onPressed: () => _toggleFullScreen(context),
              tooltip: 'Toggle Full Screen Mode',
            ),
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () {
                context.read<LogBloc>().add(ClearLogsEvent());
              },
              tooltip: 'Clear logs',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildWorkflowControls(),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildLogPanel(),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 1,
                  child: _buildDevicePanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowControls() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(bottom: BorderSide(color: Colors.grey[400]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'Device Type',
                  value: _selectedDeviceType,
                  items: const ['ESP32', 'ESP8266', 'Arduino Uno'], // You'd fetch these from API
                  onChanged: (value) {
                    setState(() {
                      _selectedDeviceType = value;
                      // Reset firmware version when device type changes
                      _selectedFirmwareVersion = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdown(
                  label: 'Firmware Version',
                  value: _selectedFirmwareVersion,
                  items: const ['v1.0.0', 'v1.1.0', 'v2.0.0'], // You'd fetch these from API based on selected device type
                  onChanged: (value) {
                    setState(() {
                      _selectedFirmwareVersion = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdown(
                  label: 'Product Batch',
                  value: _selectedBatch,
                  items: const ['Batch-001', 'Batch-002', 'Batch-003'], // You'd fetch these from API
                  onChanged: (value) {
                    setState(() {
                      _selectedBatch = value;
                      // Fetch device serials in this batch from API
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan Device QR'),
                onPressed: () {
                  // Simulate QR scanning - in real app, this would open scanner
                  setState(() {
                    _scannedSerial = 'SN-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
                  });
                  // Show snackbar notification
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Scanned device: $_scannedSerial'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.flash_on),
                label: const Text('Flash Firmware'),
                onPressed: _canFlashFirmware()
                    ? () {
                        // This would initiate the firmware flashing process
                        context.read<LogBloc>().add(
                              InitiateFlashEvent(
                                deviceId: widget.deviceId,
                                firmwareVersion: _selectedFirmwareVersion!,
                                deviceSerial: _scannedSerial!,
                              ),
                            );
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          value: value,
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ))
              .toList(),
          onChanged: onChanged,
          isExpanded: true,
        ),
      ],
    );
  }

  bool _canFlashFirmware() {
    return _selectedDeviceType != null &&
        _selectedFirmwareVersion != null &&
        _scannedSerial != null;
  }

  Widget _buildLogPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          _buildLogHeader(),
          Expanded(
            child: _buildLogList(),
          ),
          _buildLogInput(),
        ],
      ),
    );
  }

  Widget _buildLogHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey)),
        color: Colors.black,
      ),
      child: Row(
        children: [
          const Text(
            'Arduino CLI Output',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center,
              color: Colors.white70,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
              });
            },
            tooltip: _autoScroll ? 'Auto-scroll enabled' : 'Auto-scroll disabled',
          ),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    return BlocConsumer<LogBloc, LogState>(
      listener: (context, state) {
        // Auto-scroll when new logs arrive
        if (_autoScroll && state.logs.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 50), () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
        }
      },
      builder: (context, state) {
        if (state.filteredLogs.isEmpty) {
          return const Center(
            child: Text(
              'No logs to display',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          itemCount: state.filteredLogs.length,
          itemBuilder: (context, index) {
            final log = state.filteredLogs[index]; // Chronological order
            return _buildLogItemModern(log);
          },
        );
      },
    );
  }

  Widget _buildLogItemModern(LogEntry log) {
    // Special handling for input request logs
    if (log is SerialInputLogEntry) {
      return _buildSerialInputRequest(log);
    }

    // Special handling for batch device selection
    if (log is BatchDeviceSelectionLogEntry) {
      return _buildBatchDeviceSelection(log);
    }

    // Special handling for firmware selection
    if (log is FirmwareSelectionLogEntry) {
      return _buildFirmwareSelection(log);
    }

    // Normal log entry
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              _formatTimeOnly(log.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: _getLogColor(log.level).withOpacity(0.7),
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (log.origin == 'user-input')
            Text(
              '> ',
              style: TextStyle(
                color: Colors.green[300],
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          Expanded(
            child: Text(
              log.message,
              style: TextStyle(
                color: _getLogColor(log.level),
                fontFamily: 'monospace',
                fontWeight: log.level == LogLevel.error || log.level == LogLevel.warning
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSerialInputRequest(SerialInputLogEntry log) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.shade800),
        borderRadius: BorderRadius.circular(4),
        color: Colors.green.shade900.withOpacity(0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            log.message,
            style: TextStyle(
              color: Colors.green[300],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.green[700]!),
              ),
              fillColor: Colors.black45,
              filled: true,
              hintText: 'Type your command...',
              hintStyle: TextStyle(color: Colors.green[300]!.withOpacity(0.5)),
              prefixIcon: Icon(Icons.keyboard, color: Colors.green[300], size: 18),
              suffixIcon: IconButton(
                icon: Icon(Icons.send, color: Colors.green[300], size: 18),
                onPressed: () {
                  // Send the text to serial monitor
                  // Implementation depends on your application structure
                  final text = _inputController.text;
                  if (text.isNotEmpty) {
                    log.onSerialInput(text);
                    _inputController.clear();
                  }
                },
              ),
            ),
            controller: _inputController,
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                log.onSerialInput(value);
                _inputController.clear();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBatchDeviceSelection(BatchDeviceSelectionLogEntry log) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade800),
        borderRadius: BorderRadius.circular(4),
        color: Colors.blue.shade900.withOpacity(0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            log.message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Available devices in batch:',
            style: TextStyle(
              color: Colors.blue[300],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: log.availableSerials.map((serial) {
              final isSelected = serial == log.selectedSerial;
              return FilterChip(
                label: Text(serial),
                selected: isSelected,
                checkmarkColor: Colors.white,
                selectedColor: Colors.blue[700],
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.blue[300],
                ),
                backgroundColor: Colors.blue[900]?.withOpacity(0.3),
                onSelected: (_) => log.onSerialSelect(serial),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFirmwareSelection(FirmwareSelectionLogEntry log) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.purple.shade800),
        borderRadius: BorderRadius.circular(4),
        color: Colors.purple.shade900.withOpacity(0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            log.message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Available firmware templates:',
            style: TextStyle(
              color: Colors.purple[300],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...log.availableTemplates.map((template) {
            final isSelected = template.id == log.selectedTemplateId;
            return ListTile(
              title: Text(
                '${template.name} (v${template.version})',
                style: TextStyle(
                  color: isSelected ? Colors.purple[100] : Colors.purple[300],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                template.description,
                style: TextStyle(color: Colors.purple[400]?.withOpacity(0.7)),
              ),
              tileColor: isSelected ? Colors.purple[800]?.withOpacity(0.3) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: isSelected
                    ? BorderSide(color: Colors.purple[500]!)
                    : BorderSide.none,
              ),
              onTap: () => log.onTemplateSelect(template.id),
              trailing: isSelected
                  ? Icon(Icons.check_circle, color: Colors.purple[300])
                  : null,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLogInput() {
    return BlocBuilder<LogBloc, LogState>(
      buildWhen: (previous, current) =>
          current.activeInputRequest != previous.activeInputRequest,
      builder: (context, state) {
        // Only show input when we have an active input request
        if (state.activeInputRequest == null) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey)),
            color: Colors.black,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  focusNode: _inputFocusNode,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    fillColor: Colors.grey[900],
                    filled: true,
                    hintText: 'Type a command...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty && state.activeInputRequest != null) {
                      if (state.activeInputRequest is SerialInputLogEntry) {
                        (state.activeInputRequest as SerialInputLogEntry)
                            .onSerialInput(value);
                      }
                      _inputController.clear();
                      _inputFocusNode.requestFocus();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final value = _inputController.text;
                  if (value.isNotEmpty && state.activeInputRequest != null) {
                    if (state.activeInputRequest is SerialInputLogEntry) {
                      (state.activeInputRequest as SerialInputLogEntry)
                          .onSerialInput(value);
                    }
                    _inputController.clear();
                    _inputFocusNode.requestFocus();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('Send'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDevicePanel() {
    return BlocBuilder<LogBloc, LogState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  const Text(
                    'Devices in Batch',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    state.batchDevices.isEmpty
                        ? 'No batch selected'
                        : '${state.batchDevices.where((d) => d.isProcessed).length}/${state.batchDevices.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildDeviceList(state),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeviceList(LogState state) {
    if (state.batchDevices.isEmpty) {
      return const Center(
        child: Text(
          'Select a batch to view devices',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: state.batchDevices.length,
      itemBuilder: (context, index) {
        final device = state.batchDevices[index];
        return ListTile(
          title: Text(device.serialNumber),
          subtitle: Text(
            device.isProcessed ? 'Programmed' : 'Waiting',
            style: TextStyle(
              color: device.isProcessed ? Colors.green : Colors.orange,
            ),
          ),
          leading: Icon(
            device.isProcessed ? Icons.check_circle : Icons.pending,
            color: device.isProcessed ? Colors.green : Colors.orange,
          ),
          trailing: device.isProcessed
              ? Text(
                  device.flashTime != null
                      ? '${device.flashTime!.hour}:${device.flashTime!.minute}'
                      : '',
                  style: const TextStyle(color: Colors.grey),
                )
              : null,
        );
      },
    );
  }

  Color _getLogColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Colors.white;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red[300]!;
      case LogLevel.success:
        return Colors.green[300]!;
      case LogLevel.verbose:
        return Colors.grey[400]!;
      case LogLevel.debug:
        return Colors.cyan[300]!;
      case LogLevel.input:
        return Colors.green[300]!;
      case LogLevel.system:
        return Colors.purple[300]!;
    }
  }

  String _formatTimeOnly(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  void _toggleFullScreen(BuildContext context) {
    // This would use a fullscreen manager implementation
    // For now, we'll just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Full screen mode toggled'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}