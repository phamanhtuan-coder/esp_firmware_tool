import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool isDarkTheme;
  final double zoomLevel;
  final Function(double) onZoomChanged;
  final VoidCallback onThemeToggled;

  const AppHeader({
    super.key,
    required this.isDarkTheme,
    required this.zoomLevel,
    required this.onZoomChanged,
    required this.onThemeToggled,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: isDarkTheme ? AppColors.primary : AppColors.accent,
      title: const Text('Firmware Deployment Tool', style: TextStyle(color: Colors.white)),
      actions: [
        Text('${(zoomLevel * 100).toInt()}%', style: const TextStyle(color: Colors.white)),
        IconButton(
          icon: const Icon(Icons.zoom_out),
          onPressed: () => onZoomChanged((zoomLevel - 0.1).clamp(0.7, 1.5)),
        ),
        IconButton(
          icon: const Icon(Icons.zoom_in),
          onPressed: () => onZoomChanged((zoomLevel + 0.1).clamp(0.7, 1.5)),
        ),
        IconButton(
          icon: const Icon(Icons.fullscreen),
          onPressed: () async {
            final isFullScreen = await windowManager.isFullScreen();
            await windowManager.setFullScreen(!isFullScreen);
          }
        ),
        IconButton(
          icon: Icon(isDarkTheme ? Icons.wb_sunny : Icons.nights_stay, color: AppColors.warning),
          onPressed: onThemeToggled,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}