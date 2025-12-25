import 'package:flutter/material.dart';

import 'package:tlucalendar/core/native/native_parser.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course_hour.dart';
import 'package:tlucalendar/features/schedule/domain/entities/school_year.dart';
import 'package:tlucalendar/features/schedule/domain/entities/semester.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_course_hours_usecase.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_current_semester_usecase.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_schedule_usecase.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_school_years_usecase.dart';
import 'package:tlucalendar/services/notification_service.dart';

class ScheduleProvider extends ChangeNotifier {
  final GetScheduleUseCase getScheduleUseCase;
  final GetSchoolYearsUseCase getSchoolYearsUseCase;
  final GetCurrentSemesterUseCase getCurrentSemesterUseCase;
  final GetCourseHoursUseCase getCourseHoursUseCase;

  ScheduleProvider({
    required this.getScheduleUseCase,
    required this.getSchoolYearsUseCase,
    required this.getCurrentSemesterUseCase,
    required this.getCourseHoursUseCase,
  });

  // State
  List<SchoolYear> _schoolYears = [];
  List<Course> _courses = [];
  List<CourseHour> _courseHours = [];
  Semester? _currentSemester;

  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<SchoolYear> get schoolYears => _schoolYears;
  List<Course> get courses => _courses;
  List<CourseHour> get courseHours => _courseHours;
  Semester? get currentSemester => _currentSemester;
  Semester? get selectedSemester =>
      _currentSemester; // Alias for UI if needed, or implement distinct selection
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Init Data
  Future<void> init(String accessToken) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Fetch School Years (and semesters)
      final yearsResult = await getSchoolYearsUseCase(accessToken);

      await yearsResult.fold(
        (failure) async {
          _errorMessage = failure.message;
        },
        (years) async {
          _schoolYears = years;
          // Sort years by startDate ascending (oldest first, newest last)
          // This ensures that .last returns the most recent year/semester
          _schoolYears.sort((a, b) => a.startDate.compareTo(b.startDate));

          // 2. Determine Current Semester
          // Flatten semesters to find current
          Semester? foundCurrent;
          for (var y in years) {
            for (var s in y.semesters) {
              if (s.isCurrent) {
                foundCurrent = s;
                break;
              }
            }
          }
          // Default to last if no current
          if (foundCurrent == null &&
              years.isNotEmpty &&
              years.last.semesters.isNotEmpty) {
            foundCurrent = years.last.semesters.last;
          }

          _currentSemester = foundCurrent;

          // 3. Fetch Course Hours (needed for UI time display)
          final hoursResult = await getCourseHoursUseCase(accessToken);
          hoursResult.fold((l) => null, (r) => _courseHours = r);

          // 4. If we have a current semester, load its schedule
          if (_currentSemester != null) {
            await loadSchedule(accessToken, _currentSemester!.id);
          }
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      // Don't modify isLoading inside finally if we want to show loading during loadSchedule?
      // loadSchedule will handle its own notification but let's just unset here if we haven't
      // But loadSchedule might still be running if we awaited it? Yes.
      // So false here is correct.
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectSemester(String accessToken, int semesterId) async {
    // Find semester object
    Semester? found;
    for (var y in _schoolYears) {
      final s = y.semesters.where((s) => s.id == semesterId).firstOrNull;
      if (s != null) {
        found = s;
        break;
      }
    }

    if (found != null) {
      _currentSemester = found;
      await loadSchedule(accessToken, semesterId);
    }
  }

  Future<void> loadSchedule(String accessToken, int semesterId) async {
    // Don't set global isLoading, maybe add local loading state if needed
    // Or set it if this is user initiated
    // _isLoading = true;
    // notifyListeners();

    final result = await getScheduleUseCase(
      GetScheduleParams(accessToken: accessToken, semesterId: semesterId),
    );
    result.fold((f) => _errorMessage = f.message, (c) {
      _courses = c;
      _scheduleNotifications();
    });
    // _isLoading = false;
    notifyListeners();
  }

  Future<void> _scheduleNotifications() async {
    // delay to avoid blocking immediate UI updates
    await Future.delayed(Duration.zero);

    if (_currentSemester == null || _courses.isEmpty) return;

    final notificationService = NotificationService();

    // Clear all previous notifications
    await notificationService.cancelAllNotifications();

    // Optimized Native Notification Generation
    if (_currentSemester == null) return;

    final notifications = NativeParser.generateNotifications(
      _currentSemester!.startDate,
    );

    if (notifications.isEmpty && _courses.isNotEmpty) {
      print("Native Notifications returned empty! Using Dart fallback.");
      await _scheduleDartNotifications(notificationService);
      return;
    }

    // Batch processing to prevent UI freezer (Davey)
    int count = 0;
    for (var n in notifications) {
      await notificationService.scheduleNativeClassNotification(n);
      count++;
      // Yield every 20 items to let UI breathe
      if (count % 20 == 0) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }
  }

  Future<void> _scheduleDartNotifications(
    NotificationService notificationService,
  ) async {
    if (_courseHours.isEmpty) return; // Need course hours to know times

    int count = 0;
    for (var course in _courses) {
      // Find start hour
      final startHourObj = _courseHours.firstWhere(
        (h) => h.id == course.startCourseHour,
        orElse: () => _courseHours.first, // Fallback?
      );

      // Parse start time "07:00"
      final timeParts = startHourObj.startString.split(':');
      if (timeParts.length < 2) continue;
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      // Calculate dates for this course

      final semesterStart = DateTime.fromMillisecondsSinceEpoch(
        _currentSemester!.startDate,
      );

      // Iterate weeks
      for (int w = course.fromWeek; w <= course.toWeek; w++) {
        // Calculate date relative to Semester Start
        // Week 1 starts at startDate.
        // Week w starts at startDate + (w-1)*7 days.
        // Then add (dayOfWeek - 2) days. (Mon=2 -> add 0).

        final weekStart = semesterStart.add(Duration(days: (w - 1) * 7));
        // TLU dayOfWeek: 2=Mon ... 8=Sun.
        // Dart DateTime: 1=Mon ... 7=Sun.
        // weekStart is usually Monday? Assumed.
        // We need to align with specific day.

        // Let's assume startDate is Monday of Week 1.

        final offsetDays = course.dayOfWeek - 2; // 2->0, 3->1...
        final classDate = weekStart.add(Duration(days: offsetDays));

        // Combine with time
        final classDateTime = DateTime(
          classDate.year,
          classDate.month,
          classDate.day,
          hour,
          minute,
        );

        await notificationService.scheduleClassNotifications(
          course,
          classDateTime,
          course.dayOfWeek,
          "${startHourObj.startString}-${startHourObj.endString}",
        );

        count++;
        if (count % 20 == 0)
          await Future.delayed(const Duration(milliseconds: 5));
      }
    }
  }

  // Get active courses for a date
  List<Course> getActiveCourses(DateTime date) {
    // 2=Monday...8=Sunday (TLU)
    // date.weekday: 1=Monday...7=Sunday (Dart)
    final tluDayOfWeek = date.weekday + 1;

    return _courses.where((course) {
      return course.dayOfWeek == tluDayOfWeek && course.isActiveOn(date);
    }).toList();
  }
}
