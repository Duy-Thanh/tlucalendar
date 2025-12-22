import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/features/schedule/data/models/course_model.dart';
import 'package:tlucalendar/features/schedule/data/models/school_year_model.dart';
import 'package:tlucalendar/features/schedule/data/models/semester_model.dart';
import 'package:tlucalendar/services/database_helper.dart';
// Import legacy models with an alias to avoid conflict
import 'package:tlucalendar/models/api_response.dart' as Legacy;

abstract class ScheduleLocalDataSource {
  Future<List<CourseModel>> getCachedCourses(int semesterId);
  Future<void> cacheCourses(int semesterId, List<CourseModel> courses);
  Future<List<SchoolYearModel>> getCachedSchoolYears();
  Future<void> cacheSchoolYears(List<SchoolYearModel> schoolYears);
}

class ScheduleLocalDataSourceImpl implements ScheduleLocalDataSource {
  final DatabaseHelper databaseHelper;

  ScheduleLocalDataSourceImpl({required this.databaseHelper});

  @override
  Future<List<CourseModel>> getCachedCourses(int semesterId) async {
    try {
      final studentCourses = await databaseHelper.getStudentCourses(semesterId);

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
    // Legacy caching logic (UserProvider might handle this, or we should implement)
    throw UnimplementedError('Caching handled by legacy code for now');
  }

  @override
  Future<List<SchoolYearModel>> getCachedSchoolYears() async {
    try {
      // Returns List<Legacy.SchoolYear>
      final legacyYears = await databaseHelper.getSchoolYears();
      // Returns List<Legacy.Semester>
      final legacySemesters = await databaseHelper.getSemesters();

      return legacyYears.map((y) {
        // Filter semesters for this year from the flat list
        final yearSemesters = legacySemesters.where((s) {
          // TLU Semester usually falls within School Year range
          return s.startDate >= y.startDate && s.startDate <= y.endDate;
        }).toList();

        // Convert Legacy.Semester -> Clean Arch SemesterModel
        final semesterModels = yearSemesters
            .map(
              (s) => SemesterModel(
                id: s.id,
                semesterCode: s.semesterCode,
                semesterName: s.semesterName,
                startDate: s.startDate,
                endDate: s.endDate,
                isCurrent: s.isCurrent,
                ordinalNumbers: s.ordinalNumbers,
              ),
            )
            .toList();

        // Convert Legacy.SchoolYear -> Clean Arch SchoolYearModel
        return SchoolYearModel(
          id: y.id,
          name: y.name,
          code: y.code,
          year: y.year,
          current: y.current,
          startDate: y.startDate,
          endDate: y.endDate,
          displayName: y.displayName,
          semesters: semesterModels,
        );
      }).toList();
    } catch (e) {
      throw CacheFailure(e.toString());
    }
  }

  @override
  Future<void> cacheSchoolYears(List<SchoolYearModel> schoolYears) async {
    try {
      // 1. Convert Clean Arch SchoolYearModel -> Legacy.SchoolYear
      final legacyYears = schoolYears.map((y) {
        return Legacy.SchoolYear(
          id: y.id,
          name: y.name,
          code: y.code,
          year: y.year,
          current: y.current,
          startDate: y.startDate,
          endDate: y.endDate,
          displayName: y.displayName,
          semesters: [], // Semesters saved separately in DB helper strategy
        );
      }).toList();

      await databaseHelper.saveSchoolYears(legacyYears);

      // 2. Extract and Convert Clean Arch SemesterModel -> Legacy.Semester
      final allSemesters = schoolYears.expand((y) => y.semesters).map((s) {
        return Legacy.Semester(
          id: s.id,
          semesterCode: s.semesterCode,
          semesterName: s.semesterName,
          startDate: s.startDate,
          endDate: s.endDate,
          isCurrent: s.isCurrent,
          ordinalNumbers: s.ordinalNumbers,
          semesterRegisterPeriods: [], // Not critical for basic schedule sync
        );
      }).toList();

      await databaseHelper.saveSemesters(allSemesters);
    } catch (e) {
      throw CacheFailure(e.toString());
    }
  }
}
