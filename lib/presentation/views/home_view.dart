import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/app_colors.dart';
import '../../utils/enums.dart';
import '../blocs/device/device_bloc.dart';
import '../widgets/status_text.dart';
import '../widgets/rounded_button.dart';
import '../widgets/file_picker_button.dart';
import 'device_list_view.dart';
import 'log_view.dart';

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
    const LogView(),
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
        ],
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
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
                case DeviceStatus.processing:
                  statusColor = AppColors.primary;
                  break;
                case DeviceStatus.completed:
                  statusColor = AppColors.success;
                  break;
                case DeviceStatus.error:
                  statusColor = AppColors.error;
                  break;
                default:
                  statusColor = AppColors.idle;
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
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RoundedButton(
                        label: status == DeviceStatus.processing ? 'Stop Process' : 'Start Process',
                        color: status == DeviceStatus.processing ? AppColors.error : AppColors.primary,
                        enabled: status != DeviceStatus.loading,
                        onPressed: () {
                          if (status == DeviceStatus.processing) {
                            context.read<DeviceBloc>().add(StopProcess());
                          } else {
                            context.read<DeviceBloc>().add(StartProcess());
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      FilePickerButton(
                        label: 'Select Template',
                        onFilePicked: (path) {
                          if (path != null) {
                            context.read<DeviceBloc>().add(SelectTemplate(path));
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (state.selectedTemplate != null)
                    Text('Selected: ${state.selectedTemplate}', style: const TextStyle(fontSize: 13)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}