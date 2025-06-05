import 'package:flutter/material.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';
import 'package:window_manager/window_manager.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool isDarkTheme;
  final VoidCallback onThemeToggled;
  final String? username;
  final String? userRole;

  const AppHeader({
    super.key,
    required this.isDarkTheme,
    required this.onThemeToggled,
    this.username = 'Lãng tữ lang thang',
    this.userRole = 'Chủ tịch',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkTheme ? AppColors.darkHeaderBackground : AppColors.accent,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(15),
          bottomRight: Radius.circular(15),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              // App Logo and Title
              Container(
                height: 35,
                width: 35,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset('assets/app_icon.png'),
              ),
              const SizedBox(width: 12),
              const Text(
                'SmartNet Firmware Loader',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              // Spacer
              const Spacer(),

              // User Welcome Message
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chào mừng, $username',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      userRole!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Action buttons
              IconButton(
                icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
                tooltip: 'Toàn màn hình',
                onPressed: () async {
                  final isFullScreen = await windowManager.isFullScreen();
                  await windowManager.setFullScreen(!isFullScreen);
                },
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  isDarkTheme
                      ? Icons.wb_sunny_rounded
                      : Icons.nights_stay_rounded,
                  color: AppColors.warning,
                ),
                tooltip:
                    isDarkTheme
                        ? 'Đổi sang Light Theme'
                        : 'Đổi sang Dark Theme',
                onPressed: onThemeToggled,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(72);
}
