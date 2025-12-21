import 'package:dio/dio.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/core/network/network_client.dart';
import 'package:tlucalendar/core/parser/json_parser.dart';
import 'package:tlucalendar/features/schedule/data/models/course_model.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course_hour.dart';
import 'package:tlucalendar/features/schedule/data/models/school_year_model.dart';
import 'package:tlucalendar/features/schedule/data/models/semester_model.dart';

abstract class ScheduleRemoteDataSource {
  Future<List<CourseModel>> getCourses(int semesterId, String accessToken);
  Future<List<CourseHour>> getCourseHours(String accessToken);
  Future<List<SchoolYearModel>> getSchoolYears(String accessToken);
  Future<SemesterModel> getCurrentSemester(String accessToken);
}

class ScheduleRemoteDataSourceImpl implements ScheduleRemoteDataSource {
  final NetworkClient client;
  final JsonParser jsonParser;

  ScheduleRemoteDataSourceImpl({
    required this.client,
    required this.jsonParser,
  });

  @override
  Future<List<CourseModel>> getCourses(
    int semesterId,
    String accessToken,
  ) async {
    try {
      final response = await client.get(
        '/api/StudentCourseSubject/studentLoginUser/$semesterId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> rawList = response.data is String
            ? jsonParser.parseList(response.data)
            : response.data as List<dynamic>;

        final List<CourseModel> courses = [];

        // This Logic mimics the original functionality:
        // Some courses might have multiple timetables and need expansion.
        // Or if the API returns them already expanded or nested...
        // The original logic in `AuthService.getStudentCourseSubject` did expansion.
        // Let's implement that expansion logic here if needed, or rely on `CourseModel.fromJson`.
        // BUT `CourseModel.fromJson` only takes one Map.
        // The expansion usually means one JSON object -> Multiple Course Objects.

        for (var item in rawList) {
          // Check for multiple timetables and expand
          final courseSubject = item['courseSubject'];
          if (courseSubject != null &&
              courseSubject['timetables'] is List &&
              (courseSubject['timetables'] as List).length > 1) {
            final timetables = courseSubject['timetables'] as List;
            for (var timetable in timetables) {
              // Create a copy of the item but replace/augment data for this specific timetable
              // This is tricky because `CourseModel.fromJson` currently picks the [0]th timetable.
              // We need a way to pass the specific timetable to the model factory.

              // Simplification for now: Clone the item map and put the specific timetable at index 0
              final itemCopy = Map<String, dynamic>.from(item);
              final courseSubjectCopy = Map<String, dynamic>.from(
                courseSubject,
              );
              courseSubjectCopy['timetables'] = [timetable];
              itemCopy['courseSubject'] = courseSubjectCopy;

              courses.add(CourseModel.fromJson(itemCopy));
            }
          } else {
            // Standard case
            courses.add(CourseModel.fromJson(item));
          }
        }

        return courses;
      } else {
        throw ServerFailure('Get Courses failed: ${response.statusCode}');
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<CourseHour>> getCourseHours(String accessToken) async {
    try {
      final response = await client.get(
        '/api/coursehour/1/1000',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data is String
            ? jsonParser.parse(response.data)
            : response.data as Map<String, dynamic>;

        List<dynamic> content = data['content'] ?? [];

        return content
            .map(
              (json) => CourseHour(
                id: json['id'],
                name: json['name'],
                startString: json['startString'],
                endString: json['endString'],
                indexNumber: json['indexNumber'],
              ),
            )
            .toList();
      } else {
        throw ServerFailure('Get CourseHours failed: ${response.statusCode}');
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<SchoolYearModel>> getSchoolYears(String accessToken) async {
    try {
      final response = await client.get(
        '/api/schoolyear/1/10000',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data is String
            ? jsonParser.parse(response.data)
            : response.data as Map<String, dynamic>;

        List<dynamic> content = data['content'] ?? [];

        return content.map((json) => SchoolYearModel.fromJson(json)).toList();
      } else {
        throw ServerFailure('Get SchoolYears failed: ${response.statusCode}');
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<SemesterModel> getCurrentSemester(String accessToken) async {
    try {
      final response = await client.get(
        '/api/semester/semester_info',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data is String
            ? jsonParser.parse(response.data)
            : response.data as Map<String, dynamic>;

        return SemesterModel.fromJson(data);
      } else {
        throw ServerFailure(
          'Get CurrentSemester failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
