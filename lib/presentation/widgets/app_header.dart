import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool isDarkTheme;
  final VoidCallback onThemeToggled;

  const AppHeader({
    super.key,
    required this.isDarkTheme,
    required this.onThemeToggled,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: isDarkTheme ? AppColors.darkHeaderBackground : AppColors.accent,
      title: const Text('Firmware Deployment Tool', style: TextStyle(color: Colors.white)),
      actions: [
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