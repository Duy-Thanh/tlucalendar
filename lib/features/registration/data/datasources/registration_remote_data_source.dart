import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart'; // Needed for debugPrint
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/core/native/native_parser.dart';
import 'package:tlucalendar/core/network/network_client.dart';

import 'package:tlucalendar/features/registration/domain/entities/subject_registration.dart';

abstract class RegistrationRemoteDataSource {
  Future<List<SubjectRegistration>> getRegistrationData(
    String personId,
    String periodId,
    String accessToken,
  );
  Future<void> registerCourse(
    String personId,
    String periodId,
    String courseId,
    String accessToken,
  );
  Future<void> cancelCourse(
    String personId,
    String periodId,
    String courseId,
    String accessToken,
  );
}

class RegistrationRemoteDataSourceImpl implements RegistrationRemoteDataSource {
  final NetworkClient client;

  RegistrationRemoteDataSourceImpl({required this.client});

  @override
  Future<List<SubjectRegistration>> getRegistrationData(
    String personId,
    String periodId,
    String accessToken,
  ) async {
    try {
      final response = await client.get(
        '/education/api/cs_reg_mongo/findByPeriod/$personId/$periodId',
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
      // debugPrint("REGISTRATION JSON: $jsonStr"); // Use simple print or log
      print("REGISTRATION JSON: $jsonStr");
      return NativeParser.parseRegistrationData(jsonStr);
    } on DioException catch (e) {
      throw ServerFailure(e.message ?? 'Unknown Dio Error');
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> registerCourse(
    String personId,
    String periodId,
    String courseString,
    String accessToken,
  ) async {
    try {
      final response = await client.post(
        '/education/api/cs_reg_mongo/add-register/$personId/$periodId',
        data: courseString,
        options: Options(
          contentType: 'application/json',
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
          responseType: ResponseType.plain, // Force plain text
        ),
      );

      final jsonStr = response.data.toString();

      // [REVIEW MODE] Check for Fake Success (Robust Parsing)
      if (jsonStr.contains("Action completed")) {
        debugPrint(
          "ReviewMode Check: Found 'Action completed' string. Throwing Signal.",
        );
        throw const ReviewModeSuccessFailure();
      }

      final result = NativeParser.parseRegistrationAction(jsonStr);

      if (!result.success && result.status != 0) {
        throw ServerFailure(
          result.message.isNotEmpty
              ? result.message
              : "Đăng ký thất bại (Status: ${result.status})",
        );
      }
    } on DioException catch (e) {
      throw ServerFailure(e.message ?? 'Unknown Dio Error');
    } catch (e) {
      if (e is ServerFailure) rethrow;
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> cancelCourse(
    String personId,
    String periodId,
    String courseString,
    String accessToken,
  ) async {
    try {
      final response = await client.delete(
        '/education/api/cs_reg_mongo/remove-register/$personId/$periodId',
        data: courseString,
        options: Options(
          contentType: 'application/json',
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
          responseType: ResponseType.plain, // Force plain text
        ),
      );

      final jsonStr = response.data.toString();

      // [REVIEW MODE] Check for Fake Success (Robust Parsing)
      if (jsonStr.contains("Action completed")) {
        debugPrint(
          "ReviewMode Check: Found 'Action completed' string. Throwing Signal.",
        );
        throw const ReviewModeSuccessFailure();
      }

      final result = NativeParser.parseRegistrationAction(jsonStr);

      if (!result.success && result.status != 0) {
        throw ServerFailure(
          result.message.isNotEmpty
              ? result.message
              : "Hủy đăng ký thất bại (Status: ${result.status})",
        );
      }
    } on DioException catch (e) {
      throw ServerFailure(e.message ?? 'Unknown Dio Error');
    } catch (e) {
      if (e is ServerFailure) rethrow;
      throw ServerFailure(e.toString());
    }
  }
}
