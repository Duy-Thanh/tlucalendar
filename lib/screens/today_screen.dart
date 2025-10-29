import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tlucalendar/providers/user_provider.dart';
import 'package:tlucalendar/widgets/empty_state_widget.dart';
import 'package:tlucalendar/models/api_response.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dayName = _getDayOfWeek(today.weekday);
    final dateFormat =
        '$dayName, Ngày ${today.day}/${today.month}/${today.year}';

    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        // Show login prompt if not logged in
        if (!userProvider.isLoggedIn) {
          return Center(
            child: EmptyStateWidget(
              icon: Icons.lock_outlined,
              title: 'Vui lòng đăng nhập',
              description: 'Đăng nhập để xem lịch học của bạn',
            ),
          );
        }

        // Get today's courses
        final todayWeekIndex = today.weekday + 1;
        final activeCourses = userProvider.getActiveCourses(today);
        final todaySchedules =
            activeCourses
                .where((course) => course.dayOfWeek == todayWeekIndex)
                .toList()
              ..sort((a, b) => a.startCourseHour.compareTo(b.startCourseHour));

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Text(
                    'Hôm nay',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Date chip
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateFormat,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Course list
                Expanded(
                  child: todaySchedules.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.school_outlined,
                          title: 'Không có lớp hôm nay',
                          description: 'Hãy tận hưởng ngày nghỉ của bạn!',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: todaySchedules.length,
                          itemBuilder: (context, index) {
                            return _buildCourseCard(
                              context,
                              userProvider,
                              todaySchedules[index],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCourseCard(
    BuildContext context,
    UserProvider userProvider,
    StudentCourseSubject course,
  ) {
    final timeRange = _getTimeRange(userProvider, course);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time block on the left
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    timeRange.split('\n')[0], // Start time
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 2,
                    height: 8,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeRange.split('\n')[1], // End time
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Course details on the right
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.courseName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    course.courseCode,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          course.building.isNotEmpty
                              ? '${course.room}-${course.building}'
                              : course.room,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.6),
                              ),
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
    );
  }

  String _getDayOfWeek(int weekday) {
    // Monday = 1, Sunday = 7
    // In Vietnamese: Monday-Saturday use "Thứ" prefix, Sunday is just "Chủ Nhật"
    const days = [
      'Thứ Hai', // Monday (1)
      'Thứ Ba', // Tuesday (2)
      'Thứ Tư', // Wednesday (3)
      'Thứ Năm', // Thursday (4)
      'Thứ Sáu', // Friday (5)
      'Thứ Bảy', // Saturday (6)
      'Chủ Nhật', // Sunday (7)
    ];
    if (weekday >= 1 && weekday <= 7) {
      return days[weekday - 1];
    }
    return '';
  }

  String _getTimeRange(UserProvider userProvider, StudentCourseSubject course) {
    final startHour = userProvider.courseHours[course.startCourseHour];
    final endHour = userProvider.courseHours[course.endCourseHour];

    if (startHour != null && endHour != null) {
      return '${startHour.startString}\n${endHour.endString}';
    }

    return 'Tiết ${course.startCourseHour}\nTiết ${course.endCourseHour}';
  }
}
