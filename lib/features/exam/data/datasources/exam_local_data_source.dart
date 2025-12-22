import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/exam/data/models/exam_room_model.dart';
import 'package:tlucalendar/features/exam/data/models/exam_schedule_model.dart';
import 'package:tlucalendar/services/database_helper.dart';
import 'package:tlucalendar/features/exam/data/models/exam_dtos.dart' as Legacy;

abstract class ExamLocalDataSource {
  Future<List<ExamScheduleModel>> getCachedExamSchedules(int semesterId);
  Future<void> cacheExamSchedules(
    int semesterId,
    List<ExamScheduleModel> schedules,
  );

  Future<List<ExamRoomModel>> getCachedExamRooms({
    required int semesterId,
    required int scheduleId,
    required int round,
  });

  Future<void> cacheExamRooms({
    required int semesterId,
    required int scheduleId, // registerPeriodId
    required int round,
    required List<ExamRoomModel> rooms,
  });
}

class ExamLocalDataSourceImpl implements ExamLocalDataSource {
  final DatabaseHelper databaseHelper;

  ExamLocalDataSourceImpl({required this.databaseHelper});

  @override
  Future<List<ExamScheduleModel>> getCachedExamSchedules(int semesterId) async {
    try {
      final maps = await databaseHelper.getRegisterPeriodsMaps(semesterId);
      return maps.map((json) => ExamScheduleModel.fromJson(json)).toList();
    } catch (e) {
      throw CacheFailure(e.toString());
    }
  }

  @override
  Future<void> cacheExamSchedules(
    int semesterId,
    List<ExamScheduleModel> schedules,
  ) async {
    try {
      await databaseHelper.saveRegisterPeriods(semesterId, schedules);
    } catch (e) {
      throw CacheFailure(e.toString());
    }
  }

  @override
  Future<List<ExamRoomModel>> getCachedExamRooms({
    required int semesterId,
    required int scheduleId,
    required int round,
  }) async {
    try {
      final legacyRooms = await databaseHelper.getExamRooms(
        semesterId,
        scheduleId,
        round,
      );

      // Map Legacy.StudentExamRoom -> ExamRoomModel (Clean Arch)
      // Note: ExamRoomModel is a flattened view of the exam data
      return legacyRooms.map((legacy) {
        // Safe access to nested nullable fields
        final examDate = legacy.examRoom?.examDate != null
            ? DateTime.fromMillisecondsSinceEpoch(legacy.examRoom!.examDate!)
            : null;

        final examTime =
            legacy.examRoom?.examHour?.startString ??
            legacy.examRoom?.examHour?.name;
        final roomName =
            legacy.examRoom?.room?.name ?? legacy.examRoom?.roomCode;

        return ExamRoomModel(
          id: legacy.id,
          // Missing fields in ExamRoomModel: status, examCode, etc. derived or ignored
          // Assuming 'subjectName' is available in Model
          subjectName: legacy.subjectName,
          examPeriodCode: legacy.examPeriodCode,
          studentCode: legacy.studentCode,
          examDate: examDate,
          examTime: examTime,
          roomName: roomName,
          // roomBuilding: null in Legacy DTO usually, or deep in room object
          roomBuilding: null,
          // examMethod: legacy has it? DTO might check legacy.examRoom?.examMethod (which is complex)
          // For now leave null or map if possible. Legacy DTO definition checked earlier didn't show examMethod clearly on top level.
          examMethod: null,
          notes: null, // Legacy doesn't seem to have notes easily accessible
          numberExpectedStudent: legacy.examRoom?.numberExpectedStudent,
        );
      }).toList();
    } catch (e) {
      throw CacheFailure(e.toString());
    }
  }

  @override
  Future<void> cacheExamRooms({
    required int semesterId,
    required int scheduleId,
    required int round,
    required List<ExamRoomModel> rooms,
  }) async {
    try {
      // Map ExamRoomModel -> Legacy.StudentExamRoom
      // We have to reconstruct the nested Legacy structure from flattened Model
      final legacyRooms = rooms.map((model) {
        // Reconstruct ExamHour
        Legacy.ExamHour? examHour;
        if (model.examTime != null) {
          examHour = Legacy.ExamHour(
            id: 0, // Unknown
            name: '',
            startString: model.examTime!,
            endString: '',
            start: 0,
            end: 0,
            indexNumber: 0,
            type: 0,
          );
        }

        // Reconstruct Room
        Legacy.Room? room;
        if (model.roomName != null) {
          room = Legacy.Room(id: 0, name: model.roomName!, code: '');
        }

        // Reconstruct arguments
        final examDateMs = model.examDate?.millisecondsSinceEpoch;

        final detail = Legacy.ExamRoomDetail(
          id: 0, // Unknown
          roomCode: model.roomName ?? '',
          examDate: examDateMs,
          examDateString: null, // Could format from Date
          numberExpectedStudent: model.numberExpectedStudent,
          examHour: examHour,
          room: room,
          // Missing data from Model
          duration: null,
          semesterName: null,
          courseYearName: null,
          registerPeriodName: null,
          examCode: null,
          studentCode: model.studentCode,
          markingCode: null,
          subjectName: model.subjectName,
          status: 0, // Default
        );

        return Legacy.StudentExamRoom(
          id: model.id,
          status: 0, // Default, Model doesn't have it
          examCode: null, // Model doesn't have it
          examCodeNumber: null,
          markingCode: null,
          examPeriodCode: model.examPeriodCode,
          subjectName: model.subjectName,
          studentCode: model.studentCode,
          examRound: round,
          examRoom: detail,
        );
      }).toList();

      await databaseHelper.saveExamRooms(
        semesterId,
        scheduleId,
        round,
        legacyRooms,
      );
    } catch (e) {
      throw CacheFailure(e.toString());
    }
  }
}
