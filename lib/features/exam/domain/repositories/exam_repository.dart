import 'package:dartz/dartz.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/exam/domain/entities/exam_room.dart';
import 'package:tlucalendar/features/exam/domain/entities/exam_schedule.dart';

abstract class ExamRepository {
  /// Get list of exam schedules (Register Periods) for a semester
  Future<Either<Failure, List<ExamSchedule>>> getExamSchedules(
    int semesterId,
    String accessToken,
  );

  /// Get list of exam rooms for a specific schedule and round
  Future<Either<Failure, List<ExamRoom>>> getExamRooms({
    required int semesterId,
    required int scheduleId, // registerPeriodId
    required int round,
    required String accessToken,
  });
}
