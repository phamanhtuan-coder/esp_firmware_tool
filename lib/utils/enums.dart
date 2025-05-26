import 'package:flutter/material.dart';

enum DeviceStatus { connected, compiling, flashing, done, error }

extension DeviceStatusExtension on DeviceStatus {
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
        return Colors.blue;
      case DeviceStatus.compiling:
        return Colors.orange;
      case DeviceStatus.flashing:
        return Colors.purple;
      case DeviceStatus.done:
        return Colors.green;
      case DeviceStatus.error:
        return Colors.red;
    }
  }
}