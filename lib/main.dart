import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/di/service_locator.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';
import 'package:esp_firmware_tool/presentation/views/log_view.dart';
import 'package:esp_firmware_tool/utils/app_routes.dart';
import 'package:esp_firmware_tool/utils/app_theme.dart';
import 'presentation/views/login_view.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Configure window to start maximized with standard controls
  WindowOptions windowOptions = const WindowOptions(
    titleBarStyle: TitleBarStyle.normal, // Preserve standard window controls
    size: Size(1280,720), // Initial size, will be maximized later
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
        title: 'ESP Firmware Tool',
        theme: AppTheme.lightTheme,
        home: const LoginView(),
        routes: {
          AppRoutes.logs: (context) => const LogView(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}