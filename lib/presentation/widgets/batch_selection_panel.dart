import 'package:flutter/material.dart';
import 'package:smart_net_firmware_loader/data/models/device.dart';
import 'package:smart_net_firmware_loader/data/models/batch.dart';
import 'package:smart_net_firmware_loader/utils/app_colors.dart';
import 'package:smart_net_firmware_loader/data/services/device_status_service.dart';
import 'package:smart_net_firmware_loader/data/services/planning_service.dart';
import 'package:smart_net_firmware_loader/di/service_locator.dart';
import 'package:provider/provider.dart';

import '../blocs/log/log_bloc.dart';

class BatchSelectionPanel extends StatefulWidget {
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
    this.selectedPlanning,
    required this.onPlanningSelected,
  });

  @override
  State<BatchSelectionPanel> createState() => _BatchSelectionPanelState();
}

class _BatchSelectionPanelState extends State<BatchSelectionPanel> {
  List<Map<String, String>> _plannings = [];
  List<Batch> _batches = [];
  List<Device> _devices = [];
  bool _isLoadingPlannings = true;
  bool _isLoadingBatches = false;
  bool _isLoadingDevices = false;
  String? _errorMessage;
  String? _batchErrorMessage;
  String? _deviceErrorMessage;

  @override
  void initState() {
    super.initState();
    _loadPlannings();
  }

  Future<void> _loadPlannings() async {
    setState(() {
      _isLoadingPlannings = true;
      _errorMessage = null;
    });

    try {
      final planningService = serviceLocator<PlanningService>();
      final plannings = await planningService.fetchPlannings();

      setState(() {
        _plannings = plannings;
        _isLoadingPlannings = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Không thể tải dữ liệu kế hoạch: $e';
        _isLoadingPlannings = false;
      });
    }
  }

  Future<void> _loadBatchesForPlanning(String planningId) async {
    setState(() {
      _isLoadingBatches = true;
      _batchErrorMessage = null;
      _batches = []; // Clear existing batches
    });

    try {
      final planningService = serviceLocator<PlanningService>();
      final batches = await planningService.fetchBatches(planningId);

      setState(() {
        _batches = batches;
        _isLoadingBatches = false;
      });
    } catch (e) {
      setState(() {
        _batchErrorMessage = 'Không thể tải danh sách lô: $e';
        _isLoadingBatches = false;
      });
    }
  }

  Future<void> _loadDevicesForBatch(String batchId) async {
    setState(() {
      _isLoadingDevices = true;
      _deviceErrorMessage = null;
      _devices = []; // Clear existing devices
    });

    try {
      final planningService = serviceLocator<PlanningService>();
      final devices = await planningService.fetchDevices(batchId);

      setState(() {
        _devices = devices;
        _isLoadingDevices = false;
      });
    } catch (e) {
      setState(() {
        _deviceErrorMessage = 'Không thể tải danh sách thiết bị: $e';
        _isLoadingDevices = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: widget.isDarkTheme ? AppColors.darkSurface : AppColors.cardBackground,
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
                _buildPlanningDropdown(),

                const SizedBox(height: 16),

                // Batch Dropdown
                const Text('Chọn lô (Batch)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                _buildBatchDropdown(),
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
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: widget.isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildDeviceList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanningDropdown() {
    if (_isLoadingPlannings) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadPlannings,
              color: AppColors.error,
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: widget.selectedPlanning,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        fillColor: widget.isDarkTheme ? AppColors.darkCardBackground : Colors.white,
        filled: true,
      ),
      items: _plannings.map((planning) => DropdownMenuItem(
        value: planning['id'],
        child: Text(planning['name']!),
      )).toList(),
      onChanged: (value) {
        if (value != null) {
          widget.onPlanningSelected(value);

          // Reset batches and devices when planning changes
          setState(() {
            _batches = [];
            _devices = []; // Reset device list when planning changes
            _deviceErrorMessage = null;
          });

          _loadBatchesForPlanning(value);
        }
      },
      hint: const Text('-- Chọn kế hoạch --'),
    );
  }

  Widget _buildBatchDropdown() {
    if (_isLoadingBatches) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_batchErrorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _batchErrorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: widget.selectedPlanning != null
                ? () => _loadBatchesForPlanning(widget.selectedPlanning!)
                : null,
              color: AppColors.error,
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: widget.selectedBatch,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        fillColor: widget.isDarkTheme ? AppColors.darkCardBackground : Colors.white,
        filled: true,
      ),
      items: _batches.map((batch) => DropdownMenuItem(
        value: batch.id,
        child: Text(batch.name),
      )).toList(),
      onChanged: (value) {
        if (value != null) {
          widget.onBatchSelected(value);
          _loadDevicesForBatch(value);
        }
      },
      hint: const Text('-- Chọn lô --'),
    );
  }

  Widget _buildDeviceList() {
    if (_isLoadingDevices) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_deviceErrorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _deviceErrorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: widget.selectedBatch != null
                ? () => _loadDevicesForBatch(widget.selectedBatch!)
                : null,
              color: AppColors.error,
            ),
          ],
        ),
      );
    }

    if (_devices.isEmpty) {
      return const Center(
        child: Text(
          'Không có thiết bị nào trong lô này',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Get the current serial from the state or context
    final logBloc = context.read<LogBloc>();
    final currentSerial = logBloc.state.serialNumber ?? '';

    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];

        // Check if this device matches the currently entered serial
        final bool isSerialMatch = currentSerial.isNotEmpty &&
            device.serial.trim().toLowerCase() == currentSerial.trim().toLowerCase();

        // Highlight the row with a more visible background if it matches the current serial
        final Color? highlightColor = isSerialMatch
            ? (widget.isDarkTheme ? Colors.blue[800]!.withOpacity(0.4) : Colors.blue[200])
            : null;

        return Container(
          decoration: BoxDecoration(
            color: isSerialMatch ? highlightColor : null,
            border: Border(
              bottom: BorderSide(
                color: widget.isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!,
                width: index != _devices.length - 1 ? 1 : 0,
              ),
            ),
          ),
          child: ListTile(
            leading: Text('${index + 1}'),
            title: Text(
              device.serial,
              style: TextStyle(
                fontWeight: isSerialMatch ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.status == 'firmware_failed' ? 'Chờ sửa chữa / Lỗi' :
                  device.status == 'firmware_uploading' ? 'Đang nạp firmware' :
                  device.status == 'firmware_uploaded' ? 'Đã nạp firmware' :
                  device.status == 'firmware_upload' ? 'Hàng chờ nạp firmware' :
                  device.status == 'processing' ? 'Đang xử lý' : 'Chờ xử lý',
                  style: TextStyle(
                    color:  device.status == 'firmware_failed' ? AppColors.error
                        : device.status == 'firmware_uploading' ? AppColors.success
                        : device.status == 'firmware_uploaded' ? AppColors.success
                        : device.status == 'firmware_upload' ? AppColors.connected
                        : device.status == 'processing' ? AppColors.connected
                        : AppColors.warning,
                  ),
                ),
                // Add status indicator for matching serial
                if (isSerialMatch)
                  Text(
                    device.status == 'firmware_uploading' ? 'Thiết bị sẵn sàng để nạp firmware' :
                    device.status == 'firmware_uploaded' ? 'Thiết bị đã hoàn thành nạp firmware' :
                    device.status == 'firmware_failed' ? 'Thiết bị đã được đánh dấu lỗi firmware' :
                    device.status == 'firmware_upload' ? 'Thiết bị đang trong hàng chờ nạp firmware':'Thiết bị đang chờ xử lý',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color: widget.isDarkTheme ? AppColors.darkTextSecondary : Colors.grey[600],
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
            selected: widget.selectedDevice == device.id.toString() || isSerialMatch,
            selectedTileColor: widget.isDarkTheme ? Colors.blue[900]!.withOpacity(0.2) : Colors.blue[50],
            onTap: () => widget.onDeviceSelected(device.id.toString()),
          ),
        );
      },
    );
  }

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
        backgroundColor: widget.isDarkTheme ? AppColors.darkCardBackground : Colors.white,
        title: Row(
          children: [
            Icon(dialogIcon, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: widget.isDarkTheme ? AppColors.darkTextPrimary : AppColors.text
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
                color: widget.isDarkTheme ? AppColors.darkPanelBackground : AppColors.dividerColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.isDarkTheme ? AppColors.darkDivider : Colors.grey.shade300,
                ),
              ),
              child: Text(
                device.serial,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: widget.isDarkTheme ? AppColors.darkTextPrimary : AppColors.text,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: widget.isDarkTheme ? AppColors.darkTextSecondary : Colors.grey.shade700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: widget.isDarkTheme ? AppColors.darkTextSecondary : Colors.grey.shade700,
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

  void _showApiResultDialog(BuildContext context, Map<String, dynamic> result, String deviceSerial) {
    final bool isSuccess = result['success'] == true;
    final String title = isSuccess ? 'Cập nhật thành công' : 'Cập nhật thất bại';
    final String message = result['message'] ?? (isSuccess ? 'Thiết bị đã được cập nhật trạng thái thành công.' : 'Không thể cập nhật trạng thái thiết bị.');
    final IconData dialogIcon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;
    final Color iconColor = isSuccess ? AppColors.success : AppColors.error;

    print('Showing API result dialog: success=$isSuccess, message=$message');

    Future.delayed(Duration.zero, () {
      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: widget.isDarkTheme ? AppColors.darkCardBackground : Colors.white,
          title: Row(
            children: [
              Icon(dialogIcon, color: iconColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: widget.isDarkTheme ? AppColors.darkTextPrimary : AppColors.text,
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thiết bị: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkTheme ? AppColors.darkTextSecondary : Colors.grey.shade700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      deviceSerial,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: widget.isDarkTheme ? AppColors.darkTextPrimary : AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Thông báo từ máy chủ:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: widget.isDarkTheme ? AppColors.darkTextSecondary : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isDarkTheme
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
                    color: widget.isDarkTheme ? AppColors.darkTextPrimary : AppColors.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (result['errorCode'] != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mã lỗi: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkTheme ? AppColors.darkTextSecondary : Colors.grey.shade700,
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

  Future<void> _updateDeviceStatus(BuildContext context, Device device, bool isSuccess) async {
    final deviceStatusService = serviceLocator<DeviceStatusService>();

    print('DEBUG: Starting _updateDeviceStatus for ${device.serial}');

    BuildContext? dialogContext;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        dialogContext = ctx;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: widget.isDarkTheme ? AppColors.darkCardBackground : Colors.white,
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.isDarkTheme ? AppColors.accent : AppColors.primary,
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

      if (dialogContext != null) {
        try {
          Navigator.of(dialogContext!).pop();
        } catch (e) {
          print('DEBUG: Error dismissing dialog: $e');
        }
      }

      final String newStatus = isSuccess ? 'firmware_uploading' : 'firmware_failed';
      final updatedDevice = device.copyWith(status: newStatus);

      if (result['success'] == true) {
        print('DEBUG: API call was successful, updating device state');
        widget.onDeviceMarkDefective(updatedDevice);
      }

      if (context.mounted) {
        print('DEBUG: Context is still mounted, showing result dialog');
        _showApiResultDialog(context, result, device.serial);
      } else {
        print('DEBUG: Context is not mounted, cannot show result dialog');
      }
    }
  }
}
