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

  // Add error handling for asset loading
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Directionality( // Adding Directionality widget to fix the error
      textDirection: TextDirection.ltr,
      child: Material(
        child: Container(
          color: Colors.white,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 60,
              ),
              const SizedBox(height: 16),
              Text(
                'Error: ${details.exception}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };

  await setupWindow(); // Initialize window settings

  // Start the app immediately with the splash screen
  runApp(const MyApp(isInitialized: false));

  // Perform other initialization tasks after the app has started
  setupServiceLocator();

  // Initialize Arduino service in the background
  final arduinoService = GetIt.instance<ArduinoService>();
  await arduinoService.initialize();

  // Update the app state when initialization is complete
  runApp(const MyApp(isInitialized: true));
}

class MyApp extends StatelessWidget {
  final bool isInitialized;

  const MyApp({super.key, this.isInitialized = false});

  @override
  Widget build(BuildContext context) {
    if (!isInitialized) {
      // Show only splash screen during initialization but include all routes
      return MaterialApp(
        title: 'SmartNet Firmware Loader',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        initialRoute: AppRoutes.splash,
        routes: AppRoutes.routes,
      );
    }

    // Full app with all providers after initialization
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => GetIt.instance<HomeBloc>(),
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