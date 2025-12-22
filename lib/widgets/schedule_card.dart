import 'package:flutter/material.dart';
import 'package:tlucalendar/features/schedule/data/models/course_model.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course_hour.dart';

class ScheduleCard extends StatelessWidget {
  final CourseModel course;
  final CourseHour? startHour;
  final CourseHour? endHour;
  final VoidCallback? onTap;

  const ScheduleCard({
    super.key,
    required this.course,
    this.startHour,
    this.endHour,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Format times if available
    final startTimeStr = startHour?.startString ?? '??:??';
    final endTimeStr = endHour?.endString ?? '??:??';

    // Parse hours/minutes for the large display if possible
    String hourDisplay = '--';
    String minuteDisplay = '--';

    if (startHour != null) {
      final parts = startHour!.startString.split(':');
      if (parts.length == 2) {
        hourDisplay = parts[0];
        minuteDisplay = parts[1];
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primaryContainer.withOpacity(0.85),
                colorScheme.primaryContainer.withOpacity(0.75),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ⏰ TIME - Left Side (Compact & Highlighted)
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.onPrimaryContainer.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colorScheme.onPrimaryContainer.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Start time in HH:MM format
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: hourDisplay,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: colorScheme.onPrimaryContainer,
                                    fontSize: 22,
                                  ),
                            ),
                            TextSpan(
                              text: ':',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: colorScheme.onPrimaryContainer,
                                    fontSize: 22,
                                  ),
                            ),
                            TextSpan(
                              text: minuteDisplay,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: colorScheme.onPrimaryContainer,
                                    fontSize: 22,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      // Thin divider
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Container(
                          height: 0.8,
                          width: 28,
                          color: colorScheme.onPrimaryContainer.withOpacity(
                            0.2,
                          ),
                        ),
                      ),
                      // End time - compact
                      Text(
                        'đến $endTimeStr',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer.withOpacity(
                            0.7,
                          ),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Course Details - Right Side (Compact)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Course name - single line
                      Text(
                        course.courseName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      // Course code and location - compact row
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            course.courseCode,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colorScheme.onPrimaryContainer
                                      .withOpacity(0.65),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                          ),
                          const SizedBox(width: 8),
                          // Location - compact
                          Icon(
                            Icons.location_on,
                            size: 13,
                            color: colorScheme.onPrimaryContainer.withOpacity(
                              0.6,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              course.room,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colorScheme.onPrimaryContainer
                                        .withOpacity(0.65),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
