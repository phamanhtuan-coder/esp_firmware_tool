import 'package:get_it/get_it.dart';
import 'package:esp_firmware_tool/data/services/log_service.dart';
import 'package:esp_firmware_tool/data/services/arduino_cli_service.dart';
import 'package:esp_firmware_tool/data/services/usb_service.dart';
import 'package:esp_firmware_tool/data/services/template_service.dart';
import 'package:esp_firmware_tool/presentation/blocs/device/device_bloc.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';
import 'package:esp_firmware_tool/presentation/blocs/settings/settings_bloc.dart';

final GetIt serviceLocator = GetIt.instance;

void setupServiceLocator() {
  // Register services
  serviceLocator.registerLazySingleton<ArduinoCliService>(() => ArduinoCliService());
  serviceLocator.registerLazySingleton<UsbService>(() => UsbService());

  // Register TemplateService
  serviceLocator.registerLazySingleton<TemplateService>(() => TemplateService());

  // Register Log service
  serviceLocator.registerLazySingleton<LogService>(() => LogService());

  // Register BLoCs
  serviceLocator.registerFactory<DeviceBloc>(
      () => DeviceBloc(serviceLocator<ArduinoCliService>(), serviceLocator<UsbService>()));

  serviceLocator.registerFactory<LogBloc>(
      () => LogBloc(
            logService: serviceLocator<LogService>(),
            arduinoCliService: serviceLocator<ArduinoCliService>(),
            templateService: serviceLocator<TemplateService>(),
            usbService: serviceLocator<UsbService>(),
          ));

  serviceLocator.registerFactory<SettingsBloc>(() => SettingsBloc());
}