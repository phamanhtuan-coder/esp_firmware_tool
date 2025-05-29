import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';

class ActionButtons extends StatelessWidget {
  final bool isDarkTheme;
  final VoidCallback onClearLogs;
  final Function(String, String, String, String) onInitiateFlash;
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.clear),
            label: const Text('Clear Log'),
            style: TextButton.styleFrom(
              backgroundColor: isDarkTheme ? Colors.grey[700] : Colors.grey[200],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onClearLogs,
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
            label: Text(isFlashing ? 'Flashing...' : 'Flash Firmware'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFlashing || selectedPort == null || selectedFirmwareVersion == null
                  ? Colors.grey
                  : Colors.green[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: isFlashing || selectedPort == null || selectedFirmwareVersion == null || selectedDevice == null
                ? null
                : () {
                    onInitiateFlash(
                      selectedDevice!,
                      selectedFirmwareVersion!,
                      deviceSerial,
                      'esp32',
                    );
                  },
          ),
        ],
      ),
    );
  }
}