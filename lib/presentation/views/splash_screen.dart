import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';
import 'package:smart_net_firmware_loader/core/config/app_routes.dart';
import 'package:smart_net_firmware_loader/core/utils/debug_logger.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // DebugLogger.lifecycle('SplashScreen initialized');

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    // Use a minimum display time for the splash screen (3 seconds)
    // This ensures users can see the splash screen even if initialization is fast
    Timer(const Duration(seconds: 3), _checkNavigationToLogin);
  }

  void _checkNavigationToLogin() {
    // DebugLogger.lifecycle('Checking navigation from splash to login');
    if (mounted && !_navigated) {
      setState(() {
        _navigated = true;
      });
      // DebugLogger.lifecycle('Navigating from splash to login');
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    // DebugLogger.lifecycle('SplashScreen disposed');
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary.withOpacity(0.1), AppColors.background],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  height: 140,
                  width: 140,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/app_icon.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      DebugLogger.e(
                        'Error loading app icon',
                        error: error,
                        stackTrace: stackTrace,
                      );
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 60,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Error: $error',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Text(
                    'SmartNet Firmware Loader',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Text(
                      'Smart IoT Device Management',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              FadeTransition(
                opacity: _fadeAnimation,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    strokeWidth: 3,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
