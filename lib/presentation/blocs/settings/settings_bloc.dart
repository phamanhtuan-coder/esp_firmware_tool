import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  // Constants for SharedPreferences keys
  static const String _socketUrlKey = 'socket_url';
  static const String _pythonScriptPathKey = 'python_script_path';

  SettingsBloc() : super(const SettingsState()) {
    on<LoadSettingsEvent>(_onLoadSettings);
    on<UpdateSettingsEvent>(_onUpdateSettings);
    on<SaveSettingsEvent>(_onSaveSettings);

    // Load settings when bloc is created
    add(const LoadSettingsEvent());
  }

  Future<void> _onLoadSettings(
    LoadSettingsEvent event,
    Emitter<SettingsState> emit
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final socketUrl = prefs.getString(_socketUrlKey) ?? '';
      final pythonScriptPath = prefs.getString(_pythonScriptPathKey) ?? '';

      emit(state.copyWith(
        socketUrl: socketUrl,
        pythonScriptPath: pythonScriptPath,
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to load settings: $e'));
    }
  }

  void _onUpdateSettings(
    UpdateSettingsEvent event,
    Emitter<SettingsState> emit
  ) {
    emit(state.copyWith(
      socketUrl: event.socketUrl,
      pythonScriptPath: event.pythonScriptPath,
      errorMessage: null,
    ));
  }

  Future<void> _onSaveSettings(
    SaveSettingsEvent event,
    Emitter<SettingsState> emit
  ) async {
    emit(state.copyWith(isSaving: true, errorMessage: null));

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_socketUrlKey, state.socketUrl);
      await prefs.setString(_pythonScriptPathKey, state.pythonScriptPath);

      emit(state.copyWith(isSaving: false));
    } catch (e) {
      emit(state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save settings: $e',
      ));
    }
  }
}