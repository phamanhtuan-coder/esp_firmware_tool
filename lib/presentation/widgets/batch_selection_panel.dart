import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';
import 'package:smart_net_firmware_loader/core/config/app_config.dart';
import 'package:smart_net_firmware_loader/data/models/batch.dart';
import 'package:smart_net_firmware_loader/data/models/planning.dart';
import 'package:smart_net_firmware_loader/domain/blocs/home_bloc.dart';

class BatchSelectionPanel extends StatelessWidget {
  final List<Planning> plannings;
  final List<Batch> batches;
  final String? selectedPlanningId;
  final String? selectedBatchId;
  final Function(String?) onPlanningSelected;
  final Function(String?) onBatchSelected;
  final bool? isDarkTheme;
  final bool isLoading;

  const BatchSelectionPanel({
    super.key,
    required this.plannings,
    required this.batches,
    required this.selectedPlanningId,
    required this.selectedBatchId,
    required this.onPlanningSelected,
    required this.onBatchSelected,
    this.isDarkTheme,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDarkTheme =
        isDarkTheme ?? Theme.of(context).brightness == Brightness.dark;

    // Filter batches to only show ones belonging to selected planning
    final filteredBatches = selectedPlanningId != null
        ? batches.where((batch) => batch.planningId == selectedPlanningId).toList()
        : [];

    // Only set batch value if it exists in filtered list
    final effectiveSelectedBatchId = filteredBatches.any((b) => b.id == selectedBatchId)
        ? selectedBatchId
        : null;

    return Padding(
      padding: const EdgeInsets.all(AppConfig.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Planning dropdown section
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
              Stack(
                children: [
                  DropdownButtonFormField<String?>(
                    value: plannings.any((p) => p.id == selectedPlanningId)
                        ? selectedPlanningId
                        : null,
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
                      suffixIcon: isLoading
                          ? Container(
                              margin: const EdgeInsets.all(8),
                              width: 20,
                              height: 20,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : null,
                    ),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                    dropdownColor: AppColors.componentBackground,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    items: plannings.map((planning) {
                      return DropdownMenuItem<String?>(
                        value: planning.id,
                        child: Text(planning.id),
                      );
                    }).toList(),
                    onChanged: isLoading ? null : (value) {
                      // Reset batch selection when planning changes
                      if (value != selectedPlanningId) {
                        onBatchSelected(null);
                      }
                      onPlanningSelected(value);
                    },
                    hint: Text(
                      '-- Chọn kế hoạch sản xuất --',
                      style: TextStyle(
                        color: effectiveDarkTheme ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Batch dropdown section
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
              Stack(
                children: [
                  DropdownButtonFormField<String?>(
                    value: effectiveSelectedBatchId,
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
                      enabled: selectedPlanningId != null && !isLoading,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      fillColor: AppColors.componentBackground,
                      filled: true,
                      suffixIcon: isLoading
                          ? Container(
                              margin: const EdgeInsets.all(8),
                              width: 20,
                              height: 20,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : null,
                    ),
                    onTap: selectedPlanningId != null && !isLoading
                        ? () {
                            final homeBloc = context.read<HomeBloc>();
                            homeBloc.add(FetchBatchesEvent());
                          }
                        : null,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                    dropdownColor: AppColors.componentBackground,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    isExpanded: true,
                    items: filteredBatches.map((batch) {
                      return DropdownMenuItem<String?>(
                        value: batch.id,
                        child: Text(batch.name),
                      );
                    }).toList(),
                    onChanged: (selectedPlanningId != null && !isLoading)
                        ? onBatchSelected
                        : null,
                    hint: Text(
                      selectedPlanningId != null
                          ? '-- Chọn lô sản xuất --'
                          : 'Vui lòng chọn kế hoạch trước',
                      style: TextStyle(
                        color: effectiveDarkTheme ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
