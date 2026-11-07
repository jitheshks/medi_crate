import 'package:flutter/material.dart';
import '../../../../shared/widgets/forms/app_search_field.dart';

class ReportsSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const ReportsSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AppSearchField(
      controller: controller,
      hintText: 'Search by report, lab, doctor, or notes...',
      onChanged: onChanged,
      onClear: onClear,
    );
  }
}
