import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../data/models/profile_model.dart';
import '../providers/profile_providers.dart';
import 'profile_avatar.dart';
import 'profile_delete_helper.dart';
import 'profile_form_dialog.dart';

class FamilyProfileCard extends ConsumerWidget {
  final ProfileModel profile;
  final bool isActive;

  const FamilyProfileCard({
    super.key,
    required this.profile,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? colorScheme.primary : colorScheme.outline,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(profile: profile, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.fullName,
                            style: AppTypography.h3.copyWith(
                              color: colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile.isPrimary) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.semanticColors.favoriteStar
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 12,
                                  color: context.semanticColors.favoriteStar,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'PRIMARY',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: context.semanticColors.favoriteStar,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Relationship: ${profile.displayRelationship}',
                      style: AppTypography.caption.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (action) {
                  if (action == 'edit') {
                    ProfileFormDialog.show(context, profileToEdit: profile);
                  } else if (action == 'make_primary') {
                    ref
                        .read(profilesListProvider.notifier)
                        .markAsPrimary(profile);
                  } else if (action == 'delete') {
                    ProfileDeleteHelper.confirmDelete(context, ref, profile);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Edit Profile'),
                      ],
                    ),
                  ),
                  if (!profile.isPrimary) ...[
                    const PopupMenuItem(
                      value: 'make_primary',
                      child: Row(
                        children: [
                          Icon(Icons.star_outline, size: 18),
                          SizedBox(width: 8),
                          Text('Mark Primary'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: colorScheme.error,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete Profile',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (profile.gender != null)
                _buildInfoChip(context, 'Gender: ${profile.gender}'),
              if (profile.dateOfBirth != null)
                _buildInfoChip(context, 'DOB: ${profile.dateOfBirth}'),
              if (profile.bloodGroup != null)
                _buildInfoChip(context, 'Blood Group: ${profile.bloodGroup}'),
            ],
          ),
          if (profile.notes != null && profile.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Notes: ${profile.notes}',
              style: AppTypography.caption.copyWith(
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ACTIVE PROFILE',
                        style: AppTypography.caption.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                TextButton(
                  onPressed: () {
                    ref
                        .read(activeProfileProvider.notifier)
                        .selectProfile(profile);
                  },
                  child: const Text('Switch to Profile'),
                ),
              OutlinedButton.icon(
                onPressed: () =>
                    ProfileFormDialog.show(context, profileToEdit: profile),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.outline.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          fontSize: 11,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
