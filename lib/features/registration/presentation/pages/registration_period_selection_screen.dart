import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tlucalendar/features/schedule/domain/entities/semester_register_period.dart';
import 'package:tlucalendar/features/schedule/domain/entities/school_year.dart';
import 'package:tlucalendar/features/schedule/domain/entities/semester.dart';
import 'package:tlucalendar/providers/schedule_provider.dart';
import 'package:tlucalendar/features/registration/presentation/pages/course_registration_screen.dart';
import 'package:intl/intl.dart';

class RegistrationPeriodSelectionScreen extends StatelessWidget {
  const RegistrationPeriodSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn đợt đăng ký')),
      body: Consumer<ScheduleProvider>(
        builder: (context, scheduleProvider, child) {
          final schoolYears = scheduleProvider.schoolYears;

          if (scheduleProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (schoolYears.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Không có dữ liệu năm học.'),
                  ElevatedButton(
                    onPressed: () {
                      // Try to re-fetch if possible, or user relies on AutoRefresh
                      // ScheduleProvider init fetches data.
                    },
                    child: const Text('Tải lại'),
                  ),
                ],
              ),
            );
          }

          // Flatten list of periods
          final List<Map<String, dynamic>> allPeriods = [];

          for (var year in schoolYears) {
            if (year.semesters != null) {
              for (var semester in year.semesters!) {
                if (semester.registerPeriods != null &&
                    semester.registerPeriods!.isNotEmpty) {
                  for (var period in semester.registerPeriods!) {
                    allPeriods.add({
                      'year': year,
                      'semester': semester,
                      'period': period,
                    });
                  }
                }
              }
            }
          }

          // Sort by Year > Semester > Period Start Time (Newest first)
          allPeriods.sort((a, b) {
            final yA = a['year'] as SchoolYear;
            final yB = b['year'] as SchoolYear;
            // Primary: Year Start Date Descending
            int cmpYear = yB.startDate.compareTo(yA.startDate);
            if (cmpYear != 0) return cmpYear;

            final sA = a['semester'] as Semester;
            final sB = b['semester'] as Semester;
            // Secondary: Semester Start Date Descending
            int cmpSem = sB.startDate.compareTo(sA.startDate);
            if (cmpSem != 0) return cmpSem;

            final pA = a['period'] as SemesterRegisterPeriod;
            final pB = b['period'] as SemesterRegisterPeriod;
            // Tertiary: Registration Period Start Time Descending
            return pB.startRegisterTime.compareTo(pA.startRegisterTime);
          });

          if (allPeriods.isEmpty) {
            return const Center(child: Text('Không tìm thấy đợt đăng ký nào.'));
          }

          return ListView.builder(
            itemCount: allPeriods.length,
            itemBuilder: (context, index) {
              final item = allPeriods[index];
              final period = item['period'] as SemesterRegisterPeriod;
              final semester = item['semester']; // Semester entity

              final startDate = period.startRegisterTime > 0
                  ? DateTime.fromMillisecondsSinceEpoch(
                      period.startRegisterTime,
                    )
                  : null;
              final endDate = period.endRegisterTime > 0
                  ? DateTime.fromMillisecondsSinceEpoch(period.endRegisterTime)
                  : null;
              final now = DateTime.now();
              final isActive =
                  startDate != null &&
                  endDate != null &&
                  now.isAfter(startDate) &&
                  now.isBefore(endDate);

              String timeText = '';
              if (startDate != null && endDate != null) {
                timeText =
                    'Thời gian: ${DateFormat('dd/MM/yyyy HH:mm').format(startDate)} - ${DateFormat('dd/MM/yyyy HH:mm').format(endDate)}';
              } else {
                timeText = 'Thời gian: Chưa cập nhật';
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isActive
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: ListTile(
                  title: Text(period.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Học kỳ: ${semester.semesterName}'),
                      Text(timeText),
                    ],
                  ),
                  trailing: isActive
                      ? const Chip(
                          label: Text(
                            'Đang mở',
                            style: TextStyle(fontSize: 10),
                          ),
                        )
                      : null,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            CourseRegistrationScreen(period: period),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
