import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';
import 'package:esp_firmware_tool/data/models/device.dart';
import 'package:esp_firmware_tool/data/models/batch.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';

class BatchSelectionPanel extends StatelessWidget {
  final List<Batch> batches;
  final List<Device> devices;
  final String? selectedBatch;
  final String? selectedDevice;
  final Function(String?) onBatchSelected;
  final Function(String?) onDeviceSelected;
  final Function(Device) onDeviceMarkDefective;
  final bool isDarkTheme;

  const BatchSelectionPanel({
    super.key,
    required this.batches,
    required this.devices,
    required this.selectedBatch,
    required this.selectedDevice,
    required this.onBatchSelected,
    required this.onDeviceSelected,
    required this.onDeviceMarkDefective,
    required this.isDarkTheme,
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
                                      trailing: IconButton(
                                        icon: const Icon(Icons.error, color: Colors.red),
                                        onPressed: device.status == 'defective' ? null : () => _showErrorDialog(context, device),
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

  void _showErrorDialog(BuildContext context, Device device) {
    String reason = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Báo cáo lỗi thiết bị'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Serial Number'),
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.all(8), color: isDarkTheme ? AppColors.idle : AppColors.dividerColor, child: Text(device.serial)),
            const SizedBox(height: 8),
            const Text('Lý do lỗi *'),
            const SizedBox(height: 4),
            TextField(
              onChanged: (value) => reason = value,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Nhập lý do lỗi'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            const Text('Ảnh minh chứng (tùy chọn)'),
            const SizedBox(height: 4),
            TextField(
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Chọn file ảnh'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(
            onPressed: reason.isNotEmpty
                ? () {
              onDeviceMarkDefective(device);
              Navigator.pop(context);
            }
                : null,
            child: const Text('Báo lỗi', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}