import 'package:flutter/material.dart';

import '../../data/models/timeline_event_model.dart';
import 'timeline_date_header.dart';
import 'timeline_event_card.dart';

class TimelineGroupedListView extends StatelessWidget {
  final Map<String, List<TimelineEventModel>> groupedMap;

  const TimelineGroupedListView({super.key, required this.groupedMap});

  @override
  Widget build(BuildContext context) {
    final entriesList = groupedMap.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entriesList.map((entry) {
        final dateHeaderKey = entry.key;
        final eventsInGroup = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TimelineDateHeader(dateHeader: dateHeaderKey),
            ...eventsInGroup.asMap().entries.map((itemEntry) {
              final index = itemEntry.key;
              final event = itemEntry.value;
              final isFirstInGroup = index == 0;
              final isLastInGroup = index == eventsInGroup.length - 1;

              return TimelineEventCard(
                event: event,
                showTopLine: !isFirstInGroup,
                showBottomLine: !isLastInGroup,
              );
            }),
          ],
        );
      }).toList(),
    );
  }
}
