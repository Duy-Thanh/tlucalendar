import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tlucalendar/providers/registration_provider.dart';
import 'package:tlucalendar/features/registration/domain/entities/subject_registration.dart';
import 'package:tlucalendar/features/schedule/domain/entities/semester_register_period.dart';
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
    // Need simpler UI for class section

    // Status color
    Color statusColor = Colors.grey;
    if (course.isSelected) {
      statusColor = Colors.green.shade100;
    } else if (course.isFull) {
      statusColor = Colors.red.shade100;
    }

    return Container(
      color: statusColor,
      padding: const EdgeInsets.all(8.0),
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
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'GV: ${course.timetables.isNotEmpty ? course.timetables.first.teacherName : "N/A"}',
                    ),
                    Text('Sĩ số: ${course.numberStudent}/${course.maxStudent}'),
                    Text('Trạng thái: ${course.status}'),
                  ],
                ),
              ),
              if (course.isSelected)
                ElevatedButton(
                  onPressed: () {
                    // Cancel logic
                    // Payload from C# code looks like: JsonConvert.SerializeObject(CourseSubjectDto)
                    // But I don't have easy DTO serialization here matching C#.
                    // However, `CourseSubjectModel` structure matches `CourseSubjectDto` properties if serialization naming matches.
                    // NativeParser mapped from native structs.
                    // I should probably manually construct the payload map to ensure keys match C# expectation.
                    // Keys: Id, Code, DisplayCode, SubjectName (maybe not?), etc.
                    // The C# `remove_reg` sends `SerializeObject(register)`.
                    // Wait, `new_reg` takes `register` which is `CourseSubjectDto`.

                    _handleAction(context, false);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Hủy'),
                )
              else
                ElevatedButton(
                  onPressed: course.isFull
                      ? null
                      : () {
                          // Register logic
                          _handleAction(context, true);
                        },
                  child: const Text('Đăng ký'),
                ),
            ],
          ),
          // Timetables brief
          if (course.timetables.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                course.timetables
                    .map(
                      (t) =>
                          "T${t.dayOfWeek} (Tiết ${t.startHour}-${t.endHour}) @ ${t.roomName}",
                    )
                    .join('\n'),
                style: const TextStyle(fontSize: 12, color: Colors.indigo),
              ),
            ),
          const Divider(),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, bool isRegister) async {
    // Construct payload. C# expects JSON of CourseSubjectDto.
    // My `CourseSubject` entity doesn't strictly match the C# DTO keys unless I serialize carefully.
    // Keys observed in C#: Id, Code, DisplayCode, MaxStudent, NumberStudent, IsSelected, IsFullClass, NumberOfCredit, Status, Timetables...
    // NativeParser used keys: Id, Code, DisplayCode, MaxStudent, NumberStudent, IsSelected, IsFullClass, NumberOfCredit, Status.

    // I should create a map
    final Map<String, dynamic> payloadMap = {
      "Id": course.id,
      "Code": course.code,
      "DisplayCode": course.displayCode,
      "MaxStudent": course.maxStudent,
      "NumberStudent": course.numberStudent, // This might change on server?
      "IsSelected": course.isSelected, // Current state
      "IsFullClass": course.isFull,
      "NumberOfCredit": course.credits,
      "Status": course.status,
      // Timetables?
      "Timetables": course.timetables
          .map(
            (t) => {
              "id": t.id,
              "startDate": t.startDate,
              "endDate": t.endDate,
              "fromWeek": t.fromWeek,
              "toWeek": t.toWeek,
              "weekIndex": t.dayOfWeek,
              "startHour": {"indexNumber": t.startHour}, // Nested object in C#?
              // Wait, C# `Timetable` likely has objects for startHour?
              // NativeParser: `yyjson_obj_get(tItem, "startHour")` -> `indexNumber`.
              // So yes, it is nested.
              "endHour": {"indexNumber": t.endHour},
              "roomName": t.roomName,
              "teacherName": t.teacherName,
            },
          )
          .toList(),
    };

    // Note: "startHour" having "indexNumber" is based on NativeParser logic:
    // `yyjson_val *startH = yyjson_obj_get(tItem, "startHour"); if... get_json_int(..., "indexNumber")`

    final payload = jsonEncode(payloadMap);

    final provider = context.read<RegistrationProvider>();
    final success = isRegister
        ? await provider.registerSubject(periodId, payload)
        : await provider.cancelSubjectRegistration(periodId, payload);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isRegister ? 'Đăng ký thành công' : 'Hủy thành công!'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'Thao tác thất bại')),
      );
    }
  }
}
