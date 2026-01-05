import 'dart:convert';
import 'dart:typed_data';
import 'package:brotli/brotli.dart';
import 'package:dio/dio.dart';

/// A Dio Transformer that supports Brotli ('br') decompression.
class DioBrotliTransformer extends BackgroundTransformer {
  @override
  Future<dynamic> transformResponse(
    RequestOptions options,
    ResponseBody responseBody,
  ) async {
    // Check Content-Encoding header
    final contentEncoding =
        responseBody.headers['content-encoding']?.firstOrNull?.toLowerCase() ??
        '';

    // If 'br' (Brotli), we handle decompression manually
    if (contentEncoding == 'br') {
      final stream = responseBody.stream;
      final BytesBuilder bytesBuilder = BytesBuilder(copy: false);

      await for (final chunk in stream) {
        bytesBuilder.add(chunk);
      }

      final compressedBytes = bytesBuilder.takeBytes();
      final decodedBytes = brotli.decode(compressedBytes);
      final decodedString = utf8.decode(decodedBytes);

      // Handle ResponseType
      if (options.responseType == ResponseType.json) {
        return jsonDecode(decodedString); // Return Map/List
      } else if (options.responseType == ResponseType.stream) {
        return Stream.value(decodedBytes); // Return Stream (Not common for API)
      } else {
        return decodedString; // ResponseType.plain
      }
    }

    // For other encodings (gzip, deflate, none), fallback to default
    // Dio/HttpClient handles gzip/deflate if autoUncompress is true.
    return super.transformResponse(options, responseBody);
  }
}
