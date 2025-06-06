import 'package:flutter/material.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';

class WarningDialog extends StatelessWidget {
  final bool isDarkTheme;
  final VoidCallback onCancel;
  final VoidCallback onContinue;
  final String title;
  final String message;
  final String type; // Add type property

  const WarningDialog({
    super.key,
    required this.isDarkTheme,
    required this.onCancel,
    required this.onContinue,
    required this.title,
    required this.message,
    this.type = 'warning', // Default to warning type
  });

  @override
  Widget build(BuildContext context) {
    Color getIconColor() {
      switch (type) {
        case 'success':
          return AppColors.success;
        case 'error':
          return AppColors.error;
        default:
          return AppColors.warning;
      }
    }

    IconData getIcon() {
      switch (type) {
        case 'success':
          return Icons.check_circle;
        case 'error':
          return Icons.error;
        default:
          return Icons.warning;
      }
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onCancel,
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkTheme ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  getIcon(),
                  color: getIconColor(),
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: getIconColor(),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (type == 'warning') ...[
                      TextButton(
                        onPressed: onCancel,
                        child: const Text('Hủy'),
                      ),
                      ElevatedButton(
                        onPressed: onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: getIconColor(),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Tiếp tục'),
                      ),
                    ] else
                      ElevatedButton(
                        onPressed: onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: getIconColor(),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Đóng'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
