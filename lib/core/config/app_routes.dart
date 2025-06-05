import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:smart_net_firmware_loader/domain/blocs/home_bloc.dart';
import 'package:smart_net_firmware_loader/domain/blocs/logging_bloc.dart';
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
    home: (context) => MultiBlocProvider(
      providers: [
        BlocProvider<HomeBloc>(
          create: (_) => GetIt.instance<HomeBloc>()..add(LoadInitialDataEvent()),
        ),
        BlocProvider<LoggingBloc>(
          create: (_) => GetIt.instance<LoggingBloc>(),
        ),
      ],
      child: const HomeView(),
    ),
    splash: (context) => const SplashScreen(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final builder = routes[settings.name];
    if (builder != null) {
      return MaterialPageRoute(
        builder: builder,
        settings: settings,
      );
    }
    return null;
  }
}
