import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';
import 'package:esp_firmware_tool/utils/enums.dart';
import 'package:esp_firmware_tool/presentation/blocs/device/device_bloc.dart';
import 'package:esp_firmware_tool/presentation/blocs/device/device_event.dart';
import 'package:esp_firmware_tool/presentation/blocs/device/device_state.dart';
import 'package:esp_firmware_tool/presentation/widgets/status_text.dart';
import 'package:esp_firmware_tool/presentation/widgets/rounded_button.dart';
import 'package:esp_firmware_tool/presentation/widgets/file_picker_button.dart';
import 'package:esp_firmware_tool/presentation/widgets/process_log_view.dart';
import 'package:esp_firmware_tool/presentation/views/device_list_view.dart';
import 'package:esp_firmware_tool/presentation/views/log_view.dart';
import 'package:esp_firmware_tool/presentation/views/settings_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeContent(),
    const DeviceListView(),
    const LogView(deviceId: 'system'), // System-wide logs
    const SettingsView(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: 'Devices',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal),
            label: 'Logs',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour}:${timestamp.minute}:${timestamp.second}';
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController serialController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP Firmware Tool'),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: BlocBuilder<DeviceBloc, DeviceState>(
            builder: (context, state) {
              final status = state.status;
              Color statusColor;
              switch (status) {
                case DeviceStatus.compiling:
                case DeviceStatus.flashing:
                case DeviceStatus.checking:
                  statusColor = AppColors.primary;
                  break;
                case DeviceStatus.done:
                  statusColor = AppColors.success;
                  break;
                case DeviceStatus.error:
                  statusColor = AppColors.error;
                  break;
                default:
                  statusColor = AppColors.idle;
              }

              // Update the serial controller if we have a value in the state
              if (state.serialNumber != null && serialController.text.isEmpty) {
                serialController.text = state.serialNumber!;
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'ESP Firmware Tool',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  StatusText(status: status.label, color: statusColor),

                  // Error message
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        state.error!,
                        style: TextStyle(color: AppColors.error, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Serial Number Input with QR Scan Button
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: serialController,
                          decoration: const InputDecoration(
                            labelText: 'Device Serial Number',
                            hintText: 'Enter serial number',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            context.read<DeviceBloc>().add(SetSerialNumber(value));
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'QR Code scanner not available',
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: null, // Disabled as requested
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            disabledBackgroundColor: Colors.grey[200],
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Template Selection
                  FilePickerButton(
                    label: 'Select Template',
                    onFilePicked: (path) {
                      if (path != null) {
                        context.read<DeviceBloc>().add(SelectTemplate(path));
                      }
                    },
                  ),

                  if (state.selectedTemplate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Selected: ${state.selectedTemplate}',
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  const SizedBox(height: 16),

                  // USB Port Selection with Retry Button
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'USB Port:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh, size: 16),
                            label: state.isScanning
                                ? Container(
                                    width: 16,
                                    height: 16,
                                    margin: const EdgeInsets.only(right: 8),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Refresh'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              minimumSize: const Size(80, 36),
                            ),
                            onPressed: state.isScanning
                                ? null
                                : () {
                                    context.read<DeviceBloc>().add(const ScanUsbPorts());
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Port selection
                      if (state.availablePorts.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: state.selectedPort,
                              hint: const Text('Select USB Port'),
                              isExpanded: true,
                              items: state.availablePorts.map((port) {
                                return DropdownMenuItem<String>(
                                  value: port,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.usb,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        port,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                if (newValue != null) {
                                  context.read<DeviceBloc>().add(SelectUsbPort(newValue));
                                }
                              },
                            ),
                          ),
                        )
                      else if (state.isScanning)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.grey.shade100,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'No USB devices detected',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Last scan time indicator
                      if (state.lastScanTime != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Last scan: ${_formatTimestamp(state.lastScanTime!)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Start/Stop Process Button
                  RoundedButton(
                    label: status == DeviceStatus.compiling || status == DeviceStatus.flashing
                        ? 'Stop Process'
                        : 'Start Process',
                    color: status == DeviceStatus.compiling || status == DeviceStatus.flashing
                        ? AppColors.error
                        : AppColors.primary,
                    enabled: state.serialNumber != null &&
                             state.serialNumber!.isNotEmpty &&
                             state.selectedTemplate != null &&
                             !(status == DeviceStatus.checking),
                    onPressed: () {
                      if (status == DeviceStatus.compiling || status == DeviceStatus.flashing) {
                        context.read<DeviceBloc>().add(StopProcess());
                      } else {
                        context.read<DeviceBloc>().add(StartProcess());
                      }
                    },
                  ),

                  const SizedBox(height: 24),

                  // Process Log View
                  const ProcessLogView(processId: 'main_process', maxLines: 6),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}