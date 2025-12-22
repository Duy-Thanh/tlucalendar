import 'package:dartz/dartz.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/exam/data/datasources/exam_remote_data_source.dart';
import 'package:tlucalendar/features/exam/domain/entities/exam_room.dart';
import 'package:tlucalendar/features/exam/domain/entities/exam_schedule.dart';
import 'package:tlucalendar/features/exam/domain/repositories/exam_repository.dart';

class ExamRepositoryImpl implements ExamRepository {
  final ExamRemoteDataSource remoteDataSource;

  ExamRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<ExamSchedule>>> getExamSchedules(
    int semesterId,
    String accessToken,
    Map<String, dynamic>? rawToken,
  ) async {
    try {
      final result = await remoteDataSource.getExamSchedules(
        semesterId,
        accessToken,
        rawToken,
      );
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ExamRoom>>> getExamRooms({
    required int semesterId,
    required int scheduleId,
    required int round,
    required String accessToken,
    Map<String, dynamic>? rawToken,
  }) async {
    try {
      final result = await remoteDataSource.getExamRooms(
        semesterId: semesterId,
        scheduleId: scheduleId,
        round: round,
        accessToken: accessToken,
        rawToken: rawToken,
      );
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
