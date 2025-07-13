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

class _BluetoothConnectionDialogState extends State<BluetoothConnectionDialog> with SingleTickerProviderStateMixin {
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
      final isEnabled = await widget.bluetoothService.isBluetoothEnabled();
      if (!isEnabled) {
        final enableResult = await widget.bluetoothService.requestBluetoothEnable();
        if (!enableResult) {
          setState(() {
            _errorMessage = 'Please enable Bluetooth and pair the mobile device in Windows settings.';
            _isLoading = false;
          });
          return;
        }
      }
      final devices = await widget.bluetoothService.getPairedDevices();
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
      if (devices.isEmpty) {
        setState(() {
          _errorMessage = 'No paired Bluetooth devices found. Please pair the mobile device in Windows settings.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading devices: $e';
        _isLoading = false;
      });
    }
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
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = 'Failed to connect to ${_selectedDevice!.name}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: $e';
      });
    } finally {
      if (mounted) setState(() => _isConnecting = false);
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
              Text('Loading devices...'),
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
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
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
                label: const Text('Retry'),
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
                child: const Icon(Icons.bluetooth, color: Colors.white, size: 20),
              ),
              title: Text(
                device.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: widget.isDarkTheme ? AppColors.darkTextPrimary : AppColors.text,
                ),
              ),
              subtitle: Text(
                device.address,
                style: TextStyle(
                  color: widget.isDarkTheme ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
              trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
              onTap: () => setState(() => _selectedDevice = device),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bluetooth, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Connect to Bluetooth Device',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                const Text(
                  'Select a paired Bluetooth device to receive QR code data:',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                _buildDeviceList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: widget.onCancelled ?? () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: _selectedDevice != null && !_isConnecting ? _connectToDevice : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isConnecting
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
                  : const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}