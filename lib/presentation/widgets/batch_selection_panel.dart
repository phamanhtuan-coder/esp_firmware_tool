import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';
import 'package:smart_net_firmware_loader/core/config/app_config.dart';
import 'package:smart_net_firmware_loader/data/models/batch.dart';
import 'package:smart_net_firmware_loader/data/models/planning.dart';
import 'package:smart_net_firmware_loader/domain/blocs/home_bloc.dart';

class BatchSelectionPanel extends StatefulWidget {
  final List<Planning> plannings;
  final List<Batch> batches;
  final String? selectedPlanningId;
  final String? selectedBatchId;
  final Function(String?) onPlanningSelected;
  final Function(String?) onBatchSelected;
  final bool? isDarkTheme;
  final bool isLoading;
  final VoidCallback onRefreshPlannings;
  final VoidCallback onRefreshBatches;

  const BatchSelectionPanel({
    super.key,
    required this.plannings,
    required this.batches,
    required this.selectedPlanningId,
    required this.selectedBatchId,
    required this.onPlanningSelected,
    required this.onBatchSelected,
    required this.onRefreshPlannings,
    required this.onRefreshBatches,
    this.isDarkTheme,
    this.isLoading = false,
  });

  @override
  State<BatchSelectionPanel> createState() => _BatchSelectionPanelState();
}

class _BatchSelectionPanelState extends State<BatchSelectionPanel> {
  String? _pendingPlanningId;
  String? _pendingBatchId;

  @override
  void initState() {
    super.initState();
    _pendingPlanningId = widget.selectedPlanningId;
    _pendingBatchId = widget.selectedBatchId;
  }

  @override
  void didUpdateWidget(BatchSelectionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPlanningId != widget.selectedPlanningId) {
      _pendingPlanningId = widget.selectedPlanningId;
    }
    if (oldWidget.selectedBatchId != widget.selectedBatchId) {
      _pendingBatchId = widget.selectedBatchId;
    }
  }

  void _handlePlanningChange(String? value) {
    if (value == _pendingPlanningId) return;

    _pendingPlanningId = value;
    _pendingBatchId = null;

    widget.onBatchSelected(null);
    widget.onPlanningSelected(value);
  }

  void _handleBatchChange(String? value) {
    if (value == _pendingBatchId) return;

    _pendingBatchId = value;
    widget.onBatchSelected(value);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDarkTheme = widget.isDarkTheme ?? Theme.of(context).brightness == Brightness.dark;

    // Filter batches to only show ones belonging to selected planning
    final filteredBatches = _pendingPlanningId != null
        ? widget.batches.where((batch) => batch.planningId == _pendingPlanningId).toList()
        : [];

    return Padding(
      padding: const EdgeInsets.all(AppConfig.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Planning dropdown section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Kế hoạch sản xuất',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: effectiveDarkTheme ? Colors.white : Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    splashRadius: 20,
                    tooltip: 'Làm mới danh sách kế hoạch',
                    onPressed: widget.isLoading ? null : widget.onRefreshPlannings,
                    color: widget.isLoading ? Colors.grey : AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String?>(
                value: widget.plannings.any((p) => p.id == _pendingPlanningId) ? _pendingPlanningId : null,
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
                  suffixIcon: widget.isLoading
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
                items: widget.plannings.map((planning) {
                  return DropdownMenuItem<String?>(
                    value: planning.id,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 250), // Limit width
                      child: Text(
                        planning.id,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: widget.isLoading ? null : _handlePlanningChange,
                hint: Text(
                  '-- Chọn kế hoạch sản xuất --',
                  style: TextStyle(
                    color: effectiveDarkTheme ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Batch dropdown section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lô sản xuất',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: effectiveDarkTheme ? Colors.white : Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    splashRadius: 20,
                    tooltip: 'Làm mới danh sách lô sản xuất',
                    onPressed: widget.isLoading ? null : widget.onRefreshBatches,
                    color: widget.isLoading ? Colors.grey : AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String?>(
                value: filteredBatches.any((b) => b.id == _pendingBatchId) ? _pendingBatchId : null,
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
                  enabled: _pendingPlanningId != null && !widget.isLoading,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  fillColor: AppColors.componentBackground,
                  filled: true,
                  suffixIcon: widget.isLoading
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
                onTap: _pendingPlanningId != null && !widget.isLoading
                    ? () {
                        // Schedule fetch after the build phase
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final homeBloc = context.read<HomeBloc>();
                          homeBloc.add(FetchBatchesEvent());
                        });
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
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 250), // Limit width
                      child: Text(
                        batch.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (_pendingPlanningId != null && !widget.isLoading) ? _handleBatchChange : null,
                hint: Text(
                  _pendingPlanningId != null ? '-- Chọn lô sản xuất --' : 'Vui lòng chọn kế hoạch trước',
                  style: TextStyle(
                    color: effectiveDarkTheme ? Colors.grey[400] : Colors.grey[600],
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
