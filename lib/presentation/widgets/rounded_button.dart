import 'package:flutter/material.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';

class RoundedButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color color;
  final bool enabled;
  final IconData? icon;
  final bool isLoading;

  const RoundedButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.color,
    this.enabled = true,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
      child: isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: AppColors.background,
              strokeWidth: 2,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.background, size: 20),
                const SizedBox(width: 8),
              ],
              Text(label, style: const TextStyle(fontSize: 16, color: AppColors.background, fontWeight: FontWeight.bold)),
            ],
          ),
    );
  }
}