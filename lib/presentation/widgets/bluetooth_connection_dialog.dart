import 'package:flutter/material.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';
import 'package:smart_net_firmware_loader/data/services/bluetooth_service.dart';

class BluetoothConnectionDialog extends StatefulWidget {
  final BluetoothService bluetoothService;
  final bool isDarkTheme;
  final VoidCallback? onConnected;
  final VoidCallback? onCancelled;

  const BluetoothConnectionDialog({
    super.key,
    required this.bluetoothService,
    required this.isDarkTheme,
    this.onConnected,
    this.onCancelled,
  });

  @override
  State<BluetoothConnectionDialog> createState() => _BluetoothConnectionDialogState();
}

class _BluetoothConnectionDialogState extends State<BluetoothConnectionDialog>
    with SingleTickerProviderStateMixin {
  List<BluetoothDeviceInfo> _devices = [];
  BluetoothDeviceInfo? _selectedDevice;
  bool _isLoading = false;
  bool _isConnecting = false;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _animationController.forward();
    _checkBluetoothAndLoadDevices();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkBluetoothAndLoadDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if Bluetooth is enabled
      final isEnabled = await widget.bluetoothService.isBluetoothEnabled();
      if (!isEnabled) {
        final enableResult = await widget.bluetoothService.requestBluetoothEnable();
        if (!enableResult) {
          setState(() {
            _errorMessage = widget.bluetoothService.isPlatformSupported
                ? 'Bluetooth cần được bật để sử dụng tính năng này'
                : 'Đang chạy trên ${Theme.of(context).platform.name}.\nSử dụng chế độ mô phỏng cho testing.';
            _isLoading = false;
          });

          // For desktop, still load mock devices
          if (!widget.bluetoothService.isPlatformSupported) {
            _loadMockDevices();
          }
          return;
        }
      }

      // Load paired devices
      final devices = await widget.bluetoothService.getPairedDevices();
      setState(() {
        _devices = devices;
        _isLoading = false;
      });

      if (devices.isEmpty) {
        setState(() {
          _errorMessage = widget.bluetoothService.isPlatformSupported
              ? 'Không tìm thấy thiết bị Bluetooth đã ghép nối.\nVui lòng ghép nối thiết bị trong cài đặt hệ thống.'
              : 'Chế độ desktop: Không có thiết bị thật được kết nối.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi tải danh sách thiết bị: $e';
        _isLoading = false;
      });
    }
  }

  void _loadMockDevices() async {
    // Load mock devices for desktop testing
    final devices = await widget.bluetoothService.getPairedDevices();
    setState(() {
      _devices = devices;
      _isLoading = false;
      _errorMessage = null;
    });
  }

  Future<void> _connectToDevice() async {
    if (_selectedDevice == null) return;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.bluetoothService.connectToDevice(_selectedDevice!);
      if (success) {
        widget.onConnected?.call();
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _errorMessage = 'Không thể kết nối tới thiết bị ${_selectedDevice!.name}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi kết nối: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  Widget _buildDeviceList() {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang tải danh sách thiết bị...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null && _devices.isEmpty) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.bluetoothService.isPlatformSupported
                    ? Icons.error_outline
                    : Icons.wifi,
                size: 48,
                color: widget.bluetoothService.isPlatformSupported
                    ? AppColors.error
                    : AppColors.info,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.isDarkTheme ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _checkBluetoothAndLoadDevices,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 300,
      child: ListView.builder(
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final device = _devices[index];
          final isSelected = _selectedDevice?.address == device.address;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            elevation: isSelected ? 4 : 1,
            color: isSelected
                ? (widget.isDarkTheme ? AppColors.primary.withOpacity(0.2) : AppColors.primary.withOpacity(0.1))
                : (widget.isDarkTheme ? AppColors.darkCardBackground : AppColors.cardBackground),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isSelected ? AppColors.primary : AppColors.secondary,
                child: Icon(
                  widget.bluetoothService.isPlatformSupported
                      ? Icons.bluetooth
                      : Icons.wifi,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Text(
                device.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: widget.isDarkTheme ? AppColors.darkTextPrimary : AppColors.text,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.address,
                    style: TextStyle(
                      color: widget.isDarkTheme ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                  if (!widget.bluetoothService.isPlatformSupported)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Network Bridge for Mobile App',
                        style: TextStyle(
                          color: AppColors.info,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle, color: AppColors.primary)
                  : null,
              onTap: () {
                setState(() {
                  _selectedDevice = device;
                });
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: AlertDialog(
          backgroundColor: widget.isDarkTheme ? AppColors.darkCardBackground : AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.bluetoothService.isPlatformSupported
                      ? Icons.bluetooth
                      : Icons.wifi,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.bluetoothService.isPlatformSupported
                      ? 'Kết nối Bluetooth'
                      : 'Mobile QR Bridge',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkTheme ? AppColors.darkTextPrimary : AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.bluetoothService.isPlatformSupported
                      ? 'Chọn thiết bị Bluetooth để nhận dữ liệu QR code:'
                      : 'Khởi động network bridge để kết nối với mobile app:',
                  style: TextStyle(
                    color: widget.isDarkTheme ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                if (!widget.bluetoothService.isPlatformSupported) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.info.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.info, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Hướng dẫn kết nối:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.info,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '1. Khởi động bridge bằng cách chọn "Mobile QR Scanner Bridge"\n'
                          '2. Trên mobile app, kết nối tới địa chỉ IP được hiển thị\n'
                          '3. Quét QR code trên mobile app để gửi dữ liệu',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isDarkTheme ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _buildDeviceList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: widget.onCancelled ?? () => Navigator.of(context).pop(false),
              child: Text(
                'Hủy',
                style: TextStyle(
                  color: widget.isDarkTheme ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _selectedDevice != null && !_isConnecting ? _connectToDevice : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isConnecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(widget.bluetoothService.isPlatformSupported ? 'Kết nối' : 'Khởi động Bridge'),
            ),
          ],
        ),
      ),
    );
  }
}
