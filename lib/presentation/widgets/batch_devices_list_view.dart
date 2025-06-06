import 'package:flutter/material.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';
import 'package:smart_net_firmware_loader/data/models/device.dart';

class BatchDevicesListView extends StatelessWidget {
  final List<Device> devices;
  final bool isDarkTheme;
  final String? selectedSerial;
  final Function(String, String) onUpdateDeviceStatus;

  const BatchDevicesListView({
    super.key,
    required this.devices,
    required this.isDarkTheme,
    this.selectedSerial,
    required this.onUpdateDeviceStatus,
  });

  String _getStatusText(String status) {
    switch (status) {
      case 'firmware_uploading':
        return 'Sẵn sàng nạp firmware';
      case 'firmware_uploaded':
        return 'Đã nạp firmware';
      case 'error':
        return 'Lỗi';
      case 'completed':
        return 'Hoàn thành';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'firmware_uploading':
        return Colors.blue;
      case 'firmware_uploaded':
        return Colors.green;
      case 'error':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkTheme ? AppColors.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkTheme ? AppColors.darkHeaderBackground : AppColors.primary.withAlpha(25),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Text(
              'Danh sách thiết bị trong lô',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: devices.isEmpty
                ? Center(
                    child: Text(
                      'Không có thiết bị nào trong lô này',
                      style: TextStyle(
                        color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final device = devices[index];
                            final isSelected = device.serial == selectedSerial;

                            return Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDarkTheme ? Colors.blue.withOpacity(0.15) : Colors.blue.withOpacity(0.05))
                                    : null,
                                border: Border(
                                  bottom: BorderSide(
                                    color: isDarkTheme ? Colors.grey[800]! : Colors.grey[200]!,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            device.serial,
                                            style: TextStyle(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              fontSize: 15,
                                              color: isDarkTheme ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        // Status indicator
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(device.status),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Status text
                                        Expanded(
                                          child: Text(
                                            _getStatusText(device.status),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDarkTheme ? Colors.white70 : Colors.black54,
                                            ),
                                          ),
                                        ),
                                        // Action buttons with smaller size
                                        SizedBox(
                                          height: 32,
                                          child: ElevatedButton(
                                            onPressed: () => onUpdateDeviceStatus(device.id, 'completed'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.success,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              minimumSize: const Size(32, 32),
                                              textStyle: const TextStyle(fontSize: 12),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check, size: 16),
                                                SizedBox(width: 4),
                                                Text('Hoàn thành'),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          height: 32,
                                          child: ElevatedButton(
                                            onPressed: () => onUpdateDeviceStatus(device.id, 'error'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.error,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              minimumSize: const Size(32, 32),
                                              textStyle: const TextStyle(fontSize: 12),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.error, size: 16),
                                                SizedBox(width: 4),
                                                Text('Lỗi'),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: devices.length,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
