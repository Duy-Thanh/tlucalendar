import 'package:tlucalendar/features/exam/data/models/exam_dtos.dart' as Legacy;
import 'package:tlucalendar/services/log_service.dart';
import 'package:tlucalendar/services/notification_service.dart';
import 'package:tlucalendar/features/exam/domain/usecases/get_exam_rooms_usecase.dart';
import 'package:tlucalendar/features/exam/domain/usecases/get_exam_schedules_usecase.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_school_years_usecase.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_course_hours_usecase.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course_hour.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // For ChangeNotifier

class ExamProvider with ChangeNotifier {
  final _log = LogService();

  final GetExamSchedulesUseCase getExamSchedulesUseCase;
  final GetExamRoomsUseCase getExamRoomsUseCase;
  final GetSchoolYearsUseCase getSchoolYearsUseCase;
  final GetCourseHoursUseCase getCourseHoursUseCase;

  ExamProvider({
    required this.getExamSchedulesUseCase,
    required this.getExamRoomsUseCase,
    required this.getSchoolYearsUseCase,
    required this.getCourseHoursUseCase,
  });

  List<Legacy.RegisterPeriod> _registerPeriods = [];
  List<Legacy.SemesterDto> _availableSemesters = [];
  List<Legacy.StudentExamRoom> _examRooms = [];
  List<CourseHour> _courseHours = [];
  bool _isLoading = false;
  bool _isLoadingSemesters = false;
  bool _isLoadingRooms = false;
  String? _errorMessage;
  String? _roomErrorMessage;

  int? _selectedRegisterPeriodId;
  int? _selectedSemesterId;
  int _selectedExamRound = 1;

  List<Legacy.RegisterPeriod> get registerPeriods => _registerPeriods;
  List<Legacy.SemesterDto> get availableSemesters => _availableSemesters;
  List<Legacy.StudentExamRoom> get examRooms => _examRooms;
  bool get isLoading => _isLoading;
  bool get isLoadingSemesters => _isLoadingSemesters;
  bool get isLoadingRooms => _isLoadingRooms;
  String? get errorMessage => _errorMessage;
  String? get roomErrorMessage => _roomErrorMessage;
  int? get selectedRegisterPeriodId => _selectedRegisterPeriodId;
  int? get selectedSemesterId => _selectedSemesterId;
  int get selectedExamRound => _selectedExamRound;

  Legacy.RegisterPeriod? get selectedRegisterPeriod {
    if (_selectedRegisterPeriodId == null) return null;
    try {
      return _registerPeriods.firstWhere(
        (period) => period.id == _selectedRegisterPeriodId,
      );
    } catch (e) {
      return null;
    }
  }

  Legacy.SemesterDto? get selectedSemester {
    if (_selectedSemesterId == null) return null;
    try {
      return _availableSemesters.firstWhere(
        (semester) => semester.id == _selectedSemesterId,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> fetchAvailableSemesters(String accessToken) async {
    await init(accessToken);
  }

  Future<void> init(String accessToken) async {
    _isLoadingSemesters = true;
    notifyListeners();
    notifyListeners();
    try {
      // Fetch Course Hours concurrently or sequentially
      final hoursResult = await getCourseHoursUseCase(accessToken);
      hoursResult.fold((l) => null, (r) => _courseHours = r);

      final result = await getSchoolYearsUseCase(accessToken);
      result.fold(
        (l) {
          _errorMessage = l.message;
          _log.log(
            'Error fetching school years: ${l.message}',
            level: LogLevel.error,
          );
        },
        (r) {
          _availableSemesters = [];
          for (var year in r) {
            for (var sem in year.semesters) {
              _availableSemesters.add(
                Legacy.SemesterDto(
                  id: sem.id,
                  semesterCode: sem.semesterCode,
                  semesterName: sem.semesterName,
                  startDate: sem.startDate,
                  endDate: sem.endDate,
                  isCurrent: sem.isCurrent,
                  semesterRegisterPeriods: [],
                ),
              );
            }
          }
          if (_availableSemesters.isNotEmpty) {
            final current = _availableSemesters
                .where((s) => s.isCurrent)
                .firstOrNull;
            _selectedSemesterId = current?.id ?? _availableSemesters.last.id;
          }
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _log.log('Exception fetching school years: $e', level: LogLevel.error);
    } finally {
      _isLoadingSemesters = false;
      notifyListeners();
    }
  }

  Future<bool> hasRegisterPeriodsCache(int semesterId) async {
    if (_selectedSemesterId == semesterId && _registerPeriods.isNotEmpty) {
      return true;
    }
    return false;
  }

  Future<void> selectSemesterFromCache(int semesterId) async {
    _selectedSemesterId = semesterId;
    notifyListeners();
  }

  Future<void> selectSemester(
    String accessToken,
    int semesterId,
    Map<String, dynamic>? rawToken,
  ) async {
    if (_selectedSemesterId == semesterId && _registerPeriods.isNotEmpty) {
      return;
    }

    _selectedSemesterId = semesterId;
    _isLoading = true;
    _errorMessage = null;
    _registerPeriods = [];
    notifyListeners();

    try {
      final result = await getExamSchedulesUseCase(
        GetExamSchedulesParams(
          semesterId: semesterId,
          accessToken: accessToken,
          rawToken: rawToken,
        ),
      );

      result.fold(
        (l) {
          _errorMessage = l.message;
          _log.log(
            'Error fetching exam schedules: ${l.message}',
            level: LogLevel.error,
          );
        },
        (r) {
          final currentSem =
              selectedSemester ??
              Legacy.SemesterDto(
                id: semesterId,
                semesterCode: '',
                semesterName: '',
                startDate: 0,
                endDate: 0,
                isCurrent: false,
                semesterRegisterPeriods: [],
              );

          _registerPeriods = r
              .map(
                (e) => Legacy.RegisterPeriod(
                  id: e.id,
                  name: e.name,
                  displayOrder: e.displayOrder,
                  voided: e.voided,
                  semester: currentSem,
                  examPeriods: [],
                ),
              )
              .toList();

          if (_registerPeriods.isNotEmpty) {
            _selectedRegisterPeriodId = _registerPeriods.first.id;
            // Trigger fetch for the default selected period
            fetchExamRoomDetails(
              accessToken,
              semesterId,
              _selectedRegisterPeriodId!,
              _selectedExamRound,
              rawToken,
            );
          } else {
            _selectedRegisterPeriodId = null;
          }
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _log.log('Exception fetching exam schedules: $e', level: LogLevel.error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectRegisterPeriod(
    String accessToken,
    int semesterId,
    int periodId,
    int round,
    Map<String, dynamic>? rawToken,
  ) {
    if (_selectedRegisterPeriodId != periodId) {
      _selectedRegisterPeriodId = periodId;
      notifyListeners();
      fetchExamRoomDetails(accessToken, semesterId, periodId, round, rawToken);
    }
  }

  void selectExamRound(int round) {
    if (_selectedExamRound != round) {
      _selectedExamRound = round;
      notifyListeners();
    }
  }

  void setExamRound(int round) => selectExamRound(round);

  Future<void> fetchExamRoomDetails(
    String accessToken,
    int semesterId,
    int scheduleId,
    int round,
    Map<String, dynamic>? rawToken,
  ) async {
    _isLoadingRooms = true;
    _roomErrorMessage = null;
    notifyListeners();

    try {
      final result = await getExamRoomsUseCase(
        GetExamRoomsParams(
          semesterId: semesterId,
          scheduleId: scheduleId,
          round: round,
          accessToken: accessToken,
          rawToken: rawToken,
        ),
      );

      result.fold((l) => _roomErrorMessage = l.message, (r) {
        _examRooms = r.map((e) {
          final detail = Legacy.ExamRoomDetail(
            id: 0,
            roomCode: e.roomName ?? '',
            examDate: e.examDate?.millisecondsSinceEpoch,
            examDateString: e.examDate != null
                ? DateFormat('dd/MM/yyyy').format(e.examDate!)
                : '',
            examHour: _parseExamHour(e.examTime),
            room: Legacy.Room(id: 0, name: e.roomName ?? '', code: ''),
            numberExpectedStudent: e.numberExpectedStudent ?? 0,
          );

          return Legacy.StudentExamRoom(
            id: e.id,
            status: 0,
            examPeriodCode: e.examPeriodCode,
            subjectName: e.subjectName,
            studentCode: e.studentCode,
            examRound: 0,
            examRoom: detail,
            examCode: null,
          );
        }).toList();
      });
    } catch (e) {
      _roomErrorMessage = e.toString();
    } finally {
      _isLoadingRooms = false;

      // Schedule notifications
      if (_examRooms.isNotEmpty) {
        final notificationService = NotificationService();
        for (var room in _examRooms) {
          if (room.examRoom?.examDate != null &&
              room.examRoom?.examHour != null) {
            // Parse start time
            final timeStr = room.examRoom!.examHour!.startString;
            final parts = timeStr.split(':');
            if (parts.length >= 2) {
              final h = int.tryParse(parts[0]);
              final m = int.tryParse(parts[1]);

              if (h != null && m != null) {
                final date = DateTime.fromMillisecondsSinceEpoch(
                  room.examRoom!.examDate!,
                );
                final examDateTime = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  h,
                  m,
                );

                notificationService.scheduleExamNotifications(
                  room,
                  examDateTime,
                );
              }
            }
          }
        }
      }

      notifyListeners();
    }
  }

  Legacy.ExamHour _parseExamHour(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) {
      return Legacy.ExamHour(
        id: 0,
        name: 'Chưa có',
        startString: '',
        endString: '',
        start: 0,
        end: 0,
        indexNumber: 0,
        type: 0,
      );
    }

    // Expected format: "10-12" or "07:00-09:00"
    String startStr = '';
    String endStr = '';
    String shiftName = timeStr; // Default to original string
    int start = 0;

    if (timeStr.contains('-')) {
      final parts = timeStr.split('-');
      if (parts.length >= 2) {
        startStr = parts[0].trim();
        endStr = parts[1].trim();

        // Check if these are periods (digits only, small length)
        if (RegExp(r'^\d{1,2}$').hasMatch(startStr)) {
          start = int.tryParse(startStr) ?? 0;
          int end = int.tryParse(endStr) ?? 0;

          // Look up in _courseHours
          String? realStartTime;
          String? realEndTime;

          if (_courseHours.isNotEmpty) {
            final startHour = _courseHours
                .where((h) => h.indexNumber == start)
                .firstOrNull;
            final endHour = _courseHours
                .where((h) => h.indexNumber == end)
                .firstOrNull;

            if (startHour != null) realStartTime = startHour.startString;
            if (endHour != null) realEndTime = endHour.endString;
          }

          if (realStartTime != null && realEndTime != null) {
            // Found exact clock times!
            startStr = realStartTime;
            endStr = realEndTime;
          } else {
            // Fallback to "Tiết X"
            startStr = 'Tiết $startStr';
            endStr = 'Tiết $endStr';
          }

          // Calculate Shift (Ca thi)
          if (start >= 1 && start <= 3)
            shiftName = 'Ca 1 (Sáng)';
          else if (start >= 4 && start <= 6)
            shiftName = 'Ca 2 (Sáng)';
          else if (start >= 7 && start <= 9)
            shiftName = 'Ca 3 (Chiều)';
          else if (start >= 10 && start <= 12)
            shiftName = 'Ca 4 (Chiều)';
          else if (start >= 13)
            shiftName = 'Ca 5 (Tối)';
        }
      }
    }

    return Legacy.ExamHour(
      id: 0,
      name: shiftName,
      startString: startStr,
      endString: endStr,
      start: start,
      end: 0,
      indexNumber: 0,
      type: 0,
      code: '',
    );
  }
}
