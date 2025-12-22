import 'package:tlucalendar/features/exam/data/models/exam_dtos.dart' as Legacy;
import 'package:tlucalendar/services/log_service.dart';
import 'package:tlucalendar/features/exam/domain/usecases/get_exam_rooms_usecase.dart';
import 'package:tlucalendar/features/exam/domain/usecases/get_exam_schedules_usecase.dart';
import 'package:tlucalendar/features/schedule/domain/usecases/get_school_years_usecase.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // For ChangeNotifier

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

  List<Legacy.RegisterPeriod> _registerPeriods = [];
  List<Legacy.SemesterDto> _availableSemesters = [];
  List<Legacy.StudentExamRoom> _examRooms = [];
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
          final detail = Legacy.ExamRoomDetail(
            id: 0,
            roomCode: e.roomName ?? '',
            examDate: e.examDate?.millisecondsSinceEpoch,
            examDateString: e.examDate != null
                ? DateFormat('dd/MM/yyyy').format(e.examDate!)
                : '',
            examHour: Legacy.ExamHour(
              id: 0,
              name: e.examTime ?? '',
              startString: e.examTime?.split('-').firstOrNull ?? '',
              endString: e.examTime?.split('-').lastOrNull ?? '',
              start: 0,
              end: 0,
              indexNumber: 0,
              type: 0,
              code: '',
            ),
            room: Legacy.Room(id: 0, name: e.roomName ?? '', code: ''),
            numberExpectedStudent: 0,
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
      notifyListeners();
    }
  }
}
