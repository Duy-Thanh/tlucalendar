import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tlucalendar/providers/schedule_provider.dart';
import 'package:tlucalendar/widgets/empty_state_widget.dart';
import 'package:tlucalendar/widgets/schedule_card.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateFormat = 'Thứ ${_getDayOfWeek(today.weekday)}, Ngày ${today.day}/${today.month}/${today.year}';

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          elevation: 0,
          title: const Text('Hôm nay'),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Chip(
                  label: Text(dateFormat),
                  avatar: Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        Consumer<ScheduleProvider>(
          builder: (context, scheduleProvider, _) {
            final todaySchedules = scheduleProvider.todaySchedules;

            if (todaySchedules.isEmpty) {
              return SliverFillRemaining(
                child: EmptyStateWidget(
                  icon: Icons.school_outlined,
                  title: 'Không có lớp hôm nay',
                  description: 'Hãy tận hưởng ngày của bạn!',
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return ScheduleCard(
                    schedule: todaySchedules[index],
                    onTap: () {
                      // TODO: Navigate to schedule details
                    },
                  );
                },
                childCount: todaySchedules.length,
              ),
            );
          },
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 20),
        ),
      ],
    );
  }

  String _getDayOfWeek(int weekday) {
    const days = ['', 'hai', 'ba', 'tư', 'năm', 'sáu', 'bảy'];
    return weekday < days.length ? days[weekday] : '';
  }
}
