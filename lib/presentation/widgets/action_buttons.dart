import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/presentation/blocs/log/log_bloc.dart';
import 'package:smart_net_firmware_loader/utils/app_colors.dart';

class ActionButtons extends StatelessWidget {
  final bool isDarkTheme;
  final VoidCallback onClearLogs;
  final Function(String, String, String, String, String?) onInitiateFlash;
  final bool isFlashing;
  final String? selectedPort;
  final String? selectedFirmwareVersion;
  final String? selectedDevice;
  final String deviceSerial;

  const ActionButtons({
    super.key,
    required this.isDarkTheme,
    required this.onClearLogs,
    required this.onInitiateFlash,
    required this.isFlashing,
    required this.selectedPort,
    required this.selectedFirmwareVersion,
    required this.selectedDevice,
    required this.deviceSerial,
  });

  @override
  Widget build(BuildContext context) {
    final logState = context.watch<LogBloc>().state;
    final hasLocalFile = logState.localFilePath != null;
    final isFlashEnabled = !isFlashing && selectedPort != null && (hasLocalFile || selectedFirmwareVersion != null) && deviceSerial.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.clear),
            label: const Text('Clear Log'),
            style: TextButton.styleFrom(
              backgroundColor: isDarkTheme ? AppColors.idle : AppColors.dividerColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              onClearLogs();
              context.read<LogBloc>().add(ClearLogsEvent());
            },
          ),
          ElevatedButton.icon(
            icon: isFlashing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.flash_on, size: 16),
            label: Text(isFlashing ? 'Đang nạp firmware...' : 'Nạp Firmware'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFlashEnabled ? AppColors.done : AppColors.idle,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: isFlashing || !isFlashEnabled
                ? null
                : () {
                    try {
                      // Don't send firmware version if using local file
                      final logState = context.read<LogBloc>().state;
                      final localFilePath = logState.localFilePath;
                      final firmwareVersion = localFilePath != null ? '' : selectedFirmwareVersion ?? '';

                      // First notify the LogBloc about the flashing event
                      context.read<LogBloc>().add(InitiateFlashEvent(
                        deviceId: selectedDevice ?? '',
                        firmwareVersion: firmwareVersion,
                        deviceSerial: deviceSerial,
                        deviceType: 'esp32',
                        localFilePath: localFilePath,
                      ));

                      // Then call the onInitiateFlash callback
                      onInitiateFlash(
                        selectedDevice ?? '',
                        firmwareVersion,
                        deviceSerial,
                        'esp32',
                        localFilePath,
                      );
                    } catch (e) {
                      // Make sure to reset flashing state on error
                      context.read<LogBloc>().add(StopProcessEvent());
                    }
                  },
          ),
        ],
      ),
    );
  }
}
