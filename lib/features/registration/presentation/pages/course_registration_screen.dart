import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tlucalendar/providers/registration_provider.dart';
import 'package:tlucalendar/features/registration/domain/entities/subject_registration.dart';
import 'package:tlucalendar/features/schedule/domain/entities/semester_register_period.dart';
import 'package:tlucalendar/providers/schedule_provider.dart';
import 'dart:convert'; // For jsonEncode

class CourseRegistrationScreen extends StatefulWidget {
  final SemesterRegisterPeriod period;

  const CourseRegistrationScreen({super.key, required this.period});

  @override
  State<CourseRegistrationScreen> createState() =>
      _CourseRegistrationScreenState();
}

class _CourseRegistrationScreenState extends State<CourseRegistrationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RegistrationProvider>().fetchRegistrationData(
        widget.period.id.toString(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.period.name)),
      body: Consumer<RegistrationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Lỗi: ${provider.errorMessage}'),
                  ElevatedButton(
                    onPressed: () {
                      provider.fetchRegistrationData(
                        widget.period.id.toString(),
                      );
                    },
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final subjects = provider.subjects;
          if (subjects.isEmpty) {
            return const Center(child: Text('Không có môn học nào để đăng ký'));
          }

          return ListView.builder(
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              return _SubjectItem(
                subject: subjects[index],
                periodId: widget.period.id.toString(),
              );
            },
          );
        },
      ),
    );
  }
}

class _SubjectItem extends StatefulWidget {
  final SubjectRegistration subject;
  final String periodId;

  const _SubjectItem({required this.subject, required this.periodId});

  @override
  State<_SubjectItem> createState() => _SubjectItemState();
}

class _SubjectItemState extends State<_SubjectItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            title: Text(
              widget.subject.subjectName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Số tín chỉ: ${widget.subject.numberOfCredit}'),
            trailing: IconButton(
              icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
            ),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
          ),
          if (_isExpanded)
            ...widget.subject.courseSubjects.map(
              (course) =>
                  _CourseSubjectItem(course: course, periodId: widget.periodId),
            ),
        ],
      ),
    );
  }
}

class _CourseSubjectItem extends StatelessWidget {
  final CourseSubject course;
  final String periodId;

  const _CourseSubjectItem({required this.course, required this.periodId});

  @override
  Widget build(BuildContext context) {
    // Status color
    Color statusColor = Colors.grey.shade300;
    if (course.isSelected) {
      statusColor = Colors.green.shade100;
    } else if (course.isFull) {
      statusColor = Colors.red.shade100;
    }

    // Force black text because background is consistently light
    const textColor = Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(12.0),
      child: DefaultTextStyle(
        style: const TextStyle(color: textColor, fontSize: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mã lớp: ${course.displayCode} (${course.code})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'GV: ${course.timetables.isNotEmpty ? course.timetables.first.teacherName : "N/A"}',
                        style: const TextStyle(color: textColor),
                      ),
                      Text(
                        'Sĩ số: ${course.numberStudent}/${course.maxStudent}',
                        style: const TextStyle(color: textColor),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Trạng thái: ${course.status}',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: textColor,
                            ),
                          ),
                          if (!course.isSelected && _checkConflict(context))
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Tooltip(
                                message: "Trùng lịch học",
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.deepOrange,
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (course.isSelected)
                  ElevatedButton(
                    onPressed: () => _handleAction(context, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Hủy'),
                  )
                else
                  ElevatedButton(
                    onPressed: course.isFull
                        ? null
                        : () => _handleAction(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Đăng ký'),
                  ),
              ],
            ),

            if (course.timetables.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  course.timetables
                      .map(
                        (t) =>
                            "T${t.dayOfWeek} (Tiết ${t.startHour}-${t.endHour}) @ ${t.roomName}",
                      )
                      .join('\n'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A237E), // Deep Indigo
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, bool isRegister) async {
    // Construct payload. C# expects JSON of CourseSubjectDto.
    final Map<String, dynamic> payloadMap = {
      "Id": course.id,
      "Code": course.code,
      "DisplayCode": course.displayCode,
      "MaxStudent": course.maxStudent,
      "NumberStudent": course.numberStudent,
      "IsSelected": course.isSelected,
      "IsFullClass": course.isFull,
      "NumberOfCredit": course.credits,
      "Status": course.status,
      "Timetables": course.timetables
          .map(
            (t) => {
              "id": t.id,
              "startDate": t.startDate,
              "endDate": t.endDate,
              "fromWeek": t.fromWeek,
              "toWeek": t.toWeek,
              "weekIndex": t.dayOfWeek,
              "startHour": {"indexNumber": t.startHour},
              "endHour": {"indexNumber": t.endHour},
              "roomName": t.roomName,
              "teacherName": t.teacherName,
            },
          )
          .toList(),
    };

    final payload = jsonEncode(payloadMap);
    final provider = context.read<RegistrationProvider>();

    // Show loading indicator or optimistic update could be better, but simple await here
    final success = isRegister
        ? await provider.registerSubject(periodId, payload)
        : await provider.cancelSubjectRegistration(periodId, payload);

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isRegister ? 'Đăng ký thành công' : 'Hủy thành công!',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Thao tác thất bại'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool _checkConflict(BuildContext context) {
    if (course.isSelected) return false;

    final scheduleProvider = context.read<ScheduleProvider>();
    final enrolledCourses = scheduleProvider.courses;
    final courseHours = scheduleProvider.courseHours;

    if (courseHours.isEmpty || enrolledCourses.isEmpty) return false;

    for (var t in course.timetables) {
      for (var e in enrolledCourses) {
        if (t.dayOfWeek != e.dayOfWeek) continue;

        int maxStartWeek = t.fromWeek > e.fromWeek ? t.fromWeek : e.fromWeek;
        int minEndWeek = t.toWeek < e.toWeek ? t.toWeek : e.toWeek;
        if (maxStartWeek > minEndWeek) continue;

        final eStartHourObj = courseHours.firstWhere(
          (h) => h.id == e.startCourseHour,
          orElse: () => courseHours.first,
        );
        final eEndHourObj = courseHours.firstWhere(
          (h) => h.id == e.endCourseHour,
          orElse: () => courseHours.first,
        );

        int eStartIndex = eStartHourObj.indexNumber;
        int eEndIndex = eEndHourObj.indexNumber;

        int maxStartHour = t.startHour > eStartIndex
            ? t.startHour
            : eStartIndex;
        int minEndHour = t.endHour < eEndIndex ? t.endHour : eEndIndex;

        if (maxStartHour <= minEndHour) {
          return true;
        }
      }
    }
    return false;
  }
}
