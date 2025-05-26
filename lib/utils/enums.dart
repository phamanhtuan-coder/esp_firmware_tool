import 'package:flutter/material.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';

enum DeviceStatus {
  connected,
  compiling,
  flashing,
  done,
  error;

  String get label {
    switch (this) {
      case DeviceStatus.connected:
        return 'Connected';
      case DeviceStatus.compiling:
        return 'Compiling';
      case DeviceStatus.flashing:
        return 'Flashing';
      case DeviceStatus.done:
        return 'Done';
      case DeviceStatus.error:
        return 'Error';
    }
  }

  Color get color {
    switch (this) {
      case DeviceStatus.connected:
        return AppColors.connected;
      case DeviceStatus.compiling:
        return AppColors.compiling;
      case DeviceStatus.flashing:
        return AppColors.flashing;
      case DeviceStatus.done:
        return AppColors.done;
      case DeviceStatus.error:
        return AppColors.error;
    }
  }

  IconData get icon {
    switch (this) {
      case DeviceStatus.connected:
        return Icons.check_circle_outline;
      case DeviceStatus.compiling:
        return Icons.memory;
      case DeviceStatus.flashing:
        return Icons.flash_on;
      case DeviceStatus.done:
        return Icons.check_circle;
      case DeviceStatus.error:
        return Icons.error_outline;
    }
  }
}