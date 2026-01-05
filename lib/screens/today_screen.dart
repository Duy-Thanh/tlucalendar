import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tlucalendar/providers/auth_provider.dart';
import 'package:tlucalendar/providers/schedule_provider.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course.dart';
import 'package:tlucalendar/widgets/empty_state_widget.dart';
import 'package:tlucalendar/widgets/schedule_skeleton.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

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

    // Update every minute (sufficient for class status updates)
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final now = DateTime.now();
      if (now.day != _currentDate.day ||
          now.month != _currentDate.month ||
          now.year != _currentDate.year ||
          now.minute != _currentDate.minute) {
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Chào buổi sáng';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dayName = _getDayOfWeek(today.weekday);
    final dateFormat = '$dayName, ${today.day}/${today.month}';

    return Consumer2<AuthProvider, ScheduleProvider>(
      builder: (context, authProvider, scheduleProvider, _) {
        if (!authProvider.isLoggedIn) {
          return const Center(
            child: EmptyStateWidget(
              icon: Icons.lock_outlined,
              title: 'Vui lòng đăng nhập',
              description: 'Đăng nhập để xem lịch học của bạn',
              lottieAsset: 'assets/lottie/login_required.json',
            ),
          );
        }

        if (scheduleProvider.isLoading) {
          return const Scaffold(
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: ScheduleSkeleton(),
              ),
            ),
          );
        }

        final activeCourses = scheduleProvider.getActiveCourses(today);
        // todayWeekIndex logic handled inside getActiveCourses
        final todaySchedules = activeCourses;
        todaySchedules.sort(
          (a, b) => a.startCourseHour.compareTo(b.startCourseHour),
        );

        final userName =
            authProvider.currentUser?.fullName.split(' ').last ?? 'bạn';

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                if (authProvider.accessToken != null &&
                    scheduleProvider.currentSemester != null) {
                  await scheduleProvider.loadSchedule(
                    authProvider.accessToken!,
                    scheduleProvider.currentSemester!.id,
                  );
                }
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // Reconnecting Banner
                  if (scheduleProvider.isReconnecting)
                    Container(
                      width: double.infinity,
                      color: Colors.blue.shade100,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Đang thử kết nối lại...',
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Offline Banner
                  if (scheduleProvider.isOfflineMode)
                    Container(
                      width: double.infinity,
                      color: Colors.orange.shade100,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_off,
                            size: 16,
                            color: Colors.orange.shade800,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mất kết nối. Đang hiển thị lịch đã lưu.',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Greeting Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_getGreeting()}, $userName!',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          todaySchedules.isEmpty
                              ? 'Hôm nay bạn được nghỉ ngơi thoải mái!'
                              : 'Hôm nay chiến ${todaySchedules.length} môn nhé.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),

                  // Date Chip
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          dateFormat,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Timeline List or Empty State
                  if (todaySchedules.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: EmptyStateWidget(
                        icon: Icons.weekend_outlined,
                        title: 'Không có lớp hôm nay',
                        description: 'Dành thời gian cho bản thân nhé!',
                        lottieAsset: 'assets/lottie/relax.json',
                      ),
                    )
                  else
                    AnimationLimiter(
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        itemCount: todaySchedules.length,
                        itemBuilder: (context, index) {
                          final course = todaySchedules[index];
                          final isLast = index == todaySchedules.length - 1;
                          final status = _getCourseStatus(
                            scheduleProvider,
                            course,
                          );

                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 375),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: _buildTimelineItem(
                                  context,
                                  scheduleProvider,
                                  course,
                                  isLast,
                                  status,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24), // Bottom padding
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    ScheduleProvider scheduleProvider,
    Course course,
    bool isLast,
    _CourseStatus status,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeRange = _getTimeRange(scheduleProvider, course);
    final startTime = timeRange.split('\n')[0];

    Color cardColor;
    Color contentColor;
    Color borderColor = Colors.transparent;
    double elevation = 0;
    bool isCurrent = false;

    switch (status) {
      case _CourseStatus.past:
        cardColor = colorScheme.surfaceContainerHighest.withOpacity(0.5);
        contentColor = colorScheme.onSurfaceVariant.withOpacity(0.7);
        break;
      case _CourseStatus.current:
        cardColor = colorScheme.primaryContainer;
        contentColor = colorScheme.onPrimaryContainer;
        borderColor = colorScheme.primary;
        elevation = 4;
        isCurrent = true;
        break;
      case _CourseStatus.future:
        cardColor = colorScheme.surfaceContainerLow;
        contentColor = colorScheme.onSurface;
        borderColor = colorScheme.outlineVariant.withOpacity(0.5);
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Column
          SizedBox(
            width: 50,
            child: Column(
              children: [
                Text(
                  startTime,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isCurrent
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(color: colorScheme.surface, width: 2)
                        : null,
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
              ],
            ),
          ),

          // Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _PulseWrapper(
                isPulsing: isCurrent,
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                    boxShadow: elevation > 0
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                0.05,
                              ), // Fixed shadow color
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                course.courseName,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: contentColor,
                                    ),
                              ),
                            ),
                            if (isCurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Đang học',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colorScheme.onPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              )
                            else if (status == _CourseStatus.past)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer
                                      .withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Đã học',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colorScheme.onSecondaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.room,
                              size: 16,
                              color: status == _CourseStatus.current
                                  ? contentColor.withOpacity(0.8)
                                  : colorScheme.outline,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                course.room.isNotEmpty
                                    ? course.room
                                    : 'Chưa có phòng',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: status == _CourseStatus.current
                                          ? contentColor.withOpacity(0.9)
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 100),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  course.courseCode,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: status == _CourseStatus.current
                                            ? contentColor.withOpacity(0.7)
                                            : colorScheme.outline,
                                        fontSize: 10,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  _CourseStatus _getCourseStatus(
    ScheduleProvider scheduleProvider,
    Course course,
  ) {
    if (scheduleProvider.courseHours.isEmpty) return _CourseStatus.future;

    final startHour = scheduleProvider.courseHours
        .where((h) => h.indexNumber == course.startCourseHour)
        .firstOrNull;
    final endHour = scheduleProvider.courseHours
        .where((h) => h.indexNumber == course.endCourseHour)
        .firstOrNull;

    if (startHour == null || endHour == null) return _CourseStatus.future;

    final now = DateTime.now();
    // Parse "HH:mm"
    final startParts = startHour.startString.split(':');
    final endParts = endHour.endString.split(':');

    final startTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(startParts[0]),
      int.parse(startParts[1]),
    );
    final endTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(endParts[0]),
      int.parse(endParts[1]),
    );

    if (now.isAfter(endTime)) {
      return _CourseStatus.past;
    } else if (now.isAfter(startTime) && now.isBefore(endTime)) {
      return _CourseStatus.current;
    } else {
      return _CourseStatus.future;
    }
  }

  String _getDayOfWeek(int weekday) {
    const days = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    if (weekday >= 1 && weekday <= 7) return days[weekday - 1];
    return '';
  }

  String _getTimeRange(ScheduleProvider scheduleProvider, Course course) {
    if (scheduleProvider.courseHours.isEmpty) {
      return 'Tiết ${course.startCourseHour}\nTiết ${course.endCourseHour}';
    }

    final startHour = scheduleProvider.courseHours
        .where((h) => h.indexNumber == course.startCourseHour)
        .firstOrNull;
    final endHour = scheduleProvider.courseHours
        .where((h) => h.indexNumber == course.endCourseHour)
        .firstOrNull;

    if (startHour != null && endHour != null) {
      return '${startHour.startString}\n${endHour.endString}';
    }
    return 'Tiết ${course.startCourseHour}\nTiết ${course.endCourseHour}';
  }
}

enum _CourseStatus { past, current, future }

class _PulseWrapper extends StatefulWidget {
  final Widget child;
  final bool isPulsing;

  const _PulseWrapper({required this.child, this.isPulsing = false});

  @override
  State<_PulseWrapper> createState() => _PulseWrapperState();
}

class _PulseWrapperState extends State<_PulseWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.isPulsing) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_PulseWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing != oldWidget.isPulsing) {
      if (widget.isPulsing) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPulsing) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(scale: _scaleAnimation.value, child: child);
      },
      child: widget.child,
    );
  }
}
