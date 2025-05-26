import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'presentation/blocs/device/device_bloc.dart';
import 'presentation/views/home_view.dart';
import 'data/repositories/socket_repository.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => DeviceBloc(
            socketRepository: SocketRepository(
              IO.io('http://your-fe-server', IO.OptionBuilder().setTransports(['websocket']).build()),
            ),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'ESP Firmware Tool',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: HomeView(),
      ),
    );
  }
}