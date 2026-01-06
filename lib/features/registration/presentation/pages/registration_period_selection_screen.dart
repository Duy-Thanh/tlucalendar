import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tlucalendar/features/schedule/domain/entities/semester_register_period.dart';
import 'package:tlucalendar/features/schedule/domain/entities/school_year.dart';
import 'package:tlucalendar/features/schedule/domain/entities/semester.dart';
import 'package:tlucalendar/providers/schedule_provider.dart';
import 'package:tlucalendar/features/registration/presentation/pages/course_registration_screen.dart';
import 'package:intl/intl.dart';

class RegistrationPeriodSelectionScreen extends StatefulWidget {
  const RegistrationPeriodSelectionScreen({super.key});

  @override
  State<RegistrationPeriodSelectionScreen> createState() =>
      _RegistrationPeriodSelectionScreenState();
}

class _RegistrationPeriodSelectionScreenState
    extends State<RegistrationPeriodSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn đợt đăng ký'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm đợt đăng ký...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
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
                      // Trigger refresh logic via provider if available or tell user to wait
                    },
                    child: const Text('Tải lại'),
                  ),
                ],
              ),
            );
          }

          // 1. Prepare Data
          // Sort Years: Newest first
          final sortedYears = List<SchoolYear>.from(schoolYears)
            ..sort((a, b) => b.startDate.compareTo(a.startDate));

          // 2. Filter or Group
          if (_searchQuery.isNotEmpty) {
            return _buildSearchResults(sortedYears);
          } else {
            return _buildGroupedList(sortedYears);
          }
        },
      ),
    );
  }

  Widget _buildSearchResults(List<SchoolYear> sortedYears) {
    final List<Map<String, dynamic>> results = [];

    for (var year in sortedYears) {
      if (year.semesters != null) {
        for (var semester in year.semesters!) {
          if (semester.registerPeriods != null) {
            for (var period in semester.registerPeriods!) {
              if (period.name.toLowerCase().contains(_searchQuery)) {
                results.add({
                  'year': year,
                  'semester': semester,
                  'period': period,
                });
              }
            }
          }
        }
      }
    }

    if (results.isEmpty) {
      return const Center(child: Text('Không tìm thấy kết quả nào.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        return _buildPeriodCard(
          context,
          item['period'] as SemesterRegisterPeriod,
          item['semester'] as Semester,
        );
      },
    );
  }

  Widget _buildGroupedList(List<SchoolYear> sortedYears) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: sortedYears.length,
      itemBuilder: (context, index) {
        final year = sortedYears[index];

        // Collect all periods for this year
        final List<Map<String, dynamic>> yearPeriods = [];
        if (year.semesters != null) {
          // Sort semesters newest first
          final sortedSemesters = List<Semester>.from(year.semesters!)
            ..sort((a, b) => b.startDate.compareTo(a.startDate));

          for (var semester in sortedSemesters) {
            if (semester.registerPeriods != null) {
              // Sort periods newest start time first
              final sortedPeriods =
                  List<SemesterRegisterPeriod>.from(semester.registerPeriods!)
                    ..sort(
                      (a, b) =>
                          b.startRegisterTime.compareTo(a.startRegisterTime),
                    );

              for (var period in sortedPeriods) {
                yearPeriods.add({'semester': semester, 'period': period});
              }
            }
          }
        }

        if (yearPeriods.isEmpty) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            initiallyExpanded: index == 0, // Expand first year by default
            shape: Border.all(color: Colors.transparent),
            title: Text(
              year.name, // e.g., "2025_2026" or "Năm học 2025-2026"
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${yearPeriods.length} đợt đăng ký'),
            children: yearPeriods.map((item) {
              return _buildPeriodCard(
                context,
                item['period'] as SemesterRegisterPeriod,
                item['semester'] as Semester,
                isGrouped: true,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildPeriodCard(
    BuildContext context,
    SemesterRegisterPeriod period,
    Semester semester, {
    bool isGrouped = false,
  }) {
    final startDate = period.startRegisterTime > 0
        ? DateTime.fromMillisecondsSinceEpoch(period.startRegisterTime)
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
          '${DateFormat('dd/MM/yyyy HH:mm').format(startDate)} - ${DateFormat('dd/MM/yyyy HH:mm').format(endDate)}';
    } else {
      timeText = 'Chưa cập nhật';
    }

    return Card(
      elevation: 0,
      color: isActive
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
          : isGrouped
          ? Colors.transparent
          : null,
      margin: isGrouped
          ? const EdgeInsets.symmetric(vertical: 2, horizontal: 0)
          : const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          period.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Theme.of(context).hintColor,
                ),
                const SizedBox(width: 4),
                Text('Học kỳ: ${semester.semesterName}'),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Theme.of(context).hintColor,
                ),
                const SizedBox(width: 4),
                Expanded(child: Text(timeText)),
              ],
            ),
          ],
        ),
        trailing: isActive
            ? const Chip(
                label: Text('Đang mở', style: TextStyle(fontSize: 10)),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              )
            : const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CourseRegistrationScreen(period: period),
            ),
          );
        },
      ),
    );
  }
}
