import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_net_firmware_loader/core/config/app_routes.dart';
import 'package:smart_net_firmware_loader/core/config/app_theme.dart';
import 'package:smart_net_firmware_loader/data/services/api_client.dart';
import 'package:smart_net_firmware_loader/data/services/app_lifecycle_service.dart';
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

import 'data/services/auth_guard_service.dart';
import 'data/services/auth_service.dart';



final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<AppState> appKey = GlobalKey<AppState>();

Future<void> setupServiceLocator() async {
  final getIt = GetIt.instance;
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);
  getIt.registerSingleton<LogService>(LogService());
  getIt.registerSingleton<ThemeService>(ThemeService(prefs));
  getIt.registerSingleton<AuthService>(AuthService(prefs));
  getIt.registerSingleton<ApiService>(ApiService());
  getIt.registerSingleton<ArduinoService>(ArduinoService());
  getIt.registerSingleton<BluetoothService>(BluetoothService()); // Updated service
  getIt.registerSingleton<SerialMonitorService>(SerialMonitorService());
  getIt.registerSingleton<TemplateService>(TemplateService(logService: getIt<LogService>()));
  getIt.registerSingleton<LoggingBloc>(LoggingBloc());
  getIt.registerFactory<HomeBloc>(() => HomeBloc());
  getIt.registerSingleton<AuthGuardService>(AuthGuardService(getIt<AuthService>()));
}

void setupDependencies() {
  // Add AuthGuardService
  final authService = GetIt.instance<AuthService>();
  final authGuard = AuthGuardService(authService);
  GetIt.instance.registerSingleton<AuthGuardService>(authGuard);

  // Register HomeBloc as factory, but LoggingBloc is already registered as singleton
  GetIt.instance.registerFactory<HomeBloc>(() => HomeBloc());
}

Future<void> setupWindow() async {
  try {
    // Basic window setup first
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1600, 900),
      minimumSize: Size(1600, 900),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(windowOptions);
    await windowManager.setPreventClose(true);
    await windowManager.setTitle('SmartNet Firmware Loader');
    await windowManager.setHasShadow(true);

    // Show window
    await windowManager.show();

    // Center and maximize after showing
    await Future.delayed(const Duration(milliseconds: 200));
    await windowManager.maximize();
  } catch (e) {
    debugPrint('Error in setupWindow: $e');
    try {
      // Fallback to basic window show
      await windowManager.show();
    } catch (e) {
      debugPrint('Critical error showing window: $e');
    }
  }
}

void main() async {
  try {
    debugPrint('Starting app initialization...');

    // 1. Initialize Flutter bindings first
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('Flutter bindings initialized');

    // 2. Setup error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('Flutter error: ${details.exception}');
      debugPrintStack(stackTrace: details.stack);
    };
    debugPrint('Error handling setup complete');

    // 3. Initialize window manager
    await windowManager.ensureInitialized();
    debugPrint('Window manager initialized');

    // 4. Initialize services first to ensure they're ready
    debugPrint('Initializing services...');
    await setupServiceLocator();
    debugPrint('Services initialized');

    // 5. Create and run the app before showing window
    debugPrint('Running app...');
    runApp(const MyApp());
    debugPrint('App running');

    // 6. Add close handler
    windowManager.addListener(CloseWindowListener());
    debugPrint('Close handler added');

    // 7. Finally setup and show window
    debugPrint('Setting up window...');
    await Future.delayed(const Duration(milliseconds: 100));
    await setupWindow();
    debugPrint('Window setup complete');

  } catch (e, stackTrace) {
    debugPrint('Critical error starting app: $e');
    debugPrintStack(stackTrace: stackTrace);

    // Show error screen if startup fails
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Ứng dụng khởi động thất bại',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 8),
              Text(
                'Lỗi: $e',
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center
              ),
            ],
          ),
        ),
      ),
    ));
  }
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
        initialRoute: AppRoutes.splash,
        routes: AppRoutes.routes,
        onGenerateRoute: AppRoutes.onGenerateRoute,
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

        try {
          // Cleanup services in proper order
          final getIt = GetIt.instance;

          // Close connection-based services first
          if (getIt.isRegistered<SerialMonitorService>()) {
            try {
              final service = getIt<SerialMonitorService>();
              if (service.toString().contains('dispose')) {
                (service as dynamic).dispose();
              }
            } catch (e) {
              debugPrint('Error disposing SerialMonitorService: $e');
            }
          }

          if (getIt.isRegistered<BluetoothService>()) {
            try {
              final service = getIt<BluetoothService>();
              if (service.toString().contains('dispose')) {
                (service as dynamic).dispose();
              }
            } catch (e) {
              debugPrint('Error disposing BluetoothService: $e');
            }
          }

          if (getIt.isRegistered<ArduinoService>()) {
            try {
              final service = getIt<ArduinoService>();
              if (service.toString().contains('dispose')) {
                (service as dynamic).dispose();
              }
            } catch (e) {
              debugPrint('Error disposing ArduinoService: $e');
            }
          }

          // Then close other services
          if (getIt.isRegistered<LogService>()) {
            try {
              final service = getIt<LogService>();
              if (service.toString().contains('dispose')) {
                (service as dynamic).dispose();
              }
            } catch (e) {
              debugPrint('Error disposing LogService: $e');
            }
          }

          if (getIt.isRegistered<ApiService>()) {
            try {
              final service = getIt<ApiService>();
              if (service.toString().contains('dispose')) {
                (service as dynamic).dispose();
              }
            } catch (e) {
              debugPrint('Error disposing ApiService: $e');
            }
          }

          // Wait a bit to ensure UI is updated
          await Future.delayed(const Duration(milliseconds: 100));

          // Finally reset service locator
          await GetIt.instance.reset();
        } catch (e) {
          debugPrint('Error during cleanup: $e');
          // Continue with window destroy even if cleanup fails
        }

        // Finally destroy the window
        await windowManager.destroy();
      }
    }
  }
}
