import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/di/service_locator.dart';
import 'package:esp_firmware_tool/presentation/blocs/device/device_bloc.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';
import 'package:esp_firmware_tool/presentation/blocs/settings/settings_bloc.dart';
import 'package:esp_firmware_tool/presentation/views/home_view.dart';
import 'package:esp_firmware_tool/presentation/views/device_list_view.dart';
import 'package:esp_firmware_tool/presentation/views/log_view.dart';
import 'package:esp_firmware_tool/presentation/views/settings_view.dart';
import 'package:esp_firmware_tool/utils/app_routes.dart';
import 'package:esp_firmware_tool/utils/app_theme.dart';

void main() {
  // Initialize dependency injection
  setupServiceLocator();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DeviceBloc>(
          create: (context) => serviceLocator<DeviceBloc>(),
        ),
        BlocProvider<LogBloc>(
          create: (context) => serviceLocator<LogBloc>(),
        ),
        BlocProvider<SettingsBloc>(
          create: (context) => serviceLocator<SettingsBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'ESP Firmware Tool',
        theme: AppTheme.lightTheme,
        home: const HomeView(),
        routes: {
          AppRoutes.deviceList: (context) => const DeviceListView(),
          AppRoutes.logs: (context) => const LogView(deviceId: ''),
          AppRoutes.settings: (context) => const SettingsView(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}