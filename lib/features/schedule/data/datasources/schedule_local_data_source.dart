import 'package:tlucalendar/features/schedule/domain/entities/course_hour.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/schedule/data/models/course_model.dart';
import 'package:tlucalendar/features/schedule/data/models/school_year_model.dart';
import 'package:tlucalendar/features/schedule/data/models/semester_model.dart';
import 'package:tlucalendar/services/database_helper.dart';

abstract class ScheduleLocalDataSource {
  Future<List<CourseModel>> getCachedCourses(int semesterId);
  Future<void> cacheCourses(int semesterId, List<CourseModel> courses);
  Future<List<SchoolYearModel>> getCachedSchoolYears();
  Future<void> cacheSchoolYears(List<SchoolYearModel> schoolYears);
  Future<void> cacheCourseHours(List<CourseHour> hours);
  Future<List<CourseHour>> getCachedCourseHours();
}

class ScheduleLocalDataSourceImpl implements ScheduleLocalDataSource {
  final DatabaseHelper databaseHelper;

  ScheduleLocalDataSourceImpl({required this.databaseHelper});

  @override
  Future<List<CourseModel>> getCachedCourses(int semesterId) async {
    try {
      return await databaseHelper.getCourses(semesterId);
    } catch (e) {
      throw CacheFailure(e.toString());
    }
  }

  @override
  Future<void> cacheCourses(int semesterId, List<CourseModel> courses) async {
    try {
      await databaseHelper.saveCourses(semesterId, courses);
    } catch (e) {
      throw CacheFailure(e.toString());
    }
  }

  @override
  Future<List<SchoolYearModel>> getCachedSchoolYears() async {
    try {
      final years = await databaseHelper.getSchoolYears();
      final semesters = await databaseHelper.getSemesters();

      // Stitch semesters to years
      // Helper to clone/create new SchoolYearModel with semesters
      return years.map((y) {
        final yearSemesters = semesters.where((s) {
          // Check intersection or inclusion. TLU logic: Semester falls in Year.
          return s.startDate >= y.startDate && s.startDate <= y.endDate;
        }).toList();

        // sort semesters descending
        yearSemesters.sort((a, b) => b.startDate.compareTo(a.startDate));

        return SchoolYearModel(
          id: y.id,
          name: y.name,
          code: y.code,
          year: y.year,
          current: y.current,
          startDate: y.startDate,
          endDate: y.endDate,
          displayName: y.displayName,
          semesters: yearSemesters,
        );
      }).toList();
    } catch (e) {
      throw CacheFailure(e.toString());
    }
  }

  @override
  Future<void> cacheSchoolYears(List<SchoolYearModel> schoolYears) async {
    try {
      await databaseHelper.saveSchoolYears(schoolYears);

      // Extract all semesters from the years to save them
      final allSemesters = schoolYears.expand((y) => y.semesters).map((s) {
        if (s is SemesterModel) return s;

        return SemesterModel(
          id: s.id,
          semesterCode: s.semesterCode,
          semesterName: s.semesterName,
          startDate: s.startDate,
          endDate: s.endDate,
          isCurrent: s.isCurrent,
          ordinalNumbers: s.ordinalNumbers,
        );
      }).toList();

      await databaseHelper.saveSemesters(allSemesters);
    } catch (e) {
      throw CacheFailure(e.toString());
    }
  }

  @override
  Future<void> cacheCourseHours(List<CourseHour> hours) async {
    try {
      final hourMap = {for (var h in hours) h.id: h};
      await databaseHelper.saveCourseHours(hourMap);
    } catch (e) {
      throw CacheFailure(e.toString());
    }
  }

  @override
  Future<List<CourseHour>> getCachedCourseHours() async {
    try {
      final hourMap = await databaseHelper.getCourseHours();
      return hourMap.values.toList();
    } catch (e) {
      throw CacheFailure(e.toString());
    }
  }
}
