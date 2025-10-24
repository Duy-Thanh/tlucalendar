import 'dart:convert';
import 'dart:io';
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
      // Use dart:io HttpClient with SSL verification disabled
      final httpClient = HttpClient()
        ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      
      final request = await httpClient.postUrl(Uri.parse('$baseUrl$tokenEndpoint'));
      request.headers.contentType = ContentType('application', 'x-www-form-urlencoded');
      request.headers.add('Accept', 'application/json');
      
      // Add form data
      request.write('client_id=$clientId&client_secret=$clientSecret&grant_type=$grantType&username=$studentCode&password=$password');
      
      final response = await request.close().timeout(const Duration(seconds: 30));
      final responseBody = await response.transform(utf8.decoder).join();

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
      final httpClient = HttpClient()
        ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      
      final request = await httpClient.getUrl(Uri.parse('$baseUrl$userEndpoint'));
      request.headers.add('Authorization', 'Bearer $accessToken');
      request.headers.add('Accept', 'application/json');

      final response = await request.close().timeout(const Duration(seconds: 30));
      final responseBody = await response.transform(utf8.decoder).join();

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

  /// Check if access token is still valid
  Future<bool> isTokenValid(String accessToken) async {
    try {
      final httpClient = HttpClient()
        ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      
      final request = await httpClient.getUrl(Uri.parse('$baseUrl$userEndpoint'));
      request.headers.add('Authorization', 'Bearer $accessToken');
      
      final response = await request.close().timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Fetch school years and semesters
  /// Endpoint: GET /api/schoolyear/1/10000
  Future<SchoolYearResponse> getSchoolYears(String accessToken) async {
    try {
      final httpClient = HttpClient()
        ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      
      final request = await httpClient.getUrl(Uri.parse('$baseUrl/api/schoolyear/1/10000'));
      request.headers.add('Authorization', 'Bearer $accessToken');
      request.headers.add('Accept', 'application/json');

      final response = await request.close().timeout(const Duration(seconds: 30));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody);
        return SchoolYearResponse.fromJson(jsonResponse);
      } else {
        throw Exception('Không thể lấy dữ liệu năm học (${response.statusCode})');
      }
    } catch (e) {
      if (e.toString().contains('CERTIFICATE_VERIFY_FAILED')) {
        throw Exception('Lỗi chứng chỉ SSL. Vui lòng thử lại.');
      }
      throw Exception('Lỗi lấy dữ liệu năm học: $e');
    }
  }
}
