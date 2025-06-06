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
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  fillColor: AppColors.componentBackground,
                  filled: true,
                ),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                dropdownColor: AppColors.componentBackground,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                items:
                    plannings.map((planning) {
                      return DropdownMenuItem<String?>(
                        value: planning.id,
                        child: Text(planning.name ?? 'Unnamed Planning'),
                      );
                    }).toList(),
                onChanged: onPlanningSelected,
                hint: Text(
                  '-- Chọn kế hoạch sản xuất --',
                  style: TextStyle(
                    color:
                        effectiveDarkTheme
                            ? Colors.grey[400]
                            : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  enabled: selectedPlanningId != null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  fillColor: AppColors.componentBackground,
                  filled: true,
                ),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                dropdownColor: AppColors.componentBackground,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                isExpanded: true,
                items:
                    batches.map((batch) {
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
                  style: TextStyle(
                    color:
                        effectiveDarkTheme
                            ? Colors.grey[400]
                            : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
