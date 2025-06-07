import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/core/config/app_routes.dart';
import 'package:smart_net_firmware_loader/core/config/app_theme.dart';
import 'package:smart_net_firmware_loader/data/services/api_client.dart';
import 'package:smart_net_firmware_loader/data/services/arduino_service.dart';
import 'package:smart_net_firmware_loader/data/services/bluetooth_service.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:smart_net_firmware_loader/data/services/serial_monitor_service.dart';
import 'package:smart_net_firmware_loader/data/services/template_service.dart';
import 'package:smart_net_firmware_loader/domain/blocs/home_bloc.dart';
import 'package:smart_net_firmware_loader/domain/blocs/logging_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:window_manager/window_manager.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void setupServiceLocator() {
  final getIt = GetIt.instance;
  getIt.registerSingleton<LogService>(LogService());
  getIt.registerSingleton<ApiService>(ApiService());
  getIt.registerSingleton<ArduinoService>(ArduinoService());
  getIt.registerSingleton<BluetoothService>(BluetoothService());
  getIt.registerSingleton<SerialMonitorService>(SerialMonitorService());
  getIt.registerSingleton<TemplateService>(TemplateService(logService: GetIt.instance<LogService>()));
  getIt.registerFactory<HomeBloc>(() => HomeBloc());
  getIt.registerFactory<LoggingBloc>(() => LoggingBloc());
}

Future<void> setupWindow() async {
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow();

  // Configure window settings
  await windowManager.setSize(const Size(1600, 900));
  await windowManager.setMinimumSize(const Size(1280, 720));
  await windowManager.center();
  await windowManager.setPreventClose(true);
  await windowManager.setSkipTaskbar(false);
  await windowManager.setTitle('SmartNet Firmware Loader');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow();

  // Configure window settings
  await windowManager.setSize(const Size(1280, 800));
  await windowManager.setMinimumSize(const Size(1024, 768));
  await windowManager.center();
  await windowManager.setPreventClose(true);
  await windowManager.setSkipTaskbar(false);
  await windowManager.setTitle('SmartNet Firmware Loader');

  // Add close handler
  windowManager.addListener(CloseWindowListener());

  // Register dependencies
  setupServiceLocator();

  // Run app
  runApp(const MyApp());
}

Future<bool> showCloseConfirmationDialog() async {
  return await showDialog(
    context: navigatorKey.currentContext!,
    builder: (context) => AlertDialog(
      title: const Text('Thoát ứng dụng?'),
      content: const Text('Bạn có muốn thoát ứng dụng?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Thoát'),
        ),
      ],
    ),
  ) ?? false;
}

class CloseWindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      bool shouldClose = await showCloseConfirmationDialog();
      if (shouldClose) {
        await windowManager.destroy();
      }
    }
  }
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return MultiBlocProvider(
      providers: [
        BlocProvider<HomeBloc>(
          create: (context) => GetIt.instance<HomeBloc>(),
        ),
        BlocProvider<LoggingBloc>(
          create: (context) => GetIt.instance<LoggingBloc>(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'SmartNet Firmware Loader',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );


  }


}
