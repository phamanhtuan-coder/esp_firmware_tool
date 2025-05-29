import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';

class FirmwareControlPanel extends StatelessWidget {
  final bool isDarkTheme;
  final String? selectedFirmwareVersion;
  final String? selectedPort;
  final TextEditingController serialController;
  final Function(String?) onFirmwareVersionSelected;
  final Function(String?) onUsbPortSelected;
  final VoidCallback onLocalFileSearch;
  final VoidCallback onUsbPortRefresh;
  final Function(String) onSerialSubmitted;
  final VoidCallback onQrCodeScan;
  final List<String> availablePorts;

  const FirmwareControlPanel({
    super.key,
    required this.isDarkTheme,
    required this.selectedFirmwareVersion,
    required this.selectedPort,
    required this.serialController,
    required this.onFirmwareVersionSelected,
    required this.onUsbPortSelected,
    required this.onLocalFileSearch,
    required this.onUsbPortRefresh,
    required this.onSerialSubmitted,
    required this.onQrCodeScan,
    required this.availablePorts,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Phiên bản Firmware', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: selectedFirmwareVersion,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        fillColor: isDarkTheme ? AppColors.idle : AppColors.cardBackground,
                        filled: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'v1.0.0', child: Text('v1.0.0')),
                        DropdownMenuItem(value: 'v1.1.0', child: Text('v1.1.0')),
                        DropdownMenuItem(value: 'v2.0.0-beta', child: Text('v2.0.0-beta')),
                      ],
                      onChanged: onFirmwareVersionSelected,
                      hint: const Text('-- Chọn phiên bản --'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Find in file'),
                style: TextButton.styleFrom(
                  backgroundColor: isDarkTheme ? AppColors.idle : AppColors.dividerColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onLocalFileSearch,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: serialController,
                  decoration: InputDecoration(
                    labelText: 'Serial Number',
                    hintText: 'Nhập hoặc quét mã serial',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    fillColor: isDarkTheme ? AppColors.idle : AppColors.cardBackground,
                    filled: true,
                  ),
                  onSubmitted: onSerialSubmitted,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code, size: 16),
                label: const Text('Quét QR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.connected,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onQrCodeScan,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cổng COM (USB)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: selectedPort,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        fillColor: isDarkTheme ? AppColors.idle : AppColors.cardBackground,
                        filled: true,
                      ),
                      items: availablePorts.map((port) => DropdownMenuItem(
                        value: port,
                        child: Text(port),
                      )).toList(),
                      onChanged: onUsbPortSelected,
                      hint: const Text('-- Chọn cổng COM --'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text(''),
                style: TextButton.styleFrom(
                  backgroundColor: isDarkTheme ? AppColors.idle : AppColors.dividerColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onUsbPortRefresh,
              ),
            ],
          ),
        ],
      ),
    );
  }
}