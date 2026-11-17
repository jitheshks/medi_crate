import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../vitals/presentation/providers/measurement_providers.dart';
import '../../../vitals/presentation/screens/measurements_list_screen.dart';
import '../../data/models/timeline_event_model.dart';
import 'timeline_connector.dart';
import 'timeline_event_badge.dart';

/// Reusable Timeline Event card item widget.
class TimelineEventCard extends ConsumerWidget {
  final TimelineEventModel event;
  final bool showTopLine;
  final bool showBottomLine;
  final VoidCallback? onTap;

  const TimelineEventCard({
    super.key,
    required this.event,
    this.showTopLine = true,
    this.showBottomLine = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formattedDate = event.eventDate != null
        ? DateFormat('d MMM yyyy').format(event.eventDate!)
        : 'No date';
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label:
          '${event.title}, ${event.badgeText}, $formattedDate, ${event.summary}',
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Timeline Rail Node Connector
            TimelineConnector(
              icon: event.icon,
              color: event.color,
              showTopLine: showTopLine,
              showBottomLine: showBottomLine,
            ),
            const SizedBox(width: 12),

            // Right Event Content Card
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: colorScheme.outline),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x05000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    onTap:
                        onTap ??
                        () async {
                          if (event.type == 'measurement') {
                            final activeProfile = ref.read(
                              activeProfileProvider,
                            );
                            final measurementId = event.targetId.isNotEmpty
                                ? event.targetId
                                : event.id;
                            if (activeProfile != null) {
                              final repo = ref.read(
                                measurementRepositoryProvider,
                              );
                              final item = await repo.getMeasurementById(
                                activeProfile.profileId,
                                measurementId,
                              );
                              if (item != null && context.mounted) {
                                showMeasurementDetailSheet(context, ref, item);
                                return;
                              }
                            }
                            if (context.mounted) {
                              context.pushGuarded(AppRoutes.measurements);
                            }
                            return;
                          }

                          if (event.targetRoute.isNotEmpty) {
                            try {
                              context.pushGuarded(event.targetRoute);
                            } catch (_) {
                              context.pushGuarded(AppRoutes.timeline);
                            }
                          }
                        },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Top Badge & Date Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: TimelineEventBadge(
                                  text: event.badgeText,
                                  color: event.color,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formattedDate,
                                style: AppTypography.caption.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Title
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                              fontSize: 15,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Summary description
                          Text(
                            event.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
