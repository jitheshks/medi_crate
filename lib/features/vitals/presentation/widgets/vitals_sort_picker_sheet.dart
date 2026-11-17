import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/sheets/app_bottom_sheet.dart';

void showVitalsSortPickerSheet(
  BuildContext context, {
  required String currentSortOrder,
  required ValueChanged<String> onSortOrderSelected,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  AppBottomSheet.show<void>(
    context: context,
    builder: (context) {
      return AppBottomSheet(
        title: 'Sort Measurements',
        showCloseButton: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: const Text('Newest first'),
              trailing: currentSortOrder == 'Newest first'
                  ? Icon(Icons.check, color: colorScheme.primary)
                  : null,
              onTap: () {
                onSortOrderSelected('Newest first');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: const Text('Oldest first'),
              trailing: currentSortOrder == 'Oldest first'
                  ? Icon(Icons.check, color: colorScheme.primary)
                  : null,
              onTap: () {
                onSortOrderSelected('Oldest first');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.numbers),
              title: const Text('Highest value'),
              trailing: currentSortOrder == 'Highest value'
                  ? Icon(Icons.check, color: colorScheme.primary)
                  : null,
              onTap: () {
                onSortOrderSelected('Highest value');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    },
  );
}
