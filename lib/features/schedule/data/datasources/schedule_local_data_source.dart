import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/schedule/data/models/course_model.dart';
import 'package:tlucalendar/services/database_helper.dart';

abstract class ScheduleLocalDataSource {
  Future<List<CourseModel>> getCachedCourses(int semesterId);
  Future<void> cacheCourses(int semesterId, List<CourseModel> courses);
}

class ScheduleLocalDataSourceImpl implements ScheduleLocalDataSource {
  final DatabaseHelper databaseHelper;

  ScheduleLocalDataSourceImpl({required this.databaseHelper});

  @override
  Future<List<CourseModel>> getCachedCourses(int semesterId) async {
    try {
      final studentCourses = await databaseHelper.getStudentCourses(semesterId);

      // Convert `StudentCourseSubject` (infra model) to `CourseModel` (Clean Arch model)
      // Since `StudentCourseSubject` fields match `CourseModel` (Entity) fields almost 1:1,
      // we can map them.

      return studentCourses
          .map(
            (e) => CourseModel(
              id: e.id,
              courseCode: e.courseCode,
              courseName: e.courseName,
              classCode: e.classCode,
              className: e.className,
              dayOfWeek: e.dayOfWeek,
              startCourseHour: e.startCourseHour,
              endCourseHour: e.endCourseHour,
              room: e.room,
              building: e.building,
              campus: e.campus,
              credits: e.credits,
              startDate: e.startDate.toInt(),
              endDate: e.endDate.toInt(),
              fromWeek: e.fromWeek,
              toWeek: e.toWeek,
              status: e.status,
              grade: e.grade,
              lecturerName: e.lecturer?.name,
              lecturerEmail: e.lecturer?.email,
            ),
          )
          .toList();
    } catch (e) {
      throw CacheFailure(e.toString());
    }
  }

  @override
  Future<void> cacheCourses(int semesterId, List<CourseModel> courses) async {
    // We need to convert `CourseModel` back to `StudentCourseSubject` to use `DatabaseHelper`.
    // Or refactor `DatabaseHelper`. For now, adapting is safer/faster.

    // Actually, `DatabaseHelper` expects `StudentCourseSubject`.
    // I should create a mapper or temporary use `api_response` classes in Data Layer
    // simply for bridging with the legacy DB helper.

    // However, `CourseModel` doesn't have `toJson` for DB yet?
    // `DatabaseHelper` uses its own manual mapping.

    // Skipping this for now as `UserProvider` currently handles caching via `DatabaseHelper`.
    // I will let `UserProvider` continue to manage caching for Phase 1 to avoid breaking offline mode,
    // OR implement the mapping here.

    throw UnimplementedError('Caching handled by legacy code for now');
  }
}
