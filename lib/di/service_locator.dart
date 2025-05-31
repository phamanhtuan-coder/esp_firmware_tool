import 'package:get_it/get_it.dart';
import 'package:esp_firmware_tool/data/services/log_service.dart';
import 'package:esp_firmware_tool/data/services/arduino_cli_service.dart';
import 'package:esp_firmware_tool/data/services/usb_service.dart';
import 'package:esp_firmware_tool/data/services/template_service.dart';
import 'package:esp_firmware_tool/data/services/batch_service.dart';
import 'package:esp_firmware_tool/data/services/serial_monitor_service.dart';
import 'package:esp_firmware_tool/data/services/firmware_flash_service.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';

final GetIt serviceLocator = GetIt.instance;

void setupServiceLocator() {
  // Core services - independent services that don't have dependencies
  serviceLocator.registerLazySingleton<LogService>(() => LogService());
  serviceLocator.registerLazySingleton<ArduinoCliService>(() => ArduinoCliService());
  serviceLocator.registerLazySingleton<UsbService>(() => UsbService());
  serviceLocator.registerLazySingleton<SerialMonitorService>(() => SerialMonitorService());

  // Services with dependencies
  serviceLocator.registerLazySingleton<TemplateService>(() => TemplateService(
    logService: serviceLocator<LogService>(),
  ));

  serviceLocator.registerLazySingleton<BatchService>(() => BatchService(
    logService: serviceLocator<LogService>(),
    arduinoCliService: serviceLocator<ArduinoCliService>(),
  ));

  // FirmwareFlashService depends on multiple services
  serviceLocator.registerLazySingleton<FirmwareFlashService>(() => FirmwareFlashService(
    serviceLocator<ArduinoCliService>(),
    serviceLocator<TemplateService>(),
    serviceLocator<BatchService>(),
    serviceLocator<UsbService>(),
  ));

  // Bloc registration
  serviceLocator.registerFactory<LogBloc>(() => LogBloc());
}