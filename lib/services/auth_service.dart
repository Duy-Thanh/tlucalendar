import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tlucalendar/models/api_response.dart';

class AuthService {
  static const String baseUrl = 'https://sinhvien1.tlu.edu.vn/education';
  static const String tokenEndpoint = '/oauth/token';
  static const String userEndpoint = '/api/users/getCurrentUser';
  
  // OAuth credentials (fixed by TLU)
  static const String clientId = 'education_client';
  static const String clientSecret = 'password';
  static const String grantType = 'password';

  /// Authenticate user with student code and password
  Future<LoginResponse> login(String studentCode, String password) async {
    try {
      final request = http.Request('POST', Uri.parse('$baseUrl$tokenEndpoint'));
      request.headers.update('Content-Type', (_) => 'application/x-www-form-urlencoded', ifAbsent: () => 'application/x-www-form-urlencoded');
      request.headers['Accept'] = 'application/json';
      request.bodyFields = {
        'client_id': clientId,
        'client_secret': clientSecret,
        'grant_type': grantType,
        'username': studentCode,
        'password': password,
      };

      final response = await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody);
        return LoginResponse.fromJson(jsonResponse);
      } else {
        try {
          final errorBody = jsonDecode(responseBody);
          final errorDesc = errorBody['error_description'] ?? 'Đăng nhập thất bại';
          throw Exception(errorDesc);
        } catch (e) {
          throw Exception('Đăng nhập thất bại: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (e.toString().contains('CERTIFICATE_VERIFY_FAILED')) {
        throw Exception('Lỗi chứng chỉ SSL. Vui lòng thử lại.');
      } else if (e.toString().contains('Connection refused') || e.toString().contains('Network is unreachable')) {
        throw Exception('Không thể kết nối. Kiểm tra internet của bạn.');
      } else if (e.toString().contains('timed out')) {
        throw Exception('Timeout kết nối. Vui lòng kiểm tra internet.');
      }
      throw Exception('Lỗi đăng nhập: $e');
    }
  }

  /// Fetch current user information using access token
  Future<TluUser> getCurrentUser(String accessToken) async {
    try {
      final request = http.Request('GET', Uri.parse('$baseUrl$userEndpoint'));
      request.headers['Authorization'] = 'Bearer $accessToken';
      request.headers['Accept'] = 'application/json';

      final response = await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody);
        return TluUser.fromJson(jsonResponse);
      } else {
        throw Exception('Không thể lấy dữ liệu người dùng (${response.statusCode})');
      }
    } catch (e) {
      if (e.toString().contains('CERTIFICATE_VERIFY_FAILED')) {
        throw Exception('Lỗi chứng chỉ SSL. Vui lòng thử lại.');
      }
      throw Exception('Lỗi lấy dữ liệu: $e');
    }
  }

  /// Verify if token is still valid
  Future<bool> isTokenValid(String accessToken) async {
    try {
      final request = http.Request('GET', Uri.parse('$baseUrl$userEndpoint'));
      request.headers['Authorization'] = 'Bearer $accessToken';

      final response = await request.send().timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
