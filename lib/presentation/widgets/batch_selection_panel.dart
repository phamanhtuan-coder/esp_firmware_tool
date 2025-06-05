import 'package:flutter/material.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';
import 'package:smart_net_firmware_loader/core/config/app_config.dart';
import 'package:smart_net_firmware_loader/data/models/batch.dart';
import 'package:smart_net_firmware_loader/data/models/planning.dart';

class BatchSelectionPanel extends StatelessWidget {
  final List<Planning> plannings;
  final List<Batch> batches;
  final String? selectedPlanningId;
  final String? selectedBatchId;
  final Function(String?) onPlanningSelected;
  final Function(String?) onBatchSelected;
  final bool? isDarkTheme;

  const BatchSelectionPanel({
    super.key,
    required this.plannings,
    required this.batches,
    required this.selectedPlanningId,
    required this.selectedBatchId,
    required this.onPlanningSelected,
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
          // Planning Selection
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kế hoạch sản xuất',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: effectiveDarkTheme ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String?>(
                value: selectedPlanningId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  fillColor: effectiveDarkTheme
                      ? AppColors.darkCardBackground
                      : AppColors.cardBackground,
                  filled: true,
                ),
                dropdownColor: effectiveDarkTheme
                    ? AppColors.darkCardBackground
                    : AppColors.cardBackground,
                style: TextStyle(
                  color: effectiveDarkTheme ? Colors.white : Colors.black87,
                ),
                items: plannings.map((planning) {
                  return DropdownMenuItem<String?>(
                    value: planning.id,
                    child: Text(planning.name ?? 'Unnamed Planning'),
                  );
                }).toList(),
                onChanged: onPlanningSelected,
                hint: const Text('-- Chọn kế hoạch sản xuất --'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Batch Selection
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lô sản xuất',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: effectiveDarkTheme ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String?>(
                value: selectedBatchId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  fillColor: effectiveDarkTheme
                      ? AppColors.darkCardBackground
                      : AppColors.cardBackground,
                  filled: true,
                  enabled: selectedPlanningId != null,
                ),
                dropdownColor: effectiveDarkTheme
                    ? AppColors.darkCardBackground
                    : AppColors.cardBackground,
                style: TextStyle(
                  color: effectiveDarkTheme ? Colors.white : Colors.black87,
                ),
                items: batches.map((batch) {
                  return DropdownMenuItem<String?>(
                    value: batch.id,
                    child: Text(batch.name),
                  );
                }).toList(),
                onChanged: selectedPlanningId != null ? onBatchSelected : null,
                hint: Text(
                  selectedPlanningId != null
                      ? '-- Chọn lô sản xuất --'
                      : 'Vui lòng chọn kế hoạch trước',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
