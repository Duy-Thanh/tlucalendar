import 'package:dio/dio.dart';
import 'package:tlucalendar/core/error/failures.dart';
import 'package:tlucalendar/core/network/network_client.dart';
import 'package:tlucalendar/core/parser/json_parser.dart';
import 'package:tlucalendar/features/auth/data/models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<Map<String, dynamic>> login(String studentCode, String password);
  Future<UserModel> getCurrentUser(String accessToken);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final NetworkClient client;
  final JsonParser jsonParser;

  AuthRemoteDataSourceImpl({required this.client, required this.jsonParser});

  static const String _tokenEndpoint = '/oauth/token';
  static const String _userEndpoint = '/api/users/getCurrentUser';
  static const String _clientId = 'education_client';
  static const String _clientSecret = 'password';
  static const String _grantType = 'password';

  @override
  Future<Map<String, dynamic>> login(
    String studentCode,
    String password,
  ) async {
    try {
      // Use form-urlencoded for token endpoint
      final response = await client.post(
        _tokenEndpoint,
        data: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'grant_type': _grantType,
          'username': studentCode,
          'password': password,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      if (response.statusCode == 200) {
        final data = response.data is String
            ? jsonParser.parse(response.data)
            : response.data as Map<String, dynamic>;

        return data;
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

        return UserModel.fromJson(data);
      } else {
        throw ServerFailure('Get User failed: ${response.statusCode}');
      }
    } catch (e) {
      throw ServerFailure('Get User error: $e');
    }
  }
}
