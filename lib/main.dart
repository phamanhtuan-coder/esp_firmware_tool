import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/di/service_locator.dart';
import 'package:smart_net_firmware_loader/presentation/blocs/log/log_bloc.dart';
import 'package:smart_net_firmware_loader/presentation/views/home_view.dart';
import 'package:smart_net_firmware_loader/utils/app_routes.dart';
import 'package:smart_net_firmware_loader/utils/app_theme.dart';
import 'presentation/views/login_view.dart';
import 'presentation/views/splash_screen.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Configure window to start maximized with standard controls
  WindowOptions windowOptions = const WindowOptions(
    title: 'Firmware Deployment Tool',
    titleBarStyle: TitleBarStyle.normal, // Preserve standard window controls
    size: Size(1600,900), // Initial size, will be maximized later
    center: true, // Make sure window is centered on screen
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.maximize(); // Start in maximized mode
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setAlignment(Alignment.center);
  });

  setupServiceLocator();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LogBloc>(create: (context) => serviceLocator<LogBloc>()),
      ],
      child: MaterialApp(
        title: 'SmartNet Firmware Loader',
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
        routes: {
          AppRoutes.login: (context) => const LoginView(),
          AppRoutes.home: (context) => const HomeView(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

