import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';

class SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDarkTheme;
  final VoidCallback onClose;

  const SearchBar({
    super.key,
    required this.controller,
    required this.isDarkTheme,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: isDarkTheme ? Colors.grey[850] : Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Find in logs...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                fillColor: isDarkTheme ? Colors.grey[700] : Colors.grey[100],
                filled: true,
              ),
              onChanged: (value) => context.read<LogBloc>().add(FilterLogEvent()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}