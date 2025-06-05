import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';
import 'package:smart_net_firmware_loader/core/config/app_config.dart';
import 'package:smart_net_firmware_loader/domain/blocs/home_bloc.dart';

class BatchSelectionPanel extends StatelessWidget {
  final List<String> batches;
  final String? selectedBatchId;
  final Function(String?) onBatchSelected;
  final bool? isDarkTheme;

  const BatchSelectionPanel({
    super.key,
    required this.batches,
    required this.selectedBatchId,
    required this.onBatchSelected,
    this.isDarkTheme,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDarkTheme =
        isDarkTheme ?? Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(AppConfig.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lô Sản Xuất',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: effectiveDarkTheme ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: selectedBatchId,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              fillColor:
                  effectiveDarkTheme
                      ? AppColors.darkCardBackground
                      : AppColors.cardBackground,
              filled: true,
            ),
            dropdownColor:
                effectiveDarkTheme
                    ? AppColors.darkCardBackground
                    : AppColors.cardBackground,
            style: TextStyle(
              color: effectiveDarkTheme ? Colors.white : Colors.black87,
            ),
            items:
                batches.map((batch) {
                  return DropdownMenuItem(value: batch, child: Text(batch));
                }).toList(),
            onChanged: (value) {
              onBatchSelected(value);
              context.read<HomeBloc>().add(SelectBatchEvent(value));
            },
            hint: const Text('-- Chọn lô sản xuất --'),
          ),
        ],
      ),
    );
  }
}
