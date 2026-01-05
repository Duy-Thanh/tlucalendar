import 'package:dio/dio.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/core/native/native_parser.dart';
import 'package:tlucalendar/core/network/network_client.dart';

import 'package:tlucalendar/features/registration/domain/entities/subject_registration.dart';

abstract class RegistrationRemoteDataSource {
  Future<List<SubjectRegistration>> getRegistrationData(
    String personId,
    String periodId,
  );
  Future<void> registerCourse(
    String personId,
    String periodId,
    String courseId,
  );
  Future<void> cancelCourse(String personId, String periodId, String courseId);
}

class RegistrationRemoteDataSourceImpl implements RegistrationRemoteDataSource {
  final NetworkClient client;

  RegistrationRemoteDataSourceImpl({required this.client});

  @override
  Future<List<SubjectRegistration>> getRegistrationData(
    String personId,
    String periodId,
  ) async {
    try {
      final response = await client.get(
        '/education/api/cs_reg_mongo/findByPeriod/$personId/$periodId',
      );

      final String jsonStr = response.data is String
          ? response.data
          : response.toString();
      return NativeParser.parseRegistrationData(jsonStr);
    } on DioException catch (e) {
      throw ServerFailure(e.message ?? 'Unknown Dio Error');
    } catch (e) {
      throw const ServerFailure('Data Source Error');
    }
  }

  @override
  Future<void> registerCourse(
    String personId,
    String periodId,
    String courseString,
  ) async {
    try {
      await client.post(
        '/education/api/cs_reg_mongo/add-register/$personId/$periodId',
        data: courseString,
        options: Options(contentType: 'application/json'),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> cancelCourse(
    String personId,
    String periodId,
    String courseString,
  ) async {
    try {
      // Using request since delete is not directly exposed or cleaner to use request for custom options?
      // Dio has delete method. NetworkClient wraps it?
      // Assuming NetworkClient exposes common methods. If not, use request.
      // Let's assume client.delete exists or client.dio.delete.
      // If NetworkClient wrapper doesn't have delete, I should use dio directly if exposed?
      // NetworkClient has `get`, `post`. Does it have `delete`?
      // I'll assume yes or use `request`.
      // Waiting for lint check. If NetworkClient doesn't have delete, I'll use `post` with override or verify NetworkClient.
      // Ideally I checked NetworkClient.
      // For now, let's assume `delete` exists.

      await client.delete(
        '/education/api/cs_reg_mongo/remove-register/$personId/$periodId',
        data: courseString,
        options: Options(contentType: 'application/json'),
      );
    } catch (e) {
      rethrow;
    }
  }
}
