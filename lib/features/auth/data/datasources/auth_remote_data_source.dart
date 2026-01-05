import 'package:dio/dio.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/core/network/network_client.dart';

import 'package:tlucalendar/features/auth/data/models/user_model.dart';
import 'package:tlucalendar/core/native/native_parser.dart';

abstract class AuthRemoteDataSource {
  Future<Map<String, dynamic>> login(String studentCode, String password);
  Future<UserModel> getCurrentUser(String accessToken);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final NetworkClient client;

  AuthRemoteDataSourceImpl({required this.client});

  static const String _tokenEndpoint = '/login';
  static const String _userEndpoint = '/api/users/getCurrentUser';
  // Client secrets handled by Worker now
  // static const String _clientId = 'education_client';
  // static const String _clientSecret = 'password';
  // static const String _grantType = 'password';

  @override
  Future<Map<String, dynamic>> login(
    String studentCode,
    String password,
  ) async {
    try {
      // Simplified Login via Cloudflare Worker
      // Worker handles JSON -> Form Data conversion and Secret injection
      final response = await client.post(
        _tokenEndpoint,
        data: {'studentCode': studentCode, 'password': password},
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.plain,
        ),
        // Headers are already 'application/json' by default in Dio/NetworkClient
      );

      if (response.statusCode == 200) {
        return NativeParser.parseToken(response.data as String) ?? {};
      } else {
        throw ServerFailure('Login failed: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Failure) rethrow; // Pass through known failures
      throw ServerFailure('Login error: $e');
    }
  }

  @override
  Future<UserModel> getCurrentUser(String accessToken) async {
    try {
      final response = await client.get(
        _userEndpoint,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return NativeParser.parseUser(response.data as String) ??
            const UserModel(
              studentId: '',
              fullName: '',
              email: '',
              profileImageUrl: null,
            );
      } else {
        throw ServerFailure('Get User failed: ${response.statusCode}');
      }
    } catch (e) {
      throw ServerFailure('Get User error: $e');
    }
  }
}
