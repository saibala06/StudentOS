import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

/// Single point of contact with the FastAPI backend. Handles the auth
/// token, base URL, JSON encoding/decoding, and turning non-2xx responses
/// into a readable ApiException the UI layer can catch and show.
class ApiClient {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'studentos_access_token';

  String get _base => ApiConfig.baseUrl;

  Future<String?> get token => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<Map<String, String>> _headers({bool json = true}) async {
    final t = await token;
    return {
      if (json) 'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    String message = 'Something went wrong (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] != null) {
        message = body['detail'].toString();
      }
    } catch (_) {}
    throw ApiException(res.statusCode, message);
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers());
    return _decode(res);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$_base$path');
    final res = await http.post(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);
    return _decode(res);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$_base$path');
    final res = await http.put(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);
    return _decode(res);
  }

  Future<dynamic> delete(String path) async {
    final uri = Uri.parse('$_base$path');
    final res = await http.delete(uri, headers: await _headers());
    return _decode(res);
  }
}
