import 'package:flutter/material.dart';
import 'package:tlucalendar/models/api_response.dart';
import 'package:tlucalendar/services/log_service.dart';
import 'package:tlucalendar/features/exam/domain/usecases/get_exam_rooms_usecase.dart';
import 'package:tlucalendar/features/exam/domain/usecases/get_exam_schedules_usecase.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_school_years_usecase.dart';
import 'package:intl/intl.dart';

class ExamProvider with ChangeNotifier {
  final _log = LogService();

  final GetExamSchedulesUseCase getExamSchedulesUseCase;
  final GetExamRoomsUseCase getExamRoomsUseCase;
  final GetSchoolYearsUseCase getSchoolYearsUseCase;

  ExamProvider({
    required this.getExamSchedulesUseCase,
    required this.getExamRoomsUseCase,
    required this.getSchoolYearsUseCase,
  });

  List<RegisterPeriod> _registerPeriods = [];
  List<Semester> _availableSemesters = [];
  List<StudentExamRoom> _examRooms = [];
  bool _isLoading = false;
  bool _isLoadingSemesters = false;
  bool _isLoadingRooms = false;
  String? _errorMessage;
  String? _roomErrorMessage;

  // Selected filters
  int? _selectedRegisterPeriodId;
  int? _selectedSemesterId;
  int _selectedExamRound = 1;

  List<RegisterPeriod> get registerPeriods => _registerPeriods;
  List<Semester> get availableSemesters => _availableSemesters;
  List<StudentExamRoom> get examRooms => _examRooms;
  bool get isLoading => _isLoading;
  bool get isLoadingSemesters => _isLoadingSemesters;
  bool get isLoadingRooms => _isLoadingRooms;
  String? get errorMessage => _errorMessage;
  String? get roomErrorMessage => _roomErrorMessage;
  int? get selectedRegisterPeriodId => _selectedRegisterPeriodId;
  int? get selectedSemesterId => _selectedSemesterId;
  int get selectedExamRound => _selectedExamRound;

  // Legacy accessor for UI compatibility

  /// Get the currently selected register period
  RegisterPeriod? get selectedRegisterPeriod {
    if (_selectedRegisterPeriodId == null) return null;
    try {
      return _registerPeriods.firstWhere(
        (period) => period.id == _selectedRegisterPeriodId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get the currently selected semester
  Semester? get selectedSemester {
    if (_selectedSemesterId == null) return null;
    try {
      return _availableSemesters.firstWhere(
        (semester) => semester.id == _selectedSemesterId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Alias for init to match UI expectation
  Future<void> fetchAvailableSemesters(String accessToken) async {
    await init(accessToken);
  }

  /// Initialize: Load semesters
  Future<void> init(String accessToken) async {
    _isLoadingSemesters = true;
    notifyListeners();
    try {
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
              // Map Domain Semester -> API Semester
              _availableSemesters.add(
                Semester(
                  id: sem.id,
                  semesterCode: sem.semesterCode,
                  semesterName: sem.semesterName,
                  startDate: sem.startDate,
                  endDate: sem.endDate,
                  isCurrent: sem.isCurrent,
                  ordinalNumbers: sem.ordinalNumbers,
                  semesterRegisterPeriods:
                      [], // Empty list as we don't use this nested data
                ),
              );
            }
          }
          // Sort semesters if needed
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

  /// Select a semester and fetch its exam schedules (Register Periods)
  Future<void> selectSemester(String accessToken, int semesterId) async {
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
          // Create a placeholder semester object for the mapping
          final currentSem =
              selectedSemester ??
              Semester(
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
                (e) => RegisterPeriod(
                  id: e.id,
                  name: e.name,
                  displayOrder: e.displayOrder,
                  voided: e.voided,
                  semester: currentSem,
                  // Passing empty examPeriods list because the Entity.ExamSchedule contains
                  // definitions, not courses. The UI only uses this list for the dropdown.
                  examPeriods: [],
                ),
              )
              .toList();

          if (_registerPeriods.isNotEmpty) {
            _selectedRegisterPeriodId = _registerPeriods.first.id;
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
  ) {
    if (_selectedRegisterPeriodId != periodId) {
      _selectedRegisterPeriodId = periodId;
      notifyListeners();
      // Auto-fetch exams when period is selected
      fetchExamRoomDetails(accessToken, semesterId, periodId, round);
    }
  }

  void selectExamRound(int round) {
    if (_selectedExamRound != round) {
      _selectedExamRound = round;
      notifyListeners();
    }
  }

  void setExamRound(int round) => selectExamRound(round);

  /// Fetch list of exams (StudentExamRoom) for the student
  Future<void> fetchExamRoomDetails(
    String accessToken,
    int semesterId,
    int scheduleId,
    int round,
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
        ),
      );

      result.fold((l) => _roomErrorMessage = l.message, (r) {
        _examRooms = r.map((e) {
          // Create nested ExamRoomDetail
          final detail = ExamRoomDetail(
            id: 0, // Entity doesn't have Detail ID?
            roomCode: e.roomName ?? '',
            examDate: e.examDate?.millisecondsSinceEpoch,
            examDateString: e.examDate != null
                ? DateFormat('dd/MM/yyyy').format(e.examDate!)
                : '',
            examHour: ExamHour(
              id: 0,
              name: e.examTime, // Using string as name
              startString: e.examTime?.split('-').firstOrNull,
              endString: e.examTime?.split('-').lastOrNull,
            ),
            room: Room(id: 0, name: e.roomName ?? '', code: ''),
            numberExpectedStudent: 0, // Entity missing this
          );

          return StudentExamRoom(
            id: e.id,
            status: 0,
            examPeriodCode: e.examPeriodCode,
            subjectName: e.subjectName,
            studentCode: e.studentCode,
            examRoom: detail,
            examCode: null, // SBD missing in Entity
          );
        }).toList();
      });
    } catch (e) {
      _roomErrorMessage = e.toString();
    } finally {
      _isLoadingRooms = false;
      notifyListeners();
    }
  }
}
