import 'package:equatable/equatable.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class UpdateSettingsEvent extends SettingsEvent {
  final String? socketUrl;
  final String? pythonScriptPath;

  const UpdateSettingsEvent({this.socketUrl, this.pythonScriptPath});

  @override
  List<Object?> get props => [socketUrl, pythonScriptPath];
}

class SaveSettingsEvent extends SettingsEvent {
  const SaveSettingsEvent();
}

class LoadSettingsEvent extends SettingsEvent {
  const LoadSettingsEvent();
}