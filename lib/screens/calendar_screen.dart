import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tlucalendar/providers/schedule_provider.dart';
import 'package:tlucalendar/providers/user_provider.dart';
import 'package:tlucalendar/widgets/empty_state_widget.dart';
import 'package:tlucalendar/widgets/schedule_card.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          elevation: 0,
          title: const Text('Lịch học'),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildCalendarHeader(context),
          ),
        ),
        Consumer<UserProvider>(
          builder: (context, userProvider, _) {
            // Show login prompt if not logged in
            if (!userProvider.isLoggedIn) {
              return SliverFillRemaining(
                child: EmptyStateWidget(
                  icon: Icons.lock_outlined,
                  title: 'Vui lòng đăng nhập',
                  description: 'Đăng nhập để xem lịch học của bạn',
                ),
              );
            }

            return Consumer<ScheduleProvider>(
              builder: (context, scheduleProvider, _) {
                final schedulesForDate = scheduleProvider.schedules
                    .where((s) =>
                        s.startTime.year == _selectedDate.year &&
                        s.startTime.month == _selectedDate.month &&
                        s.startTime.day == _selectedDate.day)
                    .toList()
                  ..sort((a, b) => a.startTime.compareTo(b.startTime));

                if (schedulesForDate.isEmpty) {
                  return SliverFillRemaining(
                    child: EmptyStateWidget(
                      icon: Icons.event_busy_outlined,
                      title: 'Không có lớp',
                      description: 'Chọn một ngày khác để xem lịch học',
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return ScheduleCard(
                        schedule: schedulesForDate[index],
                        onTap: () {
                          // TODO: Navigate to schedule details
                        },
                      );
                    },
                    childCount: schedulesForDate.length,
                  ),
                );
              },
            );
          },
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 20),
        ),
      ],
    );
  }

  Widget _buildCalendarHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = DateTime.now();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_selectedDate.month}/${_selectedDate.year}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime(
                        _selectedDate.year,
                        _selectedDate.month - 1,
                      );
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime(
                        _selectedDate.year,
                        _selectedDate.month + 1,
                      );
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: _getDaysInMonth(_selectedDate),
          itemBuilder: (context, index) {
            final day = index + 1;
            final date = DateTime(_selectedDate.year, _selectedDate.month, day);
            final isSelected = _selectedDate.day == day;
            final isToday = today.year == date.year &&
                today.month == date.month &&
                today.day == date.day;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = date;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : isToday
                          ? colorScheme.primaryContainer
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isToday && !isSelected
                      ? Border.all(color: colorScheme.primary, width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : isToday
                              ? colorScheme.primary
                              : null,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  int _getDaysInMonth(DateTime date) {
    if (date.month == 12) {
      return DateTime(date.year + 1, 1, 0).day;
    }
    return DateTime(date.year, date.month + 1, 0).day;
  }
}
