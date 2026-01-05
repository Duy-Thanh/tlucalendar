import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:tlucalendar/core/network/dio_brotli_transformer.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:tlucalendar/core/error/failures.dart';

class NetworkClient {
  late final Dio _dio;

  NetworkClient({required String baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 240),
        receiveTimeout: const Duration(seconds: 240),
        validateStatus: (status) => status != null && status < 500,
        headers: {
          'Content-Type': 'application/json', // Default to JSON
          'Accept': 'application/json',
          'Accept-Encoding': 'gzip, deflate, br', // Enable Brotli
        },
      ),
    );

    // Register Custom Transformer for Brotli
    _dio.transformer = DioBrotliTransformer();

    // Aggressive Retry Strategy for High Load
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        logPrint: (message) => debugPrint('[Retry] $message'),
        retries: 5,
        retryDelays: const [
          Duration(seconds: 1),
          Duration(seconds: 3),
          Duration(seconds: 5),
          Duration(seconds: 10),
          Duration(seconds: 20),
        ],
        retryableExtraStatuses: {
          // Standard HTTP Codes
          408, 429, 500, 502, 503, 504,
          // Cloudflare Specific
          520, 521, 522, 523, 524, 525, 527, 530,
        },
      ),
    );

    // SSL Verify Bypass (Keep enabled for Emulator/Low Android Versions)
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      // client.badCertificateCallback =
      //     (X509Certificate cert, String host, int port) => true;
      client.autoUncompress = true; // Handle gzip/deflate automatically
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

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
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
