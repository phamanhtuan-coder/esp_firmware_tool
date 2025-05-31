import 'package:flutter/material.dart';
import 'package:esp_firmware_tool/data/models/device.dart';
import 'package:esp_firmware_tool/data/models/batch.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';
import 'package:esp_firmware_tool/data/services/device_status_service.dart';
import 'package:esp_firmware_tool/di/service_locator.dart';

class BatchSelectionPanel extends StatelessWidget {
  final List<Batch> batches;
  final List<Device> devices;
  final String? selectedBatch;
  final String? selectedDevice;
  final String? selectedPlanning;
  final Function(String?) onBatchSelected;
  final Function(String?) onDeviceSelected;
  final Function(String?) onPlanningSelected;
  final Function(Device) onDeviceMarkDefective;
  final bool isDarkTheme;

  // List of available plannings
  final List<Map<String, String>> plannings = [
    {'id': '1', 'name': 'Planning 2025 Q1'},
    {'id': '2', 'name': 'Planning 2025 Q2'},
    {'id': '3', 'name': 'Planning 2025 Q3'},
    {'id': '4', 'name': 'Planning 2025 Q4'},
  ];

  BatchSelectionPanel({
    super.key,
    required this.batches,
    required this.devices,
    required this.selectedBatch,
    required this.selectedDevice,
    required this.onBatchSelected,
    required this.onDeviceSelected,
    required this.onDeviceMarkDefective,
    required this.isDarkTheme,
    this.selectedPlanning,
    required this.onPlanningSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkTheme ? AppColors.darkSurface : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 8)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Planning Dropdown
                const Text('Chọn kế hoạch', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: selectedPlanning,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    fillColor: isDarkTheme ? AppColors.darkCardBackground : Colors.white,
                    filled: true,
                  ),
                  items: plannings.map((planning) => DropdownMenuItem(
                    value: planning['id'],
                    child: Text(planning['name']!),
                  )).toList(),
                  onChanged: onPlanningSelected,
                  hint: const Text('-- Chọn kế hoạch --'),
                ),

                const SizedBox(height: 16),

                // Batch Dropdown
                const Text('Chọn lô (Batch)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: selectedBatch,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    fillColor: isDarkTheme ? AppColors.darkCardBackground : Colors.white,
                    filled: true,
                  ),
                  items: batches.map((batch) => DropdownMenuItem(
                    value: batch.id.toString(),
                    child: Text(batch.name),
                  )).toList(),
                  onChanged: onBatchSelected,
                  hint: const Text('-- Chọn lô --'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Danh sách thiết bị trong lô', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: selectedBatch != null && devices.isNotEmpty
                        ? Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ListView.builder(
                                itemCount: devices.length,
                                itemBuilder: (context, index) {
                                  final device = devices[index];
                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!,
                                          width: index != devices.length - 1 ? 1 : 0,
                                        ),
                                      ),
                                    ),
                                    child: ListTile(
                                      leading: Text('${index + 1}'),
                                      title: Text(device.serial),
                                      subtitle: Text(
                                        device.status == 'defective' ? 'Hư hỏng' : device.status == 'processing' ? 'Đang xử lý' : 'Chờ xử lý',
                                        style: TextStyle(
                                          color: device.status == 'defective' ? AppColors.error
                                              : device.status == 'processing' ? AppColors.connected
                                              : AppColors.warning,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Success button
                                          IconButton(
                                            icon: const Icon(Icons.check_circle, color: Colors.green),
                                            tooltip: 'Đánh dấu thành công',
                                            onPressed: device.status == 'defective' ? null :
                                                () => _showStatusConfirmationDialog(
                                                  context,
                                                  device,
                                                  isSuccess: true
                                                ),
                                          ),
                                          // Error button
                                          IconButton(
                                            icon: const Icon(Icons.error, color: Colors.red),
                                            tooltip: 'Đánh dấu lỗi',
                                            onPressed: device.status == 'defective' ? null :
                                                () => _showStatusConfirmationDialog(
                                                  context,
                                                  device,
                                                  isSuccess: false
                                                ),
                                          ),
                                        ],
                                      ),
                                      selected: selectedDevice == device.id.toString(),
                                      selectedTileColor: isDarkTheme ? Colors.blue[900]!.withOpacity(0.2) : Colors.blue[50],
                                      onTap: () => onDeviceSelected(device.id.toString()),
                                    ),
                                  );
                                },
                              ),
                            ),
                          )
                        : const Center(child: Text('Vui lòng chọn lô để xem danh sách thiết bị', style: TextStyle(color: Colors.grey))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Show confirmation dialog for status update (success or error)
  void _showStatusConfirmationDialog(BuildContext context, Device device, {required bool isSuccess}) {
    final String title = isSuccess ? 'Xác nhận thành công' : 'Xác nhận lỗi';
    final String message = isSuccess
        ? 'Bạn có chắc chắn muốn đánh dấu thiết bị ${device.serial} là Nạp firmware thành công không?'
        : 'Bạn có chắc chắn muốn đánh dấu thiết bị ${device.serial} là hư hỏng không?';
    final String confirmButtonText = isSuccess ? 'Xác nhận thành công' : 'Xác nhận lỗi';
    final Color confirmButtonColor = isSuccess ? Colors.green : Colors.red;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Serial Number'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              color: isDarkTheme ? AppColors.idle : AppColors.dividerColor,
              child: Text(device.serial)
            ),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateDeviceStatus(context, device, isSuccess);
            },
            child: Text(
              confirmButtonText,
              style: TextStyle(color: confirmButtonColor),
            ),
          ),
        ],
      ),
    );
  }

  // Update device status via API
  Future<void> _updateDeviceStatus(BuildContext context, Device device, bool isSuccess) async {
    final deviceStatusService = serviceLocator<DeviceStatusService>();

    // Show loading indicator
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Đang cập nhật trạng thái thiết bị...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      // Call API to update status
      final result = await deviceStatusService.updateDeviceStatus(
        deviceSerial: device.serial,
        isSuccessful: isSuccess,
      );

      // Show success or error message based on API response
      if (result['success'] == true) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Cập nhật trạng thái thành công: ${result['message'] ?? 'Thành công!'}'),
            backgroundColor: Colors.green,
          ),
        );

        // Update local state by calling the callback
        if (!isSuccess) {
          // Only call the defective callback if it's an error
          onDeviceMarkDefective(device);
        }
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Cập nhật trạng thái thất bại: ${result['message'] ?? 'Lỗi không xác định'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Show error message if exception occurs
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Lỗi khi cập nhật trạng thái: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
