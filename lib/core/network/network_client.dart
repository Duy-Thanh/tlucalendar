import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:tlucalendar/core/error/failures.dart';

class NetworkClient {
  late final Dio _dio;

  NetworkClient({required String baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 120),
        receiveTimeout: const Duration(seconds: 120),
        validateStatus: (status) => status != null && status < 500,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://sinhvien1.tlu.edu.vn/',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Encoding': 'gzip, deflate, br',
        },
      ),
    );

    // Aggressive Retry Strategy for High Load
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        logPrint: (message) => debugPrint('[Retry] $message'),
        retries: 5, // Reduced from 10 to 5 to avoid spamming user logs too much
        retryDelays: const [
          Duration(seconds: 1), // Lần 1 chờ 1s
          Duration(seconds: 3), // Lần 2 chờ 3s
          Duration(seconds: 5), // Lần 3 chờ 5s
          Duration(seconds: 10), // Lần 4 chờ 10s
          Duration(seconds: 20), // Lần 5 chốt hạ 20s
        ],
        retryableExtraStatuses: {
          // =================================================================
          // 1. NHÓM TIÊU CHUẨN (STANDARD HTTP CODES)
          // =================================================================
          // --- 4xx: Client Error (Mày sai hoặc Server chặn) ---
          400, // Bad Request
          402, // Payment Required
          403, // Forbidden (Hay gặp khi bị chặn IP/WAF)
          405, // Method Not Allowed
          406, // Not Acceptable
          407, // Proxy Authentication Required
          408, // Request Timeout (RETRY MẠNH)
          409, // Conflict
          410, // Gone
          411, // Length Required
          412, // Precondition Failed
          413, // Payload Too Large
          414, // URI Too Long
          415, // Unsupported Media Type
          416, // Range Not Satisfiable
          417, // Expectation Failed
          418, // I'm a teapot (Server troll)
          421, // Misdirected Request
          422, // Unprocessable Entity
          423, // Locked (WebDAV)
          424, // Failed Dependency (WebDAV)
          425, // Too Early
          426, // Upgrade Required
          428, // Precondition Required
          429, // Too Many Requests (RETRY PHẢI CÓ DELAY)
          431, // Request Header Fields Too Large
          451, // Unavailable For Legal Reasons
          // --- 5xx: Server Error (Server chết/ngáo) ---
          500, // Internal Server Error
          501, // Not Implemented
          502, // Bad Gateway
          503, // Service Unavailable (Server bảo trì)
          504, // Gateway Timeout (RETRY MẠNH)
          505, // HTTP Version Not Supported
          506, // Variant Also Negotiates
          507, // Insufficient Storage (WebDAV)
          508, // Loop Detected (WebDAV)
          510, // Not Extended
          511, // Network Authentication Required
          // =================================================================
          // 2. NHÓM KHÔNG CHÍNH THỨC & SERVER CỤ THỂ (UNOFFICIAL/CUSTOM)
          // =================================================================

          // --- Nginx (Web Server phổ biến nhất thế giới) ---
          444, // No Response (Server cắt kết nối luôn, không trả về gì)
          494, // Request header too large
          495, // SSL Certificate Error
          496, // SSL Certificate Required
          497, // HTTP Request Sent to HTTPS Port
          499, // Client Closed Request (Mày tắt app khi đang load)
          // --- Cloudflare (Nếu trường mày dùng cái này để chống DDOS) ---
          520, // Web Server Returned an Unknown Error
          521, // Web Server Is Down (Server trường sập nguồn)
          522, // Connection Timed Out (Kết nối tới trường quá lâu)
          523, // Origin Is Unreachable
          524, // A Timeout Occurred
          525, // SSL Handshake Failed
          526, // Invalid SSL Certificate
          527, // Railgun Error
          530, // Site is frozen
          // --- Microsoft / IIS ---
          440, // Login Time-out
          449, // Retry With (Bảo mày thử lại đi)
          450, // Blocked by Windows Parental Controls (Bố mẹ cấm)
          // --- Các mã lỗi linh tinh khác (AWS, Laravel, Twitter...) ---
          419, // Page Expired (Laravel: CSRF Token hết hạn)
          420, // Method Enhanced Your Calm (Twitter cũ: Spam nhiều quá)
          430, // Request Header Fields Too Large (Shopify)
          460, // Client closed the connection (AWS ELB)
          463, // X-Forwarded-For header error (AWS ELB)
          498, // Invalid Token (Esri)
          509, // Bandwidth Limit Exceeded (Hết băng thông - Apache)
          529, // Site is overloaded (Qualys)
          598, // Network read timeout error (Informal)
          599, // Network connect timeout error (Informal)
        },
      ),
    );

    // SSL Verify Bypass (Required for TLU Servers)
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
            // Only bypass SSL for authorized TLU domains to prevent MITM on others
            return host.endsWith('tlu.edu.vn');
          };
      return client;
    };
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw const NetworkFailure('Unexpected error occurred');
    }
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw const NetworkFailure('Unexpected error occurred');
    }
  }

  Failure _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const NetworkFailure('Connection timed out');
    }

    if (error.type == DioExceptionType.connectionError) {
      return const NetworkFailure('No internet connection');
    }

    if (error.response != null) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null && statusCode >= 500) {
        return ServerFailure(
          'Lỗi máy chủ trường (Code: $statusCode). Hệ thống trường đang gặp sự cố, vui lòng thử lại sau.',
        );
      }
      return ServerFailure(
        'Server error: ${error.response?.statusCode}, Body: ${error.response?.data}',
      );
    }

    return NetworkFailure(error.message ?? 'Unknown network error');
  }
}
