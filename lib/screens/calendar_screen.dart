import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tlucalendar/providers/user_provider.dart';
import 'package:tlucalendar/widgets/empty_state_widget.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDate;
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _focusedMonth = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
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
                'Lịch học',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Semester selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: _buildSemesterSelector(context),
            ),
            // Month/Year selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: _buildMonthSelector(context),
            ),
            // Calendar Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCalendarGrid(context),
            ),
            const SizedBox(height: 16),
            // Courses for selected day
            Expanded(child: _buildDayCourses(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildSemesterSelector(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        if (userProvider.schoolYears == null) {
          return const SizedBox.shrink();
        }

        // Get all semesters from all school years
        final allSemesters = userProvider.schoolYears!.content
            .expand((year) => year.semesters)
            .toList();

        if (allSemesters.isEmpty) {
          return const SizedBox.shrink();
        }

        final colorScheme = Theme.of(context).colorScheme;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primaryContainer.withOpacity(0.6),
                colorScheme.secondaryContainer.withOpacity(0.4),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: userProvider.selectedSemester?.id,
              isExpanded: true,
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: colorScheme.primary,
                ),
              ),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
              dropdownColor: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              items: allSemesters.map((semester) {
                final isSelected = semester.id == userProvider.selectedSemester?.id;
                return DropdownMenuItem<int>(
                  value: semester.id,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primaryContainer.withOpacity(0.5)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.check_circle,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                          ),
                        Flexible(
                          child: Text(
                            semester.semesterName,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (semester.isCurrent) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.tertiary,
                                  colorScheme.tertiary.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Hiện tại',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onTertiary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (semesterId) async {
                if (semesterId != null) {
                  final semester = allSemesters.firstWhere(
                    (s) => s.id == semesterId,
                  );
                  await userProvider.selectSemester(semester);
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthSelector(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${_focusedMonth.month}/${_focusedMonth.year}',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  _focusedMonth = DateTime(
                    _focusedMonth.year,
                    _focusedMonth.month - 1,
                  );
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  _focusedMonth = DateTime(
                    _focusedMonth.year,
                    _focusedMonth.month + 1,
                  );
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final firstDayOfMonth = DateTime(
          _focusedMonth.year,
          _focusedMonth.month,
          1,
        );
        final lastDayOfMonth = DateTime(
          _focusedMonth.year,
          _focusedMonth.month + 1,
          0,
        );
        final daysInMonth = lastDayOfMonth.day;
        final firstWeekday = firstDayOfMonth.weekday;
        final previousMonthDays = firstWeekday - 1;

        return Column(
          children: [
            // Weekday headers
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  Expanded(
                    child: Center(
                      child: Text(
                        'T2',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'T3',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'T4',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'T5',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'T6',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'T7',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'CN',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Calendar grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: daysInMonth + previousMonthDays,
              itemBuilder: (context, index) {
                if (index < previousMonthDays) {
                  final prevMonth = DateTime(
                    _focusedMonth.year,
                    _focusedMonth.month,
                    0,
                  );
                  final day = prevMonth.day - previousMonthDays + index + 1;
                  return Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.3),
                      ),
                    ),
                  );
                }

                final day = index - previousMonthDays + 1;
                final date = DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month,
                  day,
                );
                final isSelected =
                    date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;
                final isToday =
                    date.year == DateTime.now().year &&
                    date.month == DateTime.now().month &&
                    date.day == DateTime.now().day;

                // Check if this day has courses
                final activeCourses = userProvider.getActiveCourses(date);
                final dayWeekIndex = date.weekday + 1;
                final hasCourses = activeCourses.any(
                  (c) => c.dayOfWeek == dayWeekIndex,
                );

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : isToday
                          ? Theme.of(
                              context,
                            ).colorScheme.primaryContainer.withOpacity(0.3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isToday && !isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '$day',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: isSelected || isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                        ),
                        if (hasCourses)
                          Positioned(
                            bottom: 4,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer
                                      : Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDayCourses(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        if (!userProvider.isLoggedIn) {
          return EmptyStateWidget(
            icon: Icons.lock_outlined,
            title: 'Vui lòng đăng nhập',
            description: 'Đăng nhập để xem lịch học của bạn',
          );
        }

        // Show loading indicator while fetching courses
        if (userProvider.isLoadingCourses) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Đang tải lịch học...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          );
        }

        // Get courses for selected date
        final activeCourses = userProvider.getActiveCourses(_selectedDate);

        final dayWeekIndex = _selectedDate.weekday + 1;

        final dayCourses =
            activeCourses.where((c) => c.dayOfWeek == dayWeekIndex).toList()
              ..sort((a, b) => a.startCourseHour.compareTo(b.startCourseHour));

        if (dayCourses.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.event_available_outlined,
            title: 'Không có lớp',
            description: 'Chọn một ngày khác để xem lịch học',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: dayCourses.length,
          itemBuilder: (context, index) {
            return _buildCourseCard(context, userProvider, dayCourses[index]);
          },
        );
      },
    );
  }

  Widget _buildCourseCard(
    BuildContext context,
    UserProvider userProvider,
    course,
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
            // Enhanced time block
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
                    timeRange.split('\n')[0],
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
                    timeRange.split('\n')[1],
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
            // Enhanced course details
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

  String _getTimeRange(UserProvider userProvider, course) {
    final startHour = userProvider.courseHours[course.startCourseHour];
    final endHour = userProvider.courseHours[course.endCourseHour];

    if (startHour != null && endHour != null) {
      return '${startHour.startString}\n${endHour.endString}';
    }

    return 'Tiết ${course.startCourseHour}\nTiết ${course.endCourseHour}';
  }
}
