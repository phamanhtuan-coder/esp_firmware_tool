import 'package:get_it/get_it.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../data/repositories/socket_repository.dart';
import '../presentation/blocs/device/device_bloc.dart';

final GetIt serviceLocator = GetIt.instance;

void setupServiceLocator() {
  // Register Socket.IO client
  serviceLocator.registerLazySingleton<IO.Socket>(() => IO.io(
      'http://your-fe-server',
      IO.OptionBuilder().setTransports(['websocket']).build()));

  // Register repositories
  serviceLocator.registerLazySingleton<ISocketRepository>(
      () => SocketRepository(serviceLocator<IO.Socket>()));

  // Register BLoCs
  serviceLocator.registerFactory<DeviceBloc>(
      () => DeviceBloc(socketRepository: serviceLocator<ISocketRepository>()));
}