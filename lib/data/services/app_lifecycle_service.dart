import 'package:get_it/get_it.dart';
import 'package:smart_net_firmware_loader/core/utils/debug_logger.dart';
import 'package:smart_net_firmware_loader/data/models/log_entry.dart';
import 'package:smart_net_firmware_loader/data/services/auth_service.dart';
import 'package:smart_net_firmware_loader/data/services/bluetooth_service.dart';
import 'package:smart_net_firmware_loader/data/services/log_service.dart';
import 'package:smart_net_firmware_loader/data/services/serial_monitor_service.dart';
import 'package:smart_net_firmware_loader/domain/blocs/home_bloc.dart';
import 'package:smart_net_firmware_loader/domain/blocs/logging_bloc.dart';

/// Service responsible for managing application lifecycle events like login and logout
class AppLifecycleService {
  final GetIt _getIt;

  AppLifecycleService(this._getIt);

  /// Safely handles user logout by resetting services instead of disposing them
  Future<void> handleLogout() async {
    try {
      print('Starting safe logout procedure...');

      // First stop any active services that might be sending logs
      if (_getIt.isRegistered<SerialMonitorService>()) {
        try {
          final serialMonitorService = _getIt<SerialMonitorService>();
          serialMonitorService.stopMonitor();
          print('Stopped serial monitor service');
        } catch (e) {
          print('Error stopping serial monitor service: $e');
        }
      }

      // Stop bluetooth service
      if (_getIt.isRegistered<BluetoothService>()) {
        try {
          final bluetoothService = _getIt<BluetoothService>();
          await bluetoothService.stop();
          print('Stopped bluetooth service');
        } catch (e) {
          print('Error stopping bluetooth service: $e');
        }
      }

      // Reset blocks instead of disposing them
      if (_getIt.isRegistered<LoggingBloc>()) {
        try {
          final loggingBloc = _getIt<LoggingBloc>();
          loggingBloc.reset();
          print('Reset LoggingBloc');

          // Add a system log that user has logged out - AFTER resetting the bloc
          if (_getIt.isRegistered<LogService>()) {
            final logService = _getIt<LogService>();
            logService.addLog(
              message: 'Người dùng đã đăng xuất khỏi ứng dụng',
              level: LogLevel.info,
              step: ProcessStep.systemEvent,
              origin: 'system',
            );
          }
        } catch (e) {
          print('Error resetting LoggingBloc: $e');
        }
      }

      // Clear authentication tokens
      if (_getIt.isRegistered<AuthService>()) {
        try {
          final authService = _getIt<AuthService>();
          await authService.clearToken();
          print('Cleared authentication tokens');
        } catch (e) {
          print('Error clearing authentication tokens: $e');
        }
      }

      // Log the successful logout to console
      print('Successfully completed logout procedure');
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  /// Perform necessary cleanup when application exits
  Future<void> handleAppExit() async {
    try {
      print('Starting application exit cleanup...');

      // Close all resources that need proper closing
      if (_getIt.isRegistered<SerialMonitorService>()) {
        try {
          final serialMonitorService = _getIt<SerialMonitorService>();
          serialMonitorService.dispose();
          print('Disposed serial monitor service');
        } catch (e) {
          print('Error disposing serial monitor service: $e');
        }
      }

      if (_getIt.isRegistered<BluetoothService>()) {
        try {
          final bluetoothService = _getIt<BluetoothService>();
          await bluetoothService.stop();
          print('Stopped bluetooth service');
        } catch (e) {
          print('Error stopping bluetooth service: $e');
        }
      }

      if (_getIt.isRegistered<LogService>()) {
        try {
          final logService = _getIt<LogService>();
          logService.dispose();
          print('Disposed log service');
        } catch (e) {
          print('Error disposing log service: $e');
        }
      }

      // Only close the bloc when exiting the app, not during logout/login cycle
      if (_getIt.isRegistered<LoggingBloc>()) {
        try {
          final loggingBloc = _getIt<LoggingBloc>();
          await loggingBloc.close();
          print('Closed LoggingBloc');
        } catch (e) {
          print('Error closing LoggingBloc: $e');
        }
      }

      print('Successfully completed application exit cleanup');
    } catch (e) {
      print('Error during application exit: $e');
    }
  }

  /// Prepare the application after login
  Future<void> handleAfterLogin() async {
    try {
      print('Initializing services after login...');

      // Reset LoggingBloc instead of recreating it
      if (_getIt.isRegistered<LoggingBloc>()) {
        try {
          final loggingBloc = _getIt<LoggingBloc>();
          loggingBloc.reset();

          // Log successful login
          if (_getIt.isRegistered<LogService>()) {
            final logService = _getIt<LogService>();
            logService.addLog(
              message: 'Đăng nhập thành công',
              level: LogLevel.success,
              step: ProcessStep.systemEvent,
              origin: 'system',
            );
          }

          print('Reset LoggingBloc for new session');
        } catch (e) {
          print('Error resetting LoggingBloc after login: $e');
        }
      }

      print('Successfully initialized services after login');
    } catch (e) {
      print('Error during after-login initialization: $e');
    }
  }
}
