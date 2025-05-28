import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';
import 'package:esp_firmware_tool/presentation/blocs/device/device_bloc.dart';
import 'package:esp_firmware_tool/presentation/blocs/device/device_event.dart';
import 'package:esp_firmware_tool/presentation/blocs/device/device_state.dart';
import 'package:esp_firmware_tool/presentation/widgets/status_text.dart';
import 'package:esp_firmware_tool/presentation/widgets/rounded_button.dart';
import 'package:esp_firmware_tool/presentation/widgets/file_picker_button.dart';
import 'package:esp_firmware_tool/presentation/views/device_list_view.dart';
import 'package:esp_firmware_tool/presentation/views/log_view.dart';
import 'package:esp_firmware_tool/presentation/views/settings_view.dart';
import 'package:intl/intl.dart';

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
            icon: Icon(Icons.receipt_outlined),
            selectedIcon: Icon(Icons.receipt),
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

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final TextEditingController serialController = TextEditingController();

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat('HH:mm:ss').format(timestamp);
  }

  void _setSerialNumber(String value) {
    context.read<DeviceBloc>().add(SetSerialNumberEvent(value));
  }

  void _selectTemplate() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ino'],
    );

    if (result != null && result.files.single.path != null) {
      if (context.mounted) {
        context.read<DeviceBloc>().add(SelectTemplateEvent(result.files.single.path!));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: BlocBuilder<DeviceBloc, DeviceState>(
            builder: (context, state) {
              // Status color based on state
              Color statusColor = AppColors.idle;
              if (state.isCompiling || state.isFlashing) {
                statusColor = AppColors.primary;
              } else if (state.error != null) {
                statusColor = AppColors.error;
              } else if (state.isConnected) {
                statusColor = AppColors.success;
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

                  // Status indicator
                  StatusText(
                    status: state.status ?? 'Ready',
                    color: statusColor
                  ),

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
                          onChanged: _setSerialNumber,
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
                        context.read<DeviceBloc>().add(SelectTemplateEvent(path));
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
                                    context.read<DeviceBloc>().add(ScanUsbPortsEvent());
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
                                  context.read<DeviceBloc>().add(SelectUsbPortEvent(newValue));
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

                  const Spacer(),

                  // Action Button
                  RoundedButton(
                    label: state.isCompiling || state.isFlashing ? 'Stop' : 'Start',
                    icon: state.isCompiling || state.isFlashing
                        ? Icons.stop
                        : Icons.play_arrow,
                    isLoading: state.isCompiling || state.isFlashing,
                    color: state.isCompiling || state.isFlashing
                        ? Colors.red
                        : Colors.green,
                    onPressed: () {
                      if (state.isCompiling || state.isFlashing) {
                        context.read<DeviceBloc>().add(StopProcessEvent());
                      } else if (state.serialNumber != null &&
                                state.selectedTemplate != null) {
                        context.read<DeviceBloc>().add(StartProcessEvent());
                      } else {
                        // Show a snackbar if missing required fields
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter serial number and select a template'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    serialController.dispose();
    super.dispose();
  }
}