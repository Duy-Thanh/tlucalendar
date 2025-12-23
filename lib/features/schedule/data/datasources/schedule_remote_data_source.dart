import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // for compute
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/core/network/network_client.dart';

import 'package:tlucalendar/features/schedule/data/models/course_model.dart';
import 'package:tlucalendar/core/native/native_parser.dart';
import 'package:tlucalendar/features/schedule/domain/entities/course_hour.dart';
import 'package:tlucalendar/features/schedule/data/models/school_year_model.dart';
import 'package:tlucalendar/features/schedule/data/models/semester_model.dart';

//
abstract class ScheduleRemoteDataSource {
  Future<List<CourseModel>> getCourses(int semesterId, String accessToken);
  Future<List<CourseHour>> getCourseHours(String accessToken);
  Future<List<SchoolYearModel>> getSchoolYears(String accessToken);
  Future<SemesterModel> getCurrentSemester(String accessToken);
}

class ScheduleRemoteDataSourceImpl implements ScheduleRemoteDataSource {
  final NetworkClient client;

  ScheduleRemoteDataSourceImpl({required this.client});

  @override
  Future<List<CourseModel>> getCourses(
    int semesterId,
    String accessToken,
  ) async {
    try {
      final response = await client.get(
        '/api/StudentCourseSubject/studentLoginUser/$semesterId',
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        // Run Native Parsing in a separate Isolate to avoid Main Thread GC Jank
        return compute(NativeParser.parseCourses, response.data as String);
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
          responseType: ResponseType.plain,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        // Run Native Parsing in a separate Isolate
        return compute(NativeParser.parseCourseHours, response.data as String);
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
          responseType: ResponseType.plain,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        // Run Native Parsing in a separate Isolate
        return compute(NativeParser.parseSchoolYears, response.data as String);
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
          responseType: ResponseType.plain,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        // Run Native Parsing in a separate Isolate
        // Note: parseSemester returns nullable, so we handle it inside wrapper if needed,
        // but compute works with function returning nullable too.
        // However, parseSemester returns SemesterResult? or Model?
        // It currently returns SemesterModel?.
        final result = await compute(
          NativeParser.parseSemester,
          response.data as String,
        );
        return result ??
            SemesterModel(
              id: 0,
              semesterCode: '',
              semesterName: '',
              startDate: 0,
              endDate: 0,
              isCurrent: false,
            );
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
