import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/presentation/blocs/log/log_bloc.dart';
import 'package:smart_net_firmware_loader/utils/app_colors.dart';

class ActionButtons extends StatelessWidget {
  final bool isDarkTheme;
  final VoidCallback onClearLogs;
  final Function(String, String, String, String, String?) onInitiateFlash;
  final String? selectedPort;
  final String? selectedFirmwareVersion;
  final String? selectedDevice;
  final String deviceSerial;

  const ActionButtons({
    super.key,
    required this.isDarkTheme,
    required this.onClearLogs,
    required this.onInitiateFlash,
    required this.selectedPort,
    required this.selectedFirmwareVersion,
    required this.selectedDevice,
    required this.deviceSerial,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LogBloc, LogState>(
      buildWhen: (previous, current) =>
        previous.isFlashing != current.isFlashing ||
        previous.localFilePath != current.localFilePath,
      builder: (context, state) {
        final hasLocalFile = state.localFilePath != null;

        // Calculate if the flash button should be enabled
        final isFlashEnabled = !state.isFlashing &&
                           selectedPort != null &&
                           (hasLocalFile || selectedFirmwareVersion != null) &&
                           deviceSerial.isNotEmpty;

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
                icon: state.isFlashing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.upload),
                label: Text(
                  state.isFlashing ? 'Đang nạp firmware...' : 'Nạp Firmware',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkTheme ? AppColors.success : AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isFlashEnabled
                    ? () {
                        if (selectedDevice != null) {
                          onInitiateFlash(
                            selectedDevice!,
                            selectedFirmwareVersion ?? '',
                            deviceSerial,
                            selectedPort!,
                            state.localFilePath,
                          );
                        }
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
