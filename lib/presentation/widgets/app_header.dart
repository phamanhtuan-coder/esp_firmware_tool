import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';
import 'package:smart_net_firmware_loader/core/config/app_routes.dart';
import 'package:smart_net_firmware_loader/data/services/auth_service.dart';
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

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Hủy',
              style: TextStyle(
                color: isDarkTheme ? AppColors.accent : AppColors.primary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authService = GetIt.instance<AuthService>();
      await authService.clearToken();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
      }
    }
  }

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
              if (username != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
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
                          if (userRole != null)
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
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                        tooltip: 'Đăng xuất',
                        onPressed: () => _handleLogout(context),
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
              ],

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
