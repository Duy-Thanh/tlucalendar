import 'dart:convert';

/// Abstract parser interface to allow swapping implementations (e.g., C++ yyjson)
abstract class JsonParser {
  Map<String, dynamic> parse(String jsonString);
  List<dynamic> parseList(String jsonString);
}

/// Default Dart implementation
class DartJsonParser implements JsonParser {
  @override
  Map<String, dynamic> parse(String jsonString) {
    if (jsonString.isEmpty) return {};
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  @override
  List<dynamic> parseList(String jsonString) {
    if (jsonString.isEmpty) return [];
    return jsonDecode(jsonString) as List<dynamic>;
  }
}
