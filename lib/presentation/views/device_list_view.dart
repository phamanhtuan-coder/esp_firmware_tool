import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/data/models/device.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';
import 'package:esp_firmware_tool/utils/enums.dart';
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
    context.read<DeviceBloc>().add(FetchDevices());
  }

  void _viewDeviceLogs(Device device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogView(deviceId: device.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Devices'),
      ),
      body: BlocBuilder<DeviceBloc, DeviceState>(
        builder: (context, state) {
          if (state.devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.devices_other,
                      size: 64, color: AppColors.idle),
                  const SizedBox(height: 16),
                  Text(
                    'No devices connected',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.idle,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () {
                      context.read<DeviceBloc>().add(FetchDevices());
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<DeviceBloc>().add(FetchDevices());
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.devices.length,
              itemBuilder: (context, index) {
                final device = state.devices[index];
                return DeviceCard(
                  device: device,
                  onLogView: () => _viewDeviceLogs(device),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback onLogView;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onLogView,
  });

  DeviceStatus _getDeviceStatus() {
    switch (device.status.toLowerCase()) {
      case 'connected':
        return DeviceStatus.connected;
      case 'compiling':
        return DeviceStatus.compiling;
      case 'flashing':
        return DeviceStatus.flashing;
      case 'done':
        return DeviceStatus.done;
      default:
        return DeviceStatus.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _getDeviceStatus();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(status.icon, color: status.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    device.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: status.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(
                      color: status.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            DeviceInfoRow(
              icon: Icons.usb,
              label: 'Port',
              value: device.usbPort ?? 'Unknown',
            ),
            const SizedBox(height: 8),
            DeviceInfoRow(
              icon: Icons.numbers,
              label: 'Serial',
              value: device.serialNumber ?? 'Unknown',
            ),
            if (device.firmwareVersion != null) ...[
              const SizedBox(height: 8),
              DeviceInfoRow(
                icon: Icons.memory,
                label: 'Firmware',
                value: device.firmwareVersion!,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: onLogView,
                  icon: const Icon(Icons.description),
                  label: const Text('View Logs'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DeviceInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const DeviceInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.idle),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: AppColors.idle),
          ),
        ),
      ],
    );
  }
}