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
                                        device.status == 'defective' ? 'Chờ sửa chữa' :
                                        device.status == 'firmware_failed' ? 'Chờ sửa chữa' :
                                        device.status == 'firmware_uploading' ? 'Đã nạp firmware' :
                                        device.status == 'processing' ? 'Đang xử lý' : 'Chờ xử lý',
                                        style: TextStyle(
                                          color: device.status == 'defective' || device.status == 'firmware_failed' ? AppColors.error
                                              : device.status == 'firmware_uploading' ? AppColors.success
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
    final IconData dialogIcon = isSuccess ? Icons.check_circle : Icons.error;
    final Color iconColor = isSuccess ? AppColors.success : AppColors.error;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDarkTheme ? AppColors.darkCardBackground : Colors.white,
        title: Row(
          children: [
            Icon(dialogIcon, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDarkTheme ? AppColors.darkTextPrimary : AppColors.text
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Serial Number',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDarkTheme ? AppColors.darkPanelBackground : AppColors.dividerColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkTheme ? AppColors.darkDivider : Colors.grey.shade300,
                ),
              ),
              child: Text(
                device.serial,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isDarkTheme ? AppColors.darkTextPrimary : AppColors.text,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: isDarkTheme ? AppColors.darkTextSecondary : Colors.grey.shade700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: isDarkTheme ? AppColors.darkTextSecondary : Colors.grey.shade700,
            ),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateDeviceStatus(context, device, isSuccess);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: iconColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isSuccess ? 'Xác nhận thành công' : 'Xác nhận lỗi'),
          ),
        ],
        actionsAlignment: MainAxisAlignment.end,
        buttonPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  // Show API result dialog after getting response
  void _showApiResultDialog(BuildContext context, Map<String, dynamic> result, String deviceSerial) {
    final bool isSuccess = result['success'] == true;
    final String title = isSuccess ? 'Cập nhật thành công' : 'Cập nhật thất bại';
    final String message = result['message'] ?? (isSuccess ? 'Thiết bị đã được cập nhật trạng thái thành công.' : 'Không thể cập nhật trạng thái thiết bị.');
    final IconData dialogIcon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;
    final Color iconColor = isSuccess ? AppColors.success : AppColors.error;

    // Log that we're showing the dialog
    print('Showing API result dialog: success=$isSuccess, message=$message');

    // Use Future.delayed to ensure this runs after any frame rebuilds
    Future.delayed(Duration.zero, () {
      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false, // Force user to interact with dialog
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDarkTheme ? AppColors.darkCardBackground : Colors.white,
          title: Row(
            children: [
              Icon(dialogIcon, color: iconColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDarkTheme ? AppColors.darkTextPrimary : AppColors.text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Device serial
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thiết bị: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkTheme ? AppColors.darkTextSecondary : Colors.grey.shade700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      deviceSerial,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isDarkTheme ? AppColors.darkTextPrimary : AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),

              // Message from server
              const SizedBox(height: 12),
              Text(
                'Thông báo từ máy chủ:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkTheme ? AppColors.darkTextSecondary : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkTheme
                      ? isSuccess ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1)
                      : isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSuccess ? AppColors.success.withOpacity(0.3) : AppColors.error.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    color: isDarkTheme ? AppColors.darkTextPrimary : AppColors.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Error code if present
              if (result['errorCode'] != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mã lỗi: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkTheme ? AppColors.darkTextSecondary : Colors.grey.shade700,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        result['errorCode'] ?? 'unknown',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSuccess ? AppColors.primary : AppColors.idle,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Đóng'),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    });
  }

  // Update device status via API
  Future<void> _updateDeviceStatus(BuildContext context, Device device, bool isSuccess) async {
    final deviceStatusService = serviceLocator<DeviceStatusService>();

    print('DEBUG: Starting _updateDeviceStatus for ${device.serial}');

    // Store the context safely - make it nullable
    BuildContext? dialogContext;

    // Show a simple loading dialog that captures its own context
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        // Store dialog context for later dismissal
        dialogContext = ctx;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDarkTheme ? AppColors.darkCardBackground : Colors.white,
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDarkTheme ? AppColors.accent : AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text('Đang cập nhật trạng thái thiết bị...'),
              ),
            ],
          ),
        );
      },
    );

    print('DEBUG: Loading dialog shown, making API call now');

    Map<String, dynamic> result = {
      'success': false,
      'message': 'Unknown error occurred',
    };

    try {
      print('DEBUG: Calling deviceStatusService.updateDeviceStatus');
      // Set a timeout for the API call
      result = await deviceStatusService.updateDeviceStatus(
        deviceSerial: device.serial,
        isSuccessful: isSuccess,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('DEBUG: API call timeout after 15 seconds');
          return {
            'success': false,
            'message': 'Kết nối đến máy chủ quá thời gian, vui lòng thử lại sau.',
            'errorCode': 'timeout'
          };
        },
      );
      print('DEBUG: API call completed with result: $result');
    } catch (e) {
      print('DEBUG: Exception in API call: $e');
      result = {
        'success': false,
        'message': 'Đã xảy ra lỗi khi gọi API: $e',
        'errorCode': 'exception',
      };
    } finally {
      print('DEBUG: In finally block, dismissing dialog');

      // Dismiss the loading dialog safely - check for null first
      if (dialogContext != null) {
        try {
          Navigator.of(dialogContext!).pop();
        } catch (e) {
          print('DEBUG: Error dismissing dialog: $e');
        }
      }

      // Create updated device with new status
      final String newStatus = isSuccess ? 'firmware_uploading' : 'firmware_failed';
      final updatedDevice = device.copyWith(status: newStatus);

      // Update local state if API call was successful
      if (result['success'] == true) {
        print('DEBUG: API call was successful, updating device state');
        onDeviceMarkDefective(updatedDevice);
      }

      // Show result dialog
      if (context.mounted) {
        print('DEBUG: Context is still mounted, showing result dialog');
        _showApiResultDialog(context, result, device.serial);
      } else {
        print('DEBUG: Context is not mounted, cannot show result dialog');
      }
    }
  }
}
