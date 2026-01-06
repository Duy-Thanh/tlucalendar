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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RegistrationProvider>().fetchRegistrationData(
        widget.period.id.toString(),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _isSearching
            ? IconButton(
                icon: const Icon(
                  Icons.close,
                ), // Use 'Close' (X) to indicate "Exit Search"
                tooltip: "Thoát tìm kiếm",
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                  });
                },
              )
            : null, // Default AutoLeading
        title: _isSearching ? _buildSearchBar() : Text(widget.period.name),
        actions: [
          if (_isSearching)
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                },
              )
            else
              const SizedBox()
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
        ],
      ),
      body: Consumer<RegistrationProvider>(
        builder: (context, provider, child) {
          // Only show full loading if we have NO data.
          // If we have data but are refreshing/acting, the individual buttons will handle loading state
          if (provider.isLoading && provider.subjects.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null && provider.subjects.isEmpty) {
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

          // Filter subjects based on search query
          final filteredSubjects = subjects.where((subject) {
            final name = subject.subjectName.toLowerCase();
            return name.contains(_searchQuery);
          }).toList();

          if (filteredSubjects.isEmpty) {
            return Center(
              child: Text('Không tìm thấy môn học "$_searchQuery"'),
            );
          }

          return ListView.builder(
            itemCount: filteredSubjects.length,
            itemBuilder: (context, index) {
              return _SubjectItem(
                subject: filteredSubjects[index],
                periodId: widget.period.id.toString(),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white),
      autofocus: true,
      decoration: const InputDecoration(
        hintText: 'Tìm kiếm môn học...',
        hintStyle: TextStyle(color: Colors.white70),
        border: InputBorder.none,
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

class _CourseSubjectItem extends StatefulWidget {
  final CourseSubject course;
  final String periodId;

  const _CourseSubjectItem({required this.course, required this.periodId});

  @override
  State<_CourseSubjectItem> createState() => _CourseSubjectItemState();
}

class _CourseSubjectItemState extends State<_CourseSubjectItem> {
  bool _isLocalLoading = false;

  @override
  Widget build(BuildContext context) {
    // Status color
    Color statusColor = Colors.grey.shade300;
    if (widget.course.isSelected) {
      statusColor = Colors.green.shade100;
    } else if (widget.course.isFull) {
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
                        'Mã lớp: ${widget.course.displayCode} (${widget.course.code})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'GV: ${widget.course.timetables.isNotEmpty ? widget.course.timetables.first.teacherName : "N/A"}',
                        style: const TextStyle(color: textColor),
                      ),
                      Text(
                        'Sĩ số: ${widget.course.numberStudent}/${widget.course.maxStudent}',
                        style: const TextStyle(color: textColor),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Trạng thái: ${widget.course.status}',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: textColor,
                            ),
                          ),
                          if (!widget.course.isSelected &&
                              _checkConflict(context))
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
                if (widget.course.isSelected)
                  ElevatedButton(
                    onPressed: _isLocalLoading
                        ? null
                        : () => _handleAction(context, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: _isLocalLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Hủy'),
                  )
                else
                  ElevatedButton(
                    onPressed: (widget.course.isFull || _isLocalLoading)
                        ? null
                        : () => _handleAction(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: _isLocalLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Đăng ký'),
                  ),
              ],
            ),

            if (widget.course.timetables.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.course.timetables
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
    setState(() {
      _isLocalLoading = true;
    });

    // Construct payload. C# expects JSON of CourseSubjectDto.
    final Map<String, dynamic> payloadMap = {
      "Id": widget.course.id,
      "Code": widget.course.code,
      "DisplayCode": widget.course.displayCode,
      "MaxStudent": widget.course.maxStudent,
      "NumberStudent": widget.course.numberStudent,
      "IsSelected": widget.course.isSelected,
      "IsFullClass": widget.course.isFull,
      "NumberOfCredit": widget.course.credits,
      "Status": widget.course.status,
      "Timetables": widget.course.timetables
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

    final success = isRegister
        ? await provider.registerSubject(widget.periodId, payload)
        : await provider.cancelSubjectRegistration(widget.periodId, payload);

    if (mounted) {
      setState(() {
        _isLocalLoading = false;
      });

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
    if (widget.course.isSelected) return false;

    final scheduleProvider = context.read<ScheduleProvider>();
    final enrolledCourses = scheduleProvider.courses;
    final courseHours = scheduleProvider.courseHours;

    if (courseHours.isEmpty || enrolledCourses.isEmpty) return false;

    for (var t in widget.course.timetables) {
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
          return true; // Conflict found
        }
      }
    }
    return false;
  }
}
