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
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
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
        retries: 10,
        retryDelays: const [
          Duration(seconds: 1),
          Duration(seconds: 2),
          Duration(seconds: 3),
          Duration(seconds: 5),
          Duration(seconds: 8),
          Duration(seconds: 10),
          Duration(seconds: 10),
          Duration(seconds: 10),
          Duration(seconds: 10),
          Duration(seconds: 10),
        ],
        retryableExtraStatuses: {408, 500, 502, 503, 504},
      ),
    );

    // SSL Verify Bypass (Required for TLU Servers)
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.idleTimeout = const Duration(seconds: 60); // Keep connection alive
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
