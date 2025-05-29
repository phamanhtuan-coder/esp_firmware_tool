import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/data/models/log_entry.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';
import 'package:esp_firmware_tool/utils/app_config.dart';
import 'package:esp_firmware_tool/presentation/widgets/rounded_button.dart';
import 'package:esp_firmware_tool/presentation/widgets/status_text.dart';
import 'package:window_manager/window_manager.dart';

class LogView extends StatefulWidget {
  const LogView({super.key});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  final TextEditingController _serialController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  bool _isDarkTheme = false;
  String? _selectedFirmwareVersion;
  String? _selectedDeviceType = 'esp32';
  String? _selectedPort;
  String? _selectedBatch;
  List<Map<String, dynamic>> _batches = [];

  @override
  void initState() {
    super.initState();
    _loadBatches();
    context.read<LogBloc>().add(FilterLogEvent(deviceFilter: ''));
    _scrollController.addListener(() {
      if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent) {
        setState(() => _autoScroll = false);
      } else {
        setState(() => _autoScroll = true);
      }
    });
  }

  void _loadBatches() async {
    final batches = await context.read<LogBloc>().logService.fetchBatches();
    setState(() => _batches = batches);
  }

  @override
  void dispose() {
    _serialController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
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
            onPressed: () async {
              final isFullScreen = await windowManager.isFullScreen();
              await windowManager.setFullScreen(!isFullScreen);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Full screen mode ${isFullScreen ? 'disabled' : 'enabled'}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Toggle Full Screen',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildControlPanel(),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildLogPanel(),
            ),
            _buildSerialInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(AppConfig.defaultPadding),
      decoration: BoxDecoration(
        color: _isDarkTheme ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 8)],
      ),
      margin: const EdgeInsets.all(AppConfig.defaultPadding),
      child: BlocBuilder<LogBloc, LogState>(
        builder: (context, state) {
          final statusColor = state.isFlashing
              ? AppColors.flashing
              : state.error != null
              ? AppColors.error
              : AppColors.done;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDropdown(
                label: 'Batch',
                value: _selectedBatch,
                items: _batches.map((batch) => batch['id'].toString()).toList(),
                onChanged: (value) {
                  setState(() => _selectedBatch = value);
                  context.read<LogBloc>().add(SelectBatchEvent(value!));
                },
              ),
              const SizedBox(height: AppConfig.defaultPadding),
              if (state.batchSerials.isNotEmpty) _buildSerialList(state.batchSerials, state.serialNumber),
              const SizedBox(height: AppConfig.defaultPadding),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: 'Firmware Version',
                      value: _selectedFirmwareVersion,
                      items: const ['v1.0.0', 'v1.1.0', 'v2.0.0'],
                      onChanged: (value) => setState(() => _selectedFirmwareVersion = value),
                    ),
                  ),
                  const SizedBox(width: AppConfig.defaultPadding),
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
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
                      } else if (state.serialNumber != null &&
                          _selectedFirmwareVersion != null &&
                          _selectedDeviceType != null &&
                          _selectedPort != null) {
                        context.read<LogBloc>().add(InitiateFlashEvent(
                          deviceId: state.serialNumber!,
                          firmwareVersion: _selectedFirmwareVersion!,
                          deviceSerial: state.serialNumber!,
                          deviceType: _selectedDeviceType!,
                        ));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select batch, serial, device type, firmware version, and port')),
                        );
                      }
                    },
                  ),
                  if (state.error != null)
                    RoundedButton(
                      label: 'Retry',
                      icon: Icons.refresh,
                      color: AppColors.primary,
                      onPressed: () {
                        if (state.serialNumber != null &&
                            _selectedFirmwareVersion != null &&
                            _selectedDeviceType != null &&
                            _selectedPort != null) {
                          context.read<LogBloc>().add(InitiateFlashEvent(
                            deviceId: state.serialNumber!,
                            firmwareVersion: _selectedFirmwareVersion!,
                            deviceSerial: state.serialNumber!,
                            deviceType: _selectedDeviceType!,
                          ));
                        }
                      },
                    ),
                  RoundedButton(
                    label: 'Mark Defective',
                    icon: Icons.error,
                    color: AppColors.error,
                    onPressed: () {
                      if (state.serialNumber != null) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirm Mark Defective'),
                            content: Text('Mark device ${state.serialNumber} as defective?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  context.read<LogBloc>().add(MarkDeviceDefectiveEvent(state.serialNumber!));
                                  Navigator.pop(context);
                                },
                                child: const Text('Confirm', style: TextStyle(color: AppColors.error)),
                              ),
                            ],
                          ),
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

  Widget _buildSerialList(List<String> serials, String? selectedSerial) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        border: Border.all(color: _isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
        color: _isDarkTheme ? Colors.grey[800] : Colors.grey[100],
      ),
      child: ListView.builder(
        itemCount: serials.length,
        itemBuilder: (context, index) {
          final serial = serials[index];
          return ListTile(
            title: Text(serial, style: TextStyle(color: _isDarkTheme ? Colors.white : Colors.black)),
            selected: serial == selectedSerial,
            selectedTileColor: AppColors.primary.withOpacity(0.2),
            onTap: () => context.read<LogBloc>().add(SelectSerialEvent(serial)),
          );
        },
      ),
    );
  }

  Widget _buildSerialInput() {
    return BlocBuilder<LogBloc, LogState>(
      buildWhen: (previous, current) =>
      current.activeInputRequest != previous.activeInputRequest || current.serialNumber != previous.serialNumber,
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isDarkTheme ? Colors.grey[850] : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serialController,
                  focusNode: _inputFocusNode,
                  style: TextStyle(color: _isDarkTheme ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    fillColor: _isDarkTheme ? Colors.grey[900] : Colors.grey[100],
                    filled: true,
                    hintText: 'Enter or scan serial number',
                    hintStyle: TextStyle(color: _isDarkTheme ? Colors.grey[400] : Colors.grey[600]),
                    prefixIcon: Icon(Icons.qr_code, color: _isDarkTheme ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  onChanged: (value) => context.read<LogBloc>().add(UpdateSerialNumberEvent(value)),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      context.read<LogBloc>().add(SelectSerialEvent(value));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  // Simulate QR code scanning (replace with actual QR scan integration)
                  final scannedSerial = 'SN-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
                  _serialController.text = scannedSerial;
                  context.read<LogBloc>().add(SelectSerialEvent(scannedSerial));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Scan QR', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogPanel() {
    return Container(
      margin: const EdgeInsets.all(AppConfig.defaultPadding),
      decoration: BoxDecoration(
        color: _isDarkTheme ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 8)],
      ),
      child: _buildLogList(),
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
        final filteredLogs =
        state.filteredLogs.where((log) => log.deviceId == state.serialNumber || log.deviceId.isEmpty).toList();
        if (filteredLogs.isEmpty) {
          return Center(
            child: Text(
              'No logs to display',
              style: TextStyle(color: _isDarkTheme ? Colors.grey[400] : Colors.grey[600]),
            ),
          );
        }
        return ListView.builder(
          controller: _scrollController,
          itemCount: filteredLogs.length,
          itemBuilder: (context, index) {
            final log = filteredLogs[index];
            return _buildLogItem(log);
          },
        );
      },
    );
  }

  Widget _buildLogItem(LogEntry log) {
    final color = log.level == LogLevel.error
        ? AppColors.error
        : log.level == LogLevel.warning
        ? AppColors.warning
        : AppColors.text;
    return ListTile(
      title: Text(
        '[${log.timestamp.toIso8601String()}] ${log.message}',
        style: TextStyle(color: color, fontSize: 14),
      ),
      subtitle: Text(
        'Device: ${log.deviceId.isEmpty ? 'N/A' : log.deviceId}, Step: ${log.step}, Origin: ${log.origin}',
        style: TextStyle(color: _isDarkTheme ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        fillColor: _isDarkTheme ? Colors.grey[900] : Colors.grey[100],
        filled: true,
      ),
      style: TextStyle(color: _isDarkTheme ? Colors.white : Colors.black),
      dropdownColor: _isDarkTheme ? Colors.grey[800] : Colors.white,
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }
}