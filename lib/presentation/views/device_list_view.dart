import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';
import 'package:esp_firmware_tool/presentation/blocs/device/device_bloc.dart';
import 'package:esp_firmware_tool/presentation/blocs/device/device_event.dart';
import 'package:esp_firmware_tool/presentation/blocs/device/device_state.dart';
import 'package:esp_firmware_tool/presentation/views/log_view.dart';

class DeviceListView extends StatefulWidget {
  const DeviceListView({super.key});

  @override
  State<DeviceListView> createState() => _DeviceListViewState();
}

class _DeviceListViewState extends State<DeviceListView> {
  @override
  void initState() {
    super.initState();
    context.read<DeviceBloc>().add(ScanUsbPortsEvent());
  }

  void _viewDeviceLogs(String portName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogView(deviceId: portName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Ports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<DeviceBloc>().add(ScanUsbPortsEvent());
            },
          ),
        ],
      ),
      body: BlocBuilder<DeviceBloc, DeviceState>(
        builder: (context, state) {
          if (state.isScanning) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.availablePorts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.usb, size: 64, color: AppColors.idle),
                  const SizedBox(height: 16),
                  Text(
                    'No USB devices detected',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.idle,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () {
                      context.read<DeviceBloc>().add(ScanUsbPortsEvent());
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Scan Again'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<DeviceBloc>().add(ScanUsbPortsEvent());
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.availablePorts.length,
              itemBuilder: (context, index) {
                final port = state.availablePorts[index];
                return PortListItem(
                  portName: port,
                  isSelected: state.selectedPort == port,
                  onPortSelected: () {
                    context.read<DeviceBloc>().add(SelectUsbPortEvent(port));
                  },
                  onViewLogs: () => _viewDeviceLogs(port),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class PortListItem extends StatelessWidget {
  final String portName;
  final bool isSelected;
  final VoidCallback onPortSelected;
  final VoidCallback onViewLogs;

  const PortListItem({
    super.key,
    required this.portName,
    required this.isSelected,
    required this.onPortSelected,
    required this.onViewLogs,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Colors.blue.shade50 : null,
      child: ListTile(
        leading: const Icon(Icons.usb),
        title: Text(portName),
        subtitle: Text(isSelected ? 'Selected' : 'Available'),
        trailing: IconButton(
          icon: const Icon(Icons.remove_red_eye),
          onPressed: onViewLogs,
        ),
        onTap: onPortSelected,
      ),
    );
  }
}