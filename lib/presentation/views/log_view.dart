import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/data/models/log_entry.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';
import 'package:esp_firmware_tool/utils/app_config.dart';
import 'package:esp_firmware_tool/presentation/widgets/rounded_button.dart';
import 'package:esp_firmware_tool/presentation/widgets/status_text.dart';

class LogView extends StatefulWidget {
  const LogView({super.key});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _autoScroll = true;
  bool _isDarkTheme = false;
  String? _selectedFirmwareVersion;
  String? _selectedDeviceType;
  String? _selectedPort;

  @override
  void initState() {
    super.initState();
    context.read<LogBloc>().add(FilterLogEvent(deviceFilter: ''));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _serialController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkTheme ? Colors.grey[900] : AppColors.background,
      appBar: AppBar(
        backgroundColor: _isDarkTheme ? Colors.grey[850] : AppColors.primary,
        title: const Text('Firmware Deployment Tool', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(_isDarkTheme ? Icons.light_mode : Icons.dark_mode, color: Colors.white),
            onPressed: () => setState(() => _isDarkTheme = !_isDarkTheme),
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all, color: Colors.white),
            onPressed: () => context.read<LogBloc>().add(ClearLogsEvent()),
            tooltip: 'Clear Logs',
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen, color: Colors.white),
            onPressed: () => _toggleFullScreen(context),
            tooltip: 'Toggle Full Screen',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildControlPanel(),
          Expanded(child: _buildLogPanel()),
          _buildSerialInput(),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(AppConfig.defaultPadding),
      decoration: BoxDecoration(
        color: _isDarkTheme ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      margin: const EdgeInsets.all(AppConfig.defaultPadding),
      child: BlocBuilder<LogBloc, LogState>(
        builder: (context, state) {
          final statusColor = state.isFlashing ? AppColors.flashing : state.error != null ? AppColors.error : AppColors.done;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: 'Device Type',
                      value: _selectedDeviceType,
                      items: const ['ESP32', 'ESP8266', 'Arduino Uno'],
                      onChanged: (value) => setState(() {
                        _selectedDeviceType = value;
                        _selectedFirmwareVersion = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: AppConfig.defaultPadding),
                  Expanded(
                    child: _buildDropdown(
                      label: 'Firmware Version',
                      value: _selectedFirmwareVersion,
                      items: const ['v1.0.0', 'v1.1.0', 'v2.0.0'],
                      onChanged: (value) => setState(() => _selectedFirmwareVersion = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConfig.defaultPadding),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _serialController,
                      decoration: InputDecoration(
                        labelText: 'Device Serial Number',
                        hintText: 'Enter serial number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        filled: true,
                        fillColor: _isDarkTheme ? Colors.grey[800] : Colors.grey[100],
                      ),
                      style: TextStyle(color: _isDarkTheme ? Colors.white : Colors.black),
                      onChanged: (value) => context.read<LogBloc>().add(UpdateSerialNumberEvent(value)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.qr_code_scanner, color: _isDarkTheme ? Colors.white70 : AppColors.primary),
                    onPressed: () {
                      final scannedSerial = 'SN-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
                      _serialController.text = scannedSerial;
                      context.read<LogBloc>().add(UpdateSerialNumberEvent(scannedSerial));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Scanned device: $scannedSerial'), duration: const Duration(seconds: 2)),
                      );
                    },
                    tooltip: 'Scan QR Code',
                  ),
                ],
              ),
              const SizedBox(height: AppConfig.defaultPadding),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: 'USB Port',
                      value: _selectedPort,
                      items: state.availablePorts,
                      onChanged: (value) {
                        setState(() => _selectedPort = value);
                        context.read<LogBloc>().add(SelectUsbPortEvent(value!));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: Icon(Icons.refresh, size: 16, color: Colors.white),
                    label: state.isScanning
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                        : const Text('Refresh', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: state.isScanning ? null : () => context.read<LogBloc>().add(ScanUsbPortsEvent()),
                  ),
                ],
              ),
              const SizedBox(height: AppConfig.defaultPadding),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StatusText(status: state.status ?? 'Ready', color: statusColor),
                  const SizedBox(width: AppConfig.defaultPadding),
                  RoundedButton(
                    label: state.isFlashing ? 'Stop' : 'Flash Firmware',
                    icon: state.isFlashing ? Icons.stop : Icons.flash_on,
                    isLoading: state.isFlashing,
                    color: state.isFlashing ? Colors.red : AppColors.success,
                    onPressed: () {
                      if (state.isFlashing) {
                        context.read<LogBloc>().add(StopProcessEvent());
                      } else if (_serialController.text.isNotEmpty && _selectedFirmwareVersion != null && _selectedDeviceType != null) {
                        context.read<LogBloc>().add(InitiateFlashEvent(
                          deviceId: _serialController.text,
                          firmwareVersion: _selectedFirmwareVersion!,
                          deviceSerial: _serialController.text, deviceType: '',
                        ));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select device type, firmware version, and enter serial number')),
                        );
                      }
                    },
                  ),
                ],
              ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    state.error!,
                    style: TextStyle(color: AppColors.error, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        },
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: _isDarkTheme ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!),
            color: _isDarkTheme ? Colors.grey[800] : Colors.grey[100],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text('Select $label', style: TextStyle(color: _isDarkTheme ? Colors.grey[400] : Colors.grey[600])),
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              items: items.map((item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: TextStyle(color: _isDarkTheme ? Colors.white : Colors.black)),
              )).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogPanel() {
    return Container(
      margin: const EdgeInsets.all(AppConfig.defaultPadding),
      decoration: BoxDecoration(
        color: _isDarkTheme ? Colors.black87 : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildLogHeader(),
          Expanded(child: _buildLogList()),
        ],
      ),
    );
  }

  Widget _buildLogHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: _isDarkTheme ? Colors.black : Colors.grey[200],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Text(
            'Arduino CLI & Serial Monitor Output',
            style: TextStyle(
              color: _isDarkTheme ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center,
              color: _isDarkTheme ? Colors.white70 : Colors.grey[600],
              size: 20,
            ),
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
            tooltip: _autoScroll ? 'Auto-scroll enabled' : 'Auto-scroll disabled',
          ),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    return BlocConsumer<LogBloc, LogState>(
      listener: (context, state) {
        if (_autoScroll && state.filteredLogs.isNotEmpty) {
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
          return Center(
            child: Text(
              'No logs to display',
              style: TextStyle(color: _isDarkTheme ? Colors.grey[400] : Colors.grey[600]),
            ),
          );
        }
        return ListView.builder(
          controller: _scrollController,
          itemCount: state.filteredLogs.length,
          itemBuilder: (context, index) {
            final log = state.filteredLogs[index];
            return _buildLogItem(log);
          },
        );
      },
    );
  }

  Widget _buildLogItem(LogEntry log) {
    if (log is SerialInputLogEntry) {
      return _buildSerialInputRequest(log);
    }
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
        borderRadius: BorderRadius.circular(12),
        color: _isDarkTheme ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            log.message,
            style: TextStyle(
              color: _isDarkTheme ? Colors.green[300] : Colors.green[800],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            style: TextStyle(color: _isDarkTheme ? Colors.white : Colors.black),
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              fillColor: _isDarkTheme ? Colors.grey[900] : Colors.white,
              filled: true,
              hintText: 'Type your command...',
              hintStyle: TextStyle(color: _isDarkTheme ? Colors.grey[400] : Colors.grey[600]),
              prefixIcon: Icon(Icons.keyboard, color: _isDarkTheme ? Colors.green[300] : Colors.green[800], size: 18),
              suffixIcon: IconButton(
                icon: Icon(Icons.send, color: _isDarkTheme ? Colors.green[300] : Colors.green[800], size: 18),
                onPressed: () {
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

  Widget _buildSerialInput() {
    return BlocBuilder<LogBloc, LogState>(
      buildWhen: (previous, current) => current.activeInputRequest != previous.activeInputRequest,
      builder: (context, state) {
        if (state.activeInputRequest == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isDarkTheme ? Colors.grey[850] : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  focusNode: _inputFocusNode,
                  style: TextStyle(color: _isDarkTheme ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    fillColor: _isDarkTheme ? Colors.grey[900] : Colors.grey[100],
                    filled: true,
                    hintText: 'Type a command...',
                    hintStyle: TextStyle(color: _isDarkTheme ? Colors.grey[400] : Colors.grey[600]),
                    prefixIcon: Icon(Icons.terminal, color: _isDarkTheme ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty && state.activeInputRequest is SerialInputLogEntry) {
                      (state.activeInputRequest as SerialInputLogEntry).onSerialInput(value);
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
                  if (value.isNotEmpty && state.activeInputRequest is SerialInputLogEntry) {
                    (state.activeInputRequest as SerialInputLogEntry).onSerialInput(value);
                    _inputController.clear();
                    _inputFocusNode.requestFocus();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Send', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getLogColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return _isDarkTheme ? Colors.white : Colors.black87;
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Full screen mode toggled'), duration: Duration(seconds: 1)),
    );
  }
}