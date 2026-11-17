import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../notifications/presentation/providers/notifications_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../../profile/presentation/widgets/profile_switcher_sheet.dart';
import '../../../search/presentation/widgets/global_search_sheet.dart';
import 'account_drawer.dart';

/// DashboardAppBar renders the global Application Shell header with active profile switcher pill, avatar & action buttons.
class DashboardAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String userName;

  const DashboardAppBar({super.key, required this.userName});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProfile = ref.watch(activeProfileProvider);
    final profileName =
        activeProfile?.fullName ??
        (userName.isNotEmpty ? userName : 'My Health');
    final relationship = activeProfile?.relationship ?? 'Self';
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final hasUnread = unreadCount > 0;

    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
        child: Builder(
          builder: (avatarContext) => Semantics(
            button: true,
            label: 'Open Account Drawer',
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => AccountDrawer.show(avatarContext),
              child: activeProfile != null
                  ? ProfileAvatar(profile: activeProfile, radius: 20)
                  : CircleAvatar(
                      backgroundColor: colorScheme.primary,
                      child: Text(
                        userName.isNotEmpty
                            ? userName[0].toUpperCase()
                            : (profileName.isNotEmpty
                                  ? profileName[0].toUpperCase()
                                  : 'M'),
                        style: AppTypography.h3.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
      title: InkWell(
        onTap: () => ProfileSwitcherSheet.show(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            profileName,
                            style: AppTypography.h2.copyWith(
                              fontSize: 16,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: colorScheme.onSurface,
                        ),
                      ],
                    ),
                    Text(
                      'Profile: $relationship',
                      style: AppTypography.caption.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.outline),
          ),
          child: IconButton(
            icon: Icon(AppIcons.search, color: colorScheme.onSurface, size: 20),
            tooltip: 'Search Profile Records',
            onPressed: () => GlobalSearchSheet.show(context),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.outline),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  AppIcons.bell,
                  color: colorScheme.onSurface,
                  size: 20,
                ),
                tooltip: 'Notifications',
                onPressed: () {
                  context.pushGuarded(AppRoutes.notifications);
                },
              ),
              if (hasUnread)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
