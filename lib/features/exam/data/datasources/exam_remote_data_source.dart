import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/core/network/network_client.dart';
import 'package:tlucalendar/core/parser/json_parser.dart';
import 'package:tlucalendar/features/exam/data/models/exam_room_model.dart';
import 'package:tlucalendar/features/exam/data/models/exam_schedule_model.dart';
import 'package:tlucalendar/core/native/native_parser.dart';

abstract class ExamRemoteDataSource {
  Future<List<ExamScheduleModel>> getExamSchedules(
    int semesterId,
    String accessToken,
    Map<String, dynamic>? rawToken,
  );
  Future<List<ExamRoomModel>> getExamRooms({
    required int semesterId,
    required int scheduleId, // registerPeriodId
    required int round,
    required String accessToken,
    Map<String, dynamic>? rawToken,
  });
}

class ExamRemoteDataSourceImpl implements ExamRemoteDataSource {
  final NetworkClient client;
  final JsonParser jsonParser;

  ExamRemoteDataSourceImpl({required this.client, required this.jsonParser});

  @override
  Future<List<ExamScheduleModel>> getExamSchedules(
    int semesterId,
    String accessToken,
    Map<String, dynamic>? rawToken,
  ) async {
    try {
      final cookieValue = rawToken != null
          ? 'token=${Uri.encodeComponent(jsonEncode(rawToken))}'
          : 'token=${Uri.encodeComponent('{"access_token":"$accessToken","token_type":"bearer"}')}';

      final response = await client.get(
        '/api/registerperiod/find/$semesterId',
        options: Options(
          responseType:
              ResponseType.plain, // Request raw string for Native Parser
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
            'Cookie': cookieValue,
          },
        ),
      );

      if (response.statusCode == 200) {
        // response.data is String because of ResponseType.plain
        return NativeParser.parseExamSchedules(response.data as String);
      } else {
        throw ServerFailure(
          'Get ExamSchedules failed: ${response.statusCode}, Body: ${response.data}',
        );
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<ExamRoomModel>> getExamRooms({
    required int semesterId,
    required int scheduleId,
    required int round,
    required String accessToken,
    Map<String, dynamic>? rawToken,
  }) async {
    try {
      final cookieValue = rawToken != null
          ? 'token=${Uri.encodeComponent(jsonEncode(rawToken))}'
          : 'token=${Uri.encodeComponent('{"access_token":"$accessToken","token_type":"bearer"}')}';

      final response = await client.get(
        '/api/semestersubjectexamroom/getListRoomByStudentByLoginUser/$semesterId/$scheduleId/$round',
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
            'Cookie': cookieValue,
          },
        ),
      );

      if (response.statusCode == 200) {
        // response.data is string
        return NativeParser.parseExamRooms(response.data as String);
      } else {
        throw ServerFailure(
          'Get ExamRooms failed: ${response.statusCode}, Body: ${response.data}',
        );
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
