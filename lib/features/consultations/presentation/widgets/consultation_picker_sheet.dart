import 'package:flutter/material.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/forms/app_search_field.dart';
import '../../../../shared/widgets/sheets/app_bottom_sheet.dart';
import 'consultation_picker_custom_field.dart';

/// Modal bottom sheet widget for picking Doctor, Hospital, or Department.
class ConsultationPickerSheet extends StatefulWidget {
  final String title;
  final String placeholderHint;
  final List<String> options;
  final String? currentValue;
  final ValueChanged<String> onSelected;

  const ConsultationPickerSheet({
    super.key,
    required this.title,
    this.placeholderHint = 'Search or add new...',
    required this.options,
    required this.currentValue,
    required this.onSelected,
  });

  static void show({
    required BuildContext context,
    required String title,
    String placeholderHint = 'Search or add new...',
    required List<String> options,
    required String? currentValue,
    required ValueChanged<String> onSelected,
  }) {
    AppBottomSheet.show<void>(
      context: context,
      builder: (context) {
        return ConsultationPickerSheet(
          title: title,
          placeholderHint: placeholderHint,
          options: options,
          currentValue: currentValue,
          onSelected: onSelected,
        );
      },
    );
  }

  @override
  State<ConsultationPickerSheet> createState() =>
      _ConsultationPickerSheetState();
}

class _ConsultationPickerSheetState extends State<ConsultationPickerSheet> {
  late final TextEditingController _searchController;
  late final TextEditingController _addNewController;

  String _searchQuery = '';
  bool _isAddingNew = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _addNewController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _addNewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchQuery.toLowerCase();
    final filteredOptions = q.isEmpty
        ? widget.options
        : widget.options.where((opt) => opt.toLowerCase().contains(q)).toList();

    return AppBottomSheet(
      title: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSearchField(
            controller: _searchController,
            hintText: widget.placeholderHint,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            onClear: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          ),
          const SizedBox(height: 12),
          if (_isAddingNew)
            ConsultationPickerCustomField(
              controller: _addNewController,
              onCancel: () {
                _addNewController.clear();
                setState(() => _isAddingNew = false);
              },
              onSave: (val) {
                widget.onSelected(val);
                Navigator.of(context).pop();
              },
            )
          else
            OutlinedButton.icon(
              onPressed: () => setState(() => _isAddingNew = true),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add New Custom Option'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          const SizedBox(height: 12),
          filteredOptions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No matching results found.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : SizedBox(
                  height: 280,
                  child: ListView.separated(
                    itemCount: filteredOptions.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Theme.of(context).dividerColor,
                    ),
                    itemBuilder: (context, index) {
                      final item = filteredOptions[index];
                      final isSelected = widget.currentValue == item;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        title: Text(
                          item,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                                size: 22,
                              )
                            : Icon(
                                Icons.circle_outlined,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                size: 20,
                              ),
                        onTap: () {
                          widget.onSelected(item);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}
