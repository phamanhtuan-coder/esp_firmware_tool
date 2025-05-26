import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class FilePickerButton extends StatelessWidget {
  final void Function(String?) onFilePicked;
  final String label;
  const FilePickerButton({super.key, required this.onFilePicked, required this.label});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () async {
        FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
        if (result != null && result.files.single.path != null) {
          onFilePicked(result.files.single.path);
        } else {
          onFilePicked(null);
        }
      },
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
      child: Text(label, style: const TextStyle(fontSize: 15)),
    );
  }
}