import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_net_firmware_loader/core/config/app_routes.dart';
import 'package:smart_net_firmware_loader/core/config/app_theme.dart';
import 'package:smart_net_firmware_loader/data/services/api_client.dart';
import 'package:smart_net_firmware_loader/data/services/arduino_service.dart';
import 'package:smart_net_firmware_loader/data/services/bluetooth_service.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:smart_net_firmware_loader/data/services/serial_monitor_service.dart';
import 'package:smart_net_firmware_loader/data/services/template_service.dart';
import 'package:smart_net_firmware_loader/data/services/theme_service.dart';
import 'package:smart_net_firmware_loader/domain/blocs/home_bloc.dart';
import 'package:smart_net_firmware_loader/domain/blocs/logging_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/loading_overlay.dart';
import 'package:smart_net_firmware_loader/presentation/widgets/warning_dialog.dart';
import 'package:window_manager/window_manager.dart';



final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<AppState> appKey = GlobalKey<AppState>();

Future<void> setupServiceLocator() async {
  final getIt = GetIt.instance;

  // Initialize SharedPreferences first
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);

  // Register ThemeService immediately after SharedPreferences
  getIt.registerSingleton<ThemeService>(ThemeService(prefs));

  // Register other services
  getIt.registerSingleton<LogService>(LogService());
  getIt.registerSingleton<ApiService>(ApiService());
  getIt.registerSingleton<ArduinoService>(ArduinoService());
  getIt.registerSingleton<BluetoothService>(BluetoothService());
  getIt.registerSingleton<SerialMonitorService>(SerialMonitorService());

  // Register services that depend on other services
  getIt.registerSingleton<TemplateService>(
    TemplateService(logService: getIt<LogService>()),
  );

  // Register blocs
  getIt.registerSingleton<LoggingBloc>(LoggingBloc());
  getIt.registerFactory<HomeBloc>(() => HomeBloc());
}

Future<void> setupWindow() async {
  await windowManager.ensureInitialized();

  // Set window properties first
  await Future.wait([
    windowManager.setPreventClose(true),
    windowManager.setSkipTaskbar(false),
    windowManager.setTitle('SmartNet Firmware Loader'),
    windowManager.setTitleBarStyle(TitleBarStyle.normal),
    windowManager.setBackgroundColor(Colors.transparent),
    windowManager.setHasShadow(true),
    // Set minimum size constraints
    windowManager.setMinimumSize(const Size(1024, 768)),
  ]);

  // Wait for window to be ready
  await windowManager.waitUntilReadyToShow();

  // Center and show window
  await windowManager.center();
  await windowManager.show();

  // Maximize after showing
  await windowManager.maximize();
  await windowManager.focus();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services first
  await setupServiceLocator();

  // Then setup window
  await setupWindow();

  // Add close handler
  windowManager.addListener(CloseWindowListener());

  // Run app
  runApp(MyApp(key: appKey));
}

Future<bool> showCloseConfirmationDialog() async {
  return await showDialog(
    context: navigatorKey.currentContext!,
    builder: (context) => WarningDialog(
      isDarkTheme: Theme.of(context).brightness == Brightness.dark,
      onCancel: () => Navigator.pop(context, false),
      onContinue: () => Navigator.pop(context, true),
      title: 'Thoát ứng dụng?',
      message: 'Bạn có chắc chắn muốn thoát ứng dụng không?',
      type: 'warning',
    ),
  ) ?? false;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => AppState();
}

class AppState extends State<MyApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final themeService = GetIt.instance<ThemeService>();
    final isDark = await themeService.isDarkMode();
    if (mounted) {
      setState(() {
        _isDarkMode = isDark;
      });
    }
  }

  void updateTheme(bool isDark) {
    setState(() {
      _isDarkMode = isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => GetIt.instance<LoggingBloc>(),
        ),
        BlocProvider(
          create: (context) => GetIt.instance<HomeBloc>(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'SmartNet Firmware Loader',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
        initialRoute: AppRoutes.login,
        routes: AppRoutes.routes,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class CloseWindowListener extends WindowListener {
  bool _isClosing = false;

  @override
  void onWindowClose() async {
    if (_isClosing) return;

    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      bool shouldClose = await showCloseConfirmationDialog();
      if (shouldClose) {
        _isClosing = true;

        // Hide window first to improve perceived performance
        await windowManager.hide();

        if (navigatorKey.currentContext != null) {
          // Clean up resources and show loading
          Navigator.of(navigatorKey.currentContext!).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
                return FadeTransition(
                  opacity: animation,
                  child: const LoadingOverlay(
                    isLoading: true,
                    message: 'Đang đóng ứng dụng...',
                    child: SizedBox.shrink(),
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 200),
              reverseTransitionDuration: const Duration(milliseconds: 200),
            ),
            (route) => false,
          );
        }

        // Cleanup tasks
        await Future.wait([
          // Give time for the UI to update
          Future.delayed(const Duration(milliseconds: 100)),
          // Clean up any resources, close connections, etc
          GetIt.instance.reset(),
          // Add any other cleanup tasks here
        ]);

        // Finally destroy the window
        await windowManager.destroy();
      }
    }
  }
}
