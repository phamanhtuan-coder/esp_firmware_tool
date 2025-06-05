import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:smart_net_firmware_loader/domain/blocs/home_bloc.dart';
import 'package:smart_net_firmware_loader/presentation/views/home_view.dart';
import 'package:smart_net_firmware_loader/presentation/views/login_view.dart';
import 'package:smart_net_firmware_loader/presentation/views/splash_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String splash = '/splash';

  static final Map<String, WidgetBuilder> routes = {
    login: (context) => BlocProvider<HomeBloc>(
      create: (_) => GetIt.instance<HomeBloc>(),
      child: const LoginView(),
    ),
    home: (context) => const HomeView(),
    splash: (context) => const SplashScreen(),
  };
}
