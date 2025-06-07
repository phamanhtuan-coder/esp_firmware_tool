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
  await windowManager.waitUntilReadyToShow();

  const minSize = Size(1280, 800);

  await Future.wait([
    windowManager.setMinimumSize(minSize),
    windowManager.center(),
    windowManager.setPreventClose(true),
    windowManager.setSkipTaskbar(false),
    windowManager.setTitle('SmartNet Firmware Loader'),
    windowManager.setTitleBarStyle(TitleBarStyle.normal),
    windowManager.setBackgroundColor(Colors.transparent),
    windowManager.setHasShadow(true),
  ]);

  // Maximize window at startup
  await windowManager.maximize();
  await windowManager.show();
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
  runApp(const MyApp());
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

        // Show loading overlay
        if (navigatorKey.currentContext != null) {
          showDialog(
            context: navigatorKey.currentContext!,
            barrierDismissible: false,
            builder: (context) => const LoadingOverlay(
              isLoading: true,
              message: 'Đang đóng ứng dụng...',
              child: SizedBox.shrink(),
            ),
          );
        }

        // Delay a bit to show loading overlay
        await Future.delayed(const Duration(milliseconds: 500));

        // Close the window
        await windowManager.destroy();
      }
    }
  }
}
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
  }

  Future<void> _loadThemeSettings() async {
    try {
      final themeService = GetIt.instance<ThemeService>();
      final isDark = await themeService.isDarkMode();
      if (mounted) {
        setState(() {
          _isDarkMode = isDark;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading theme settings: $e');
      if (mounted) {
        setState(() {
          _isDarkMode = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

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
        themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
