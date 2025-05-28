import 'package:get_it/get_it.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:esp_firmware_tool/data/repositories/socket_repository.dart';
import 'package:esp_firmware_tool/data/services/log_service.dart';
import 'package:esp_firmware_tool/presentation/blocs/device/device_bloc.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';
import 'package:esp_firmware_tool/presentation/blocs/settings/settings_bloc.dart';
import 'package:esp_firmware_tool/utils/app_config.dart';

final GetIt serviceLocator = GetIt.instance;

void setupServiceLocator() {
  // Register Socket.IO client with configuration from AppConfig
  serviceLocator.registerLazySingleton<IO.Socket>(() => IO.io(
        AppConfig.socketUrl,
        IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setTimeout(AppConfig.socketTimeout)
          .setReconnectionAttempts(AppConfig.socketReconnectAttempts)
          .build()
      ));

  // Register repositories
  serviceLocator.registerLazySingleton<ISocketRepository>(
      () => SocketRepository(serviceLocator<IO.Socket>()));

  // Register services
  serviceLocator.registerLazySingleton<LogService>(() => LogService());

  // Register BLoCs
  serviceLocator.registerFactory<DeviceBloc>(
      () => DeviceBloc(socketRepository: serviceLocator<ISocketRepository>()));

  serviceLocator.registerFactory<LogBloc>(
      () => LogBloc(logService: serviceLocator<LogService>()));

  serviceLocator.registerFactory<SettingsBloc>(() => SettingsBloc());
}