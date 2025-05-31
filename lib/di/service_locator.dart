import 'package:get_it/get_it.dart';
import 'package:esp_firmware_tool/data/services/log_service.dart';
import 'package:esp_firmware_tool/data/services/arduino_cli_service.dart';
import 'package:esp_firmware_tool/data/services/usb_service.dart';
import 'package:esp_firmware_tool/data/services/template_service.dart';
import 'package:esp_firmware_tool/data/services/batch_service.dart';
import 'package:esp_firmware_tool/data/services/serial_monitor_service.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';

final GetIt serviceLocator = GetIt.instance;

void setupServiceLocator() {
  serviceLocator.registerLazySingleton<ArduinoCliService>(() => ArduinoCliService());
  serviceLocator.registerLazySingleton<UsbService>(() => UsbService());
  serviceLocator.registerLazySingleton<LogService>(() => LogService());
  serviceLocator.registerLazySingleton<SerialMonitorService>(() => SerialMonitorService());
  serviceLocator.registerLazySingleton<TemplateService>(() => TemplateService(
    logService: serviceLocator<LogService>(),
  ));
  serviceLocator.registerLazySingleton<BatchService>(() => BatchService(
    logService: serviceLocator<LogService>(),
    arduinoCliService: serviceLocator<ArduinoCliService>(),
  ));
  serviceLocator.registerFactory<LogBloc>(() => LogBloc());
}