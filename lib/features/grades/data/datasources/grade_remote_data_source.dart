import 'package:dio/dio.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/core/native/native_parser.dart';
import 'package:tlucalendar/core/network/network_client.dart';
import 'package:tlucalendar/features/grades/data/models/student_mark_model.dart';

abstract class GradeRemoteDataSource {
  Future<List<StudentMarkModel>> getGrades(String accessToken);
}

class GradeRemoteDataSourceImpl implements GradeRemoteDataSource {
  final NetworkClient client;

  GradeRemoteDataSourceImpl({required this.client});

  @override
  Future<List<StudentMarkModel>> getGrades(String accessToken) async {
    try {
      // API to get ALL grades (SemesterId = 0 usually means all or current context, based on C# Analysis)
      // C# Code: client.GetAsync(".../education/api/studentsubjectmark/getListStudentMarkBySemesterByLoginUser/0")
      final response = await client.get(
        '/education/api/studentsubjectmark/getListStudentMarkBySemesterByLoginUser/0',
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      final String jsonStr = response.data is String
          ? response.data
          : response.toString();

      // debugPrint("GRADES JSON: $jsonStr");

      return NativeParser.parseStudentMarks(jsonStr);
    } on DioException catch (e) {
      throw ServerFailure(e.message ?? 'Unknown Dio Error');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
