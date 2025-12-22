import 'package:dartz/dartz.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/schedule/data/datasources/schedule_local_data_source.dart';
import 'package:tlucalendar/features/schedule/data/datasources/schedule_remote_data_source.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course_hour.dart';
import 'package:tlucalendar/features/schedule/domain/entities/school_year.dart';
import 'package:tlucalendar/features/schedule/domain/entities/semester.dart';
import 'package:tlucalendar/features/schedule/domain/repositories/schedule_repository.dart';

class ScheduleRepositoryImpl implements ScheduleRepository {
  final ScheduleRemoteDataSource remoteDataSource;
  final ScheduleLocalDataSource localDataSource;

  ScheduleRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, List<Course>>> getCourses(
    int semesterId,
    String accessToken,
  ) async {
    try {
      final courseModels = await remoteDataSource.getCourses(
        semesterId,
        accessToken,
      );
      // Ideally cache here: await localDataSource.cacheCourses(semesterId, courseModels);
      return Right(courseModels);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CourseHour>>> getCourseHours(
    String accessToken,
  ) async {
    try {
      final hours = await remoteDataSource.getCourseHours(accessToken);
      return Right(hours);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Course>>> getCachedCourses(int semesterId) async {
    try {
      final courses = await localDataSource.getCachedCourses(semesterId);
      return Right(courses);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<SchoolYear>>> getSchoolYears(
    String accessToken,
  ) async {
    try {
      final years = await remoteDataSource.getSchoolYears(accessToken);
      // Cache success
      try {
        await localDataSource.cacheSchoolYears(years);
      } catch (e) {
        // Logging or silent fail on cache error, don't block UI
        // print('Cache error: $e');
      }
      return Right(years);
    } catch (e) {
      // If remote fails, try local
      try {
        final localYears = await localDataSource.getCachedSchoolYears();
        if (localYears.isNotEmpty) {
          return Right(localYears);
        }
      } catch (localError) {
        // If local also fails, ignore
      }

      if (e is Failure) return Left(e);
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Semester>> getCurrentSemester(
    String accessToken,
  ) async {
    try {
      final semester = await remoteDataSource.getCurrentSemester(accessToken);
      return Right(semester);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
