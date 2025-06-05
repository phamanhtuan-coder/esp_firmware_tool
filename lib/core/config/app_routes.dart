import 'package:flutter/material.dart';
import 'package:smart_net_firmware_loader/presentation/views/home_view.dart';
import 'package:smart_net_firmware_loader/presentation/views/login_view.dart';
import 'package:smart_net_firmware_loader/presentation/views/splash_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String splash = '/splash';

  static final Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginView(),
    home: (context) => const HomeView(),
    splash: (context) => const SplashScreen(),
  };
}
