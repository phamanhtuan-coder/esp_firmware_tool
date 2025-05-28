import 'package:equatable/equatable.dart';

class SettingsState extends Equatable {
  final String socketUrl;
  final String pythonScriptPath;
  final bool isSaving;
  final String? errorMessage;

  const SettingsState({
    this.socketUrl = '',
    this.pythonScriptPath = '',
    this.isSaving = false,
    this.errorMessage,
  });

  SettingsState copyWith({
    String? socketUrl,
    String? pythonScriptPath,
    bool? isSaving,
    String? errorMessage,
  }) {
    return SettingsState(
      socketUrl: socketUrl ?? this.socketUrl,
      pythonScriptPath: pythonScriptPath ?? this.pythonScriptPath,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [socketUrl, pythonScriptPath, isSaving, errorMessage];
}