import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../blocs/settings/settings.dart';
import '../widgets/rounded_button.dart';
import '../../utils/app_colors.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final TextEditingController _socketUrlController = TextEditingController();
  final TextEditingController _pythonScriptPathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize the controllers with the current values from the bloc
    final settingsState = context.read<SettingsBloc>().state;
    _socketUrlController.text = settingsState.socketUrl;
    _pythonScriptPathController.text = settingsState.pythonScriptPath;
  }

  @override
  void dispose() {
    _socketUrlController.dispose();
    _pythonScriptPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.primary,
      ),
      body: BlocConsumer<SettingsBloc, SettingsState>(
        listener: (context, state) {
          // Show snackbar if there's an error
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          } else if (!state.isSaving && _socketUrlController.text.isNotEmpty) {
            // Show success message when save is complete and we have a URL
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Settings saved successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }

          // Update controllers if the state changes from elsewhere
          if (_socketUrlController.text != state.socketUrl) {
            _socketUrlController.text = state.socketUrl;
          }
          if (_pythonScriptPathController.text != state.pythonScriptPath) {
            _pythonScriptPathController.text = state.pythonScriptPath;
          }
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Socket.IO Server URL',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _socketUrlController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. http://localhost:3000',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    context.read<SettingsBloc>().add(UpdateSettingsEvent(socketUrl: value));
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Python Script Path',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pythonScriptPathController,
                        decoration: const InputDecoration(
                          hintText: 'Path to process.py',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (value) {
                          context.read<SettingsBloc>().add(
                                UpdateSettingsEvent(pythonScriptPath: value),
                              );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.folder_open),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['py'],
                          dialogTitle: 'Select Python Script',
                        );
                        if (result != null) {
                          final path = result.files.single.path;
                          if (path != null) {
                            _pythonScriptPathController.text = path;
                            context.read<SettingsBloc>().add(
                                  UpdateSettingsEvent(pythonScriptPath: path),
                                );
                          }
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Center(
                  child: RoundedButton(
                    label: 'Save Settings',
                    color: AppColors.primary,
                    onPressed: () {
                      context.read<SettingsBloc>().add(const SaveSettingsEvent());
                    },
                    enabled: !state.isSaving,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}