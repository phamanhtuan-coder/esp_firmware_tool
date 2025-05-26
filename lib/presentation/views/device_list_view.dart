import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/device.dart';
import '../../utils/app_colors.dart';
import '../../utils/enums.dart';
import '../blocs/device/device_bloc.dart';
import 'log_view.dart';

class DeviceListView extends StatefulWidget {
  const DeviceListView({super.key});

  @override
  State<DeviceListView> createState() => _DeviceListViewState();
}

class _DeviceListViewState extends State<DeviceListView> {
  Device? selectedDevice;

  @override
  void initState() {
    super.initState();
    context.read<DeviceBloc>().add(FetchDevices());
  }

  void _selectDevice(Device device) {
    setState(() {
      selectedDevice = device;
    });

    // Navigate to log view for the selected device
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
        title: const Text('ESP Devices'),
        centerTitle: true,
      ),
      body: BlocBuilder<DeviceBloc, DeviceState>(
        builder: (context, state) {
          if (state.devices.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.devices, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No ESP devices connected', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.devices.length,
            itemBuilder: (context, index) {
              final device = state.devices[index] as Device;

              // Map string status to enum for color
              DeviceStatus deviceStatus;
              switch (device.status.toLowerCase()) {
                case 'connected':
                  deviceStatus = DeviceStatus.connected;
                  break;
                case 'compiling':
                  deviceStatus = DeviceStatus.compiling;
                  break;
                case 'flashing':
                  deviceStatus = DeviceStatus.flashing;
                  break;
                case 'done':
                  deviceStatus = DeviceStatus.done;
                  break;
                default:
                  deviceStatus = DeviceStatus.error;
              }

              return DeviceListTile(
                device: device,
                isSelected: selectedDevice?.id == device.id,
                status: deviceStatus,
                onTap: () => _selectDevice(device),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<DeviceBloc>().add(FetchDevices()),
        tooltip: 'Refresh Devices',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class DeviceListTile extends StatelessWidget {
  final Device device;
  final bool isSelected;
  final DeviceStatus status;
  final VoidCallback onTap;

  const DeviceListTile({
    super.key,
    required this.device,
    required this.isSelected,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? Colors.blue.withOpacity(0.1) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Colors.blue, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: status.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.usb, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'USB Port: ${device.usbPort ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.qr_code, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Serial: ${device.serialNumber ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              if (device.firmwareVersion != null) const SizedBox(height: 8),
              if (device.firmwareVersion != null)
                Row(
                  children: [
                    const Icon(Icons.memory, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Firmware: ${device.firmwareVersion}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.analytics),
                  label: const Text('View Logs'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}