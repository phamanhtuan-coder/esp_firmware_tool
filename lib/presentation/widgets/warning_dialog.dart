import 'package:flutter/material.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';

class WarningDialog extends StatelessWidget {
  final bool isDarkTheme;
  final VoidCallback onCancel;
  final VoidCallback onContinue;
  final String title;
  final String message;

  const WarningDialog({
    super.key,
    required this.isDarkTheme,
    required this.onCancel,
    required this.onContinue,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
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
                Text(
                  title,
                  style: TextStyle(
                    color: isDarkTheme ? AppColors.warning : AppColors.warning,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(message),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('Hủy'),
                    ),
                    ElevatedButton(
                      onPressed: onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Tiếp tục'),
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