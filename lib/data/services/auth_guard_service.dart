import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';
import 'package:smart_net_firmware_loader/core/config/app_routes.dart';
import 'package:smart_net_firmware_loader/data/services/auth_service.dart';

class AuthGuardService {
  final AuthService _authService;
  Timer? _tokenCheckTimer;
  Timer? _logoutTimer;
  bool _isShowingWarning = false;

  AuthGuardService(this._authService) {
    // Start periodic token check
    _tokenCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => checkTokenValidity(),
    );
  }

  void checkTokenValidity() {
    if (!_authService.isTokenValid() && !_isShowingWarning) {
      _isShowingWarning = true;

      final context = GetIt.instance<GlobalKey<NavigatorState>>().currentContext;
      if (context != null && context.mounted) {
        _showLogoutWarning(context);
      }
    }
  }

  void _showLogoutWarning(BuildContext context) {
    int remainingSeconds = 10;

    // Show initial warning
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Phiên làm việc của bạn sắp hết hạn. Tự động đăng xuất sau $remainingSeconds giây.'),
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Đăng xuất ngay',
          textColor: Colors.white,
          onPressed: () => _performLogout(context),
        ),
      ),
    );

    // Start countdown timer
    _logoutTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        remainingSeconds--;
        if (context.mounted) {
          if (remainingSeconds > 0) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Phiên làm việc của bạn sắp hết hạn. Tự động đăng xuất sau $remainingSeconds giây.'),
                backgroundColor: AppColors.warning,
                duration: const Duration(seconds: 1),
                action: SnackBarAction(
                  label: 'Đăng xuất ngay',
                  textColor: Colors.white,
                  onPressed: () => _performLogout(context),
                ),
              ),
            );
          } else {
            timer.cancel();
            _performLogout(context);
          }
        }
      },
    );
  }

  void _performLogout(BuildContext context) {
    _logoutTimer?.cancel();
    _authService.clearToken();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.'),
        backgroundColor: AppColors.error,
        duration: Duration(seconds: 2),
      ),
    );

    // Navigate to login after showing the message
    Future.delayed(const Duration(seconds: 2), () {
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
      }
      _isShowingWarning = false;
    });
  }

  void dispose() {
    _tokenCheckTimer?.cancel();
    _logoutTimer?.cancel();
  }
}
