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
  );
  Future<List<ExamRoomModel>> getExamRooms({
    required int semesterId,
    required int scheduleId, // registerPeriodId
    required int round,
    required String accessToken,
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
  ) async {
    try {
      final response = await client.get(
        '/api/semestersubjectexamroom/getListRegisterPeriod/$semesterId',
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
  }) async {
    try {
      final response = await client.get(
        '/api/semestersubjectexamroom/getListRoomByStudentByLoginUser/$semesterId/$scheduleId/$round',
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
