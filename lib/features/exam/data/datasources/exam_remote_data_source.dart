import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/core/network/network_client.dart';
import 'package:tlucalendar/core/parser/json_parser.dart';
import 'package:tlucalendar/features/exam/data/models/exam_room_model.dart';
import 'package:tlucalendar/features/exam/data/models/exam_schedule_model.dart';

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

      print('----- DEBUG EXAM REQUEST -----');
      print('Entries in rawToken: ${rawToken?.length}');
      print('Keys in rawToken: ${rawToken?.keys.toList()}');
      print('Generated Cookie: $cookieValue');
      print('------------------------------');

      final response = await client.get(
        '/api/registerperiod/find/$semesterId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
            'Cookie': cookieValue,
          },
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> rawList = response.data is String
            ? jsonParser.parseList(response.data)
            : response.data as List<dynamic>;

        return rawList.map((json) => ExamScheduleModel.fromJson(json)).toList();
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
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
            'Cookie': cookieValue,
          },
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> rawList = response.data is String
            ? jsonParser.parseList(response.data)
            : response.data as List<dynamic>;

        return rawList.map((json) => ExamRoomModel.fromJson(json)).toList();
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
