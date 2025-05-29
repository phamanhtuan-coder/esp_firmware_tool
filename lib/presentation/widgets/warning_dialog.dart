import 'package:flutter/material.dart';

class WarningDialog extends StatelessWidget {
  final bool isDarkTheme;
  final VoidCallback onCancel;
  final VoidCallback onContinue;
  final String title;
  final String message;

  const WarningDialog({
    super.key,
    required this.isDarkTheme,
    required this.onCancel,
    required this.onContinue,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onCancel,
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkTheme ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDarkTheme ? Colors.yellow[500] : Colors.yellow[600],
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(message),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('Hủy'),
                    ),
                    ElevatedButton(
                      onPressed: onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow[600],
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Tiếp tục'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}