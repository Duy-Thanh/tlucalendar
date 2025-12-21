import 'package:dartz/dartz.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course_hour.dart';
import 'package:tlucalendar/features/schedule/domain/entities/school_year.dart';
import 'package:tlucalendar/features/schedule/domain/entities/semester.dart';

abstract class ScheduleRepository {
  /// Get list of courses for a specific semester
  Future<Either<Failure, List<Course>>> getCourses(
    int semesterId,
    String accessToken,
  );

  /// Get course hours (time slots)
  Future<Either<Failure, List<CourseHour>>> getCourseHours(String accessToken);

  /// Get cached courses only (for offline)
  Future<Either<Failure, List<Course>>> getCachedCourses(int semesterId);

  /// Get school years
  Future<Either<Failure, List<SchoolYear>>> getSchoolYears(String accessToken);

  /// Get current semester info
  Future<Either<Failure, Semester>> getCurrentSemester(String accessToken);
}
