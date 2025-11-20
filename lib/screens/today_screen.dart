import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tlucalendar/providers/user_provider.dart';
import 'package:tlucalendar/widgets/empty_state_widget.dart';
import 'package:tlucalendar/models/api_response.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late DateTime _currentDate;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentDate = DateTime.now();
    
    // Update every second to keep the date fresh
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      // Only rebuild if the date actually changed
      if (now.day != _currentDate.day || 
          now.month != _currentDate.month || 
          now.year != _currentDate.year) {
        setState(() {
          _currentDate = now;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = _currentDate;
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced time block on the left
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.surface,
                    colorScheme.surfaceContainerHighest,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    timeRange.split('\n')[0], // Start time
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.3,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 2,
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.primary.withOpacity(0.3),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    timeRange.split('\n')[1], // End time
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Enhanced course details on the right
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.courseName,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      letterSpacing: 0.1,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      course.courseCode,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(
                          Icons.location_on,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          course.building.isNotEmpty
                              ? '${course.room}-${course.building}'
                              : course.room,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
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
