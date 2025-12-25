import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:tlucalendar/providers/auth_provider.dart';
import 'package:tlucalendar/providers/schedule_provider.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course.dart';
import 'package:tlucalendar/widgets/empty_state_widget.dart';
import 'package:tlucalendar/widgets/schedule_skeleton.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDate;
  late DateTime _focusedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _focusedDay = DateTime.now();
  }

  List<Course> _getEventsForDay(
    DateTime day,
    ScheduleProvider scheduleProvider,
  ) {
    return scheduleProvider.getActiveCourses(day);
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDate, selectedDay)) {
      setState(() {
        _selectedDate = selectedDay;
        _focusedDay = focusedDay;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            _buildHeader(context),

            // Collapsible Calendar
            Consumer<ScheduleProvider>(
              builder: (context, scheduleProvider, _) {
                return _buildTableCalendar(context, scheduleProvider);
              },
            ),

            const Divider(height: 1),

            // Course List
            Expanded(child: _buildCourseList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCalendar(
    BuildContext context,
    ScheduleProvider scheduleProvider,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior
          .opaque, // Ensure gestures are caught even on empty space
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! < 0) {
          // Swipe Up -> Week
          if (_calendarFormat != CalendarFormat.week) {
            setState(() => _calendarFormat = CalendarFormat.week);
          }
        } else if (details.primaryVelocity! > 0) {
          // Swipe Down -> Month
          if (_calendarFormat != CalendarFormat.month) {
            setState(() => _calendarFormat = CalendarFormat.month);
          }
        }
      },
      child: Card(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        elevation: 8,
        shadowColor: Theme.of(context).shadowColor.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            TableCalendar<Course>(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              availableGestures: AvailableGestures.horizontalSwipe,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Tháng',
                CalendarFormat.week: 'Tuần',
              },
              rowHeight: 48, // Increased from 42 for breathability
              daysOfWeekHeight: 24, // Slightly taller header
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: Theme.of(context).textTheme.titleLarge!
                    .copyWith(
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 20, // Restore larger size
                    ),
                leftChevronIcon: Container(
                  padding: const EdgeInsets.all(8), // Restore padding
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                ),
                rightChevronIcon: Container(
                  padding: const EdgeInsets.all(8), // Restore padding
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                ),
                headerMargin: const EdgeInsets.only(
                  bottom: 12.0,
                  top: 8.0,
                  left: 8,
                  right: 8,
                ),
              ),
              selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
              onDaySelected: _onDaySelected,
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              eventLoader: (day) => _getEventsForDay(day, scheduleProvider),
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 14, // Restore font size
                ),
                defaultTextStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14, // Restore font size
                ),
                selectedDecoration: BoxDecoration(
                  color: Color(0xFFFF8A65),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(
                    Radius.circular(16),
                  ), // Rounder
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x66FF8A65),
                      blurRadius: 12, // Softer shadow
                      offset: Offset(0, 4),
                      spreadRadius: 2, // "Excessive" glow
                    ),
                  ],
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                defaultDecoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                weekendDecoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                cellMargin: EdgeInsets.all(6), // More spacing between cells
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;
                  return Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFF7C4DFF), // Deep Purple Accent
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${events.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                }
              },
            ),

            // Handle drag handle indicator
            GestureDetector(
              onTap: () {
                setState(() {
                  _calendarFormat = _calendarFormat == CalendarFormat.month
                      ? CalendarFormat.week
                      : CalendarFormat.month;
                });
              },
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity! < 0) {
                  if (_calendarFormat != CalendarFormat.week) {
                    setState(() => _calendarFormat = CalendarFormat.week);
                  }
                } else if (details.primaryVelocity! > 0) {
                  if (_calendarFormat != CalendarFormat.month) {
                    setState(() => _calendarFormat = CalendarFormat.month);
                  }
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                ), // Reduced padding
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHigh.withOpacity(0.5),
                ),
                child: Center(
                  child: Container(
                    height: 4, // Thinner handle
                    width: 32, // Smaller handle width
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lịch học',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('EEEE, d MMMM, yyyy', 'vi').format(DateTime.now()),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          _buildSemesterSelector(context),
        ],
      ),
    );
  }

  Widget _buildSemesterSelector(BuildContext context) {
    return Consumer2<ScheduleProvider, AuthProvider>(
      builder: (context, scheduleProvider, authProvider, _) {
        if (scheduleProvider.schoolYears.isEmpty) {
          return const SizedBox.shrink();
        }

        final selectedSemester = scheduleProvider.selectedSemester;

        return InkWell(
          onTap: () =>
              _showSemesterPicker(context, scheduleProvider, authProvider),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    selectedSemester?.semesterName ?? 'Chọn học kỳ',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSemesterPicker(
    BuildContext context,
    ScheduleProvider scheduleProvider,
    AuthProvider authProvider,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Chọn học kỳ',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: scheduleProvider.schoolYears.length,
                  itemBuilder: (context, index) {
                    final year = scheduleProvider.schoolYears[index];
                    return ExpansionTile(
                      title: Text(year.name),
                      children: year.semesters.map((semester) {
                        final isSelected =
                            semester.id ==
                            scheduleProvider.selectedSemester?.id;
                        return ListTile(
                          title: Text(semester.semesterName),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                          onTap: () {
                            if (authProvider.accessToken != null) {
                              scheduleProvider.selectSemester(
                                authProvider.accessToken!,
                                semester.id,
                              );
                            }
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCourseList(BuildContext context) {
    return Consumer<ScheduleProvider>(
      builder: (context, scheduleProvider, _) {
        if (scheduleProvider.isLoading) {
          return const ScheduleSkeleton();
        }

        final courses = scheduleProvider.getActiveCourses(_selectedDate);

        if (courses.isEmpty) {
          return const EmptyStateWidget(
            title: 'Không có lịch học',
            icon: Icons.event_busy,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: courses.length,
          itemBuilder: (context, index) {
            return _buildCourseCard(context, courses[index], scheduleProvider);
          },
        );
      },
    );
  }

  Widget _buildCourseCard(
    BuildContext context,
    Course course,
    ScheduleProvider scheduleProvider,
  ) {
    String startTime = '${course.startCourseHour}';
    String endTime = '${course.endCourseHour}';

    final sHourObj = scheduleProvider.courseHours
        .where((h) => h.indexNumber == course.startCourseHour)
        .firstOrNull;
    final eHourObj = scheduleProvider.courseHours
        .where((h) => h.indexNumber == course.endCourseHour)
        .firstOrNull;

    if (sHourObj != null) startTime = sHourObj.startString;
    if (eHourObj != null) endTime = eHourObj.endString;

    final timeRange = '$startTime - $endTime';

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
        left: 16,
        right: 16,
      ), // Compact margin
      elevation: 4,
      shadowColor: Theme.of(context).shadowColor.withOpacity(0.3),
      surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ), // Compact radius
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(16), // Compact padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      timeRange,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      course.room,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Calculate status
              Builder(
                builder: (context) {
                  bool isPast = false;
                  bool isCurrent = false;
                  final now = DateTime.now();
                  final isToday = isSameDay(_selectedDate, now);

                  if (_selectedDate.isBefore(
                    DateTime(now.year, now.month, now.day),
                  )) {
                    isPast = true;
                  } else if (isToday) {
                    final sHourObj = scheduleProvider.courseHours
                        .where((h) => h.indexNumber == course.startCourseHour)
                        .firstOrNull;
                    final eHourObj = scheduleProvider.courseHours
                        .where((h) => h.indexNumber == course.endCourseHour)
                        .firstOrNull;

                    if (sHourObj != null && eHourObj != null) {
                      final startParts = sHourObj.startString.split(':');
                      final endParts = eHourObj.endString.split(':');
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
                        isPast = true;
                      } else if (now.isAfter(startTime) &&
                          now.isBefore(endTime)) {
                        isCurrent = true;
                      }
                    }
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          course.courseName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                // Smaller title
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          margin: const EdgeInsets.only(left: 6, top: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Đang học',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 10,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        )
                      else if (isPast)
                        Container(
                          margin: const EdgeInsets.only(left: 6, top: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Đã học',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 10,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.tertiaryContainer,
                    child: Icon(
                      Icons.person,
                      size: 12,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    course.lecturerName ?? 'Chưa cập nhật',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
