import 'package:smart_net_firmware_loader/data/services/bluetooth_server.dart';
import 'package:smart_net_firmware_loader/data/services/qr_code_service.dart';
import 'package:get_it/get_it.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:smart_net_firmware_loader/data/services/arduino_cli_service.dart';
import 'package:smart_net_firmware_loader/data/services/usb_service.dart';
import 'package:smart_net_firmware_loader/data/services/template_service.dart';
import 'package:smart_net_firmware_loader/data/services/batch_service.dart';
import 'package:smart_net_firmware_loader/data/services/serial_monitor_service.dart';
import 'package:smart_net_firmware_loader/data/services/firmware_flash_service.dart';
import 'package:smart_net_firmware_loader/data/services/api_client.dart';
import 'package:smart_net_firmware_loader/data/services/device_status_service.dart';
import 'package:smart_net_firmware_loader/presentation/blocs/log/log_bloc.dart';
import 'package:smart_net_firmware_loader/data/services/planning_service.dart';

final GetIt serviceLocator = GetIt.instance;

void setupServiceLocator() {
  // Core services - independent services that don't have dependencies
  serviceLocator.registerLazySingleton<LogService>(() => LogService());
  serviceLocator.registerLazySingleton<ArduinoCliService>(() => ArduinoCliService());
  serviceLocator.registerLazySingleton<UsbService>(() => UsbService());
  serviceLocator.registerLazySingleton<SerialMonitorService>(() => SerialMonitorService());

  // Register API client
  serviceLocator.registerLazySingleton<ApiClient>(() => ApiClient());

  // Services with dependencies
  serviceLocator.registerLazySingleton<TemplateService>(() => TemplateService(
    logService: serviceLocator<LogService>(),
  ));

  serviceLocator.registerLazySingleton<BatchService>(() => BatchService(
    logService: serviceLocator<LogService>(),
    arduinoCliService: serviceLocator<ArduinoCliService>(),
  ));

  // Device status service
  serviceLocator.registerLazySingleton<DeviceStatusService>(() => DeviceStatusService(
    apiClient: serviceLocator<ApiClient>(),
    logService: serviceLocator<LogService>(),
  ));

  // FirmwareFlashService depends on multiple services
  serviceLocator.registerLazySingleton<FirmwareFlashService>(() => FirmwareFlashService(
    serviceLocator<ArduinoCliService>(),
    serviceLocator<TemplateService>(),
    serviceLocator<BatchService>(),
    serviceLocator<UsbService>(),
  ));

  // Bluetooth server service
  serviceLocator.registerLazySingleton<BluetoothServer>(() => BluetoothServer(
    logService: serviceLocator<LogService>(),
  ));

  // QR Code service
  serviceLocator.registerLazySingleton<QrCodeService>(() => QrCodeService(
    logService: serviceLocator<LogService>(),
    bluetoothServer: serviceLocator<BluetoothServer>(),
  ));

  // Planning service
  serviceLocator.registerLazySingleton<PlanningService>(() => PlanningService(
    apiClient: serviceLocator<ApiClient>(),
    logService: serviceLocator<LogService>(),
  ));

  // Bloc registration
  serviceLocator.registerFactory<LogBloc>(() => LogBloc());
}

