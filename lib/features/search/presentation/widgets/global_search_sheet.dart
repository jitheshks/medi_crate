import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import '../../../../shared/widgets/sheets/app_bottom_sheet.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/models/global_search_result.dart';
import '../providers/global_search_providers.dart';
import 'global_search_category_filter_bar.dart';
import 'global_search_result_tile.dart';

/// Modal search sheet for instant, offline, in-memory search across active profile records.
class GlobalSearchSheet extends ConsumerStatefulWidget {
  const GlobalSearchSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AppBottomSheet.show<void>(
      context: context,
      builder: (context) => const GlobalSearchSheet(),
    );
  }

  @override
  ConsumerState<GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends ConsumerState<GlobalSearchSheet> {
  late final TextEditingController _searchController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _focusNode = FocusNode();

    // Reset providers on open so search starts clean
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(globalSearchQueryProvider.notifier).state = '';
        ref.read(globalSearchCategoryFilterProvider.notifier).state = null;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(globalSearchQueryProvider.notifier).state = '';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeProfile = ref.watch(activeProfileProvider);
    final profileName = activeProfile?.fullName ?? 'Active Profile';

    final searchQuery = ref.watch(globalSearchQueryProvider);
    final selectedCategory = ref.watch(globalSearchCategoryFilterProvider);
    final results = ref.watch(globalSearchResultsProvider);

    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.90;
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final contentHeight = (sheetHeight * 0.82 - (keyboardInset * 2)).clamp(
      200.0,
      sheetHeight * 0.82,
    );

    return AppBottomSheet(
      titleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Global Health Search',
            style: AppTypography.h2.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Searching in $profileName',
            style: AppTypography.caption.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        tooltip: 'Close Search',
        icon: const Icon(Icons.close, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      child: SizedBox(
        height: contentHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input Field
            TextField(
              controller: _searchController,
              focusNode: _focusNode,
              autofocus: true,
              textInputAction: TextInputAction.search,
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search doctors, medicines, reports...',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                prefixIcon: Icon(
                  AppIcons.search,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        color: colorScheme.onSurfaceVariant,
                        tooltip: 'Clear query',
                        onPressed: _clearSearch,
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (val) {
                ref.read(globalSearchQueryProvider.notifier).state = val;
                setState(() {});
              },
            ),
            const SizedBox(height: 10),

            // Horizontal Category Filter Chips Bar
            const GlobalSearchCategoryFilterBar(),
            const SizedBox(height: 8),
            Divider(height: 1, color: colorScheme.outline),

            // Results Viewport
            Expanded(
              child: _buildResultsContent(
                context,
                searchQuery,
                selectedCategory,
                results,
                profileName,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsContent(
    BuildContext context,
    String searchQuery,
    SearchEntityType? selectedCategory,
    List<GlobalSearchResult> results,
    String profileName,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (searchQuery.trim().isEmpty) {
      return _buildInitialEmptyState(context);
    }

    if (results.isEmpty) {
      return _buildNoResultsState(context, searchQuery, profileName);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: results.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: colorScheme.outline),
      itemBuilder: (context, index) {
        final item = results[index];
        return GlobalSearchResultTile(item: item);
      },
    );
  }

  Widget _buildInitialEmptyState(BuildContext context) {
    return const AppEmptyState(
      icon: AppIcons.search,
      title: 'Search Your Health Records',
      message:
          'Instant search across doctors, hospitals, consultations, medicines, reports, appointments, and vitals.',
    );
  }

  Widget _buildNoResultsState(
    BuildContext context,
    String query,
    String profileName,
  ) {
    return AppEmptyState.filtered(
      title: 'No matches found',
      message: 'No records matching "$query" were found in $profileName.',
      onAction: _clearSearch,
      actionLabel: 'Clear Search',
    );
  }
}
