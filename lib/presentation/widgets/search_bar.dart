import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/presentation/blocs/log/log_bloc.dart';
import 'package:smart_net_firmware_loader/utils/app_colors.dart';

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
      color: isDarkTheme ? AppColors.idle : Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Find in logs...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                fillColor: isDarkTheme ? AppColors.idle : AppColors.dividerColor,
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