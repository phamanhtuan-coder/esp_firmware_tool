import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/core/config/app_routes.dart';
import 'package:smart_net_firmware_loader/core/config/app_theme.dart';
import 'package:smart_net_firmware_loader/data/services/api_client.dart';
import 'package:smart_net_firmware_loader/data/services/arduino_service.dart';
import 'package:smart_net_firmware_loader/data/services/bluetooth_service.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:smart_net_firmware_loader/data/services/serial_monitor_service.dart';
import 'package:smart_net_firmware_loader/domain/blocs/home_bloc.dart';
import 'package:smart_net_firmware_loader/domain/blocs/logging_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:window_manager/window_manager.dart';

void setupServiceLocator() {
  final getIt = GetIt.instance;
  getIt.registerSingleton<LogService>(LogService());
  getIt.registerSingleton<ApiService>(ApiService());
  getIt.registerSingleton<ArduinoService>(ArduinoService());
  getIt.registerSingleton<BluetoothService>(BluetoothService());
  getIt.registerSingleton<SerialMonitorService>(SerialMonitorService());
  getIt.registerFactory<HomeBloc>(() => HomeBloc());
  getIt.registerFactory<LoggingBloc>(() => LoggingBloc());
}

Future<void> setupWindow() async {
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1280, 720), // Default window size
    minimumSize: Size(800, 600), // Minimum window size
    center: true, // Center window on screen
    title: 'SmartNet Firmware Loader',
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupWindow(); // Initialize window settings
  setupServiceLocator();
  final arduinoService = GetIt.instance<ArduinoService>();
  await arduinoService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => GetIt.instance<HomeBloc>()..add(LoadInitialDataEvent()),
        ),
        BlocProvider(create: (_) => GetIt.instance<LoggingBloc>()),
      ],
      child: MaterialApp(
        title: 'SmartNet Firmware Loader',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        initialRoute: AppRoutes.splash,
        routes: AppRoutes.routes,
      ),
    );
  }
}