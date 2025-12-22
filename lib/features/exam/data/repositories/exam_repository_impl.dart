import 'package:dartz/dartz.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/exam/data/datasources/exam_remote_data_source.dart';
import 'package:tlucalendar/features/exam/data/datasources/exam_local_data_source.dart';
import 'package:tlucalendar/features/exam/domain/entities/exam_room.dart';
import 'package:tlucalendar/features/exam/domain/entities/exam_schedule.dart';
import 'package:tlucalendar/features/exam/domain/repositories/exam_repository.dart';

class ExamRepositoryImpl implements ExamRepository {
  final ExamRemoteDataSource remoteDataSource;
  final ExamLocalDataSource localDataSource;

  ExamRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

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
      // Cache
      try {
        await localDataSource.cacheExamSchedules(semesterId, result);
      } catch (e) {
        // Log error but proceed
      }
      return Right(result);
    } catch (e) {
      // Try local
      try {
        final localResult = await localDataSource.getCachedExamSchedules(
          semesterId,
        );
        if (localResult.isNotEmpty) {
          return Right(localResult);
        }
      } catch (_) {}

      // If both fail, return original error
      if (e is Failure) return Left(e);
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
      // Cache
      try {
        await localDataSource.cacheExamRooms(
          semesterId: semesterId,
          scheduleId: scheduleId,
          round: round,
          rooms: result,
        );
      } catch (e) {
        // Log error
      }
      return Right(result);
    } catch (e) {
      // Try local
      try {
        final localResult = await localDataSource.getCachedExamRooms(
          semesterId: semesterId,
          scheduleId: scheduleId,
          round: round,
        );
        if (localResult.isNotEmpty) {
          return Right(localResult);
        }
      } catch (_) {}

      return Left(ServerFailure(e.toString()));
    }
  }
}
