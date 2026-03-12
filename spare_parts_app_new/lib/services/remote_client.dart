import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class RemoteClient {
  final String baseUrl = Constants.baseUrl;

  Future<Map<String, String>> _getHeaders(Map<String, String>? extra) async {
    final Map<String, String> headers = {'Content-Type': 'application/json'};
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      final user = jsonDecode(userStr);
      if (user['token'] != null) {
        headers['Authorization'] = 'Bearer ${user['token']}';
      }
    }
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  Future<dynamic> postJson(
    String path,
    dynamic body, {
    Map<String, String>? headers,
  }) async {
    final authHeaders = await _getHeaders(headers);
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: authHeaders,
      body: jsonEncode(body),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    throw 'HTTP ${res.statusCode}: ${res.body}';
  }

  Future<dynamic> postMultipart(
    String path, {
    Map<String, String>? fields,
    Map<String, String>? headers,
    required String fileField,
    required String fileName,
    required List<int> bytes,
  }) async {
    final authHeaders = await _getHeaders(headers);
    authHeaders.remove('Content-Type');
    final uri = Uri.parse('$baseUrl$path');
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(authHeaders);
    if (fields != null) {
      req.fields.addAll(fields);
    }
    req.files.add(http.MultipartFile.fromBytes(fileField, bytes, filename: fileName));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    throw 'HTTP ${res.statusCode}: ${res.body}';
  }

  Future<dynamic> getJson(
    String path, {
    Map<String, String>? headers,
  }) async {
    final authHeaders = await _getHeaders(headers);
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: authHeaders,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    throw 'HTTP ${res.statusCode}: ${res.body}';
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String>? headers,
  }) async {
    final authHeaders = await _getHeaders(headers);
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: authHeaders,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return [];
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw 'HTTP ${res.statusCode}: ${res.body}';
  }

  Future<dynamic> putJson(
    String path,
    dynamic body, {
    Map<String, String>? headers,
  }) async {
    final authHeaders = await _getHeaders(headers);
    final res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: authHeaders,
      body: jsonEncode(body),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    throw 'HTTP ${res.statusCode}: ${res.body}';
  }

  Future<void> delete(String path, {Map<String, String>? headers}) async {
    final authHeaders = await _getHeaders(headers);
    final res = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: authHeaders,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }
    throw 'HTTP ${res.statusCode}: ${res.body}';
  }
}
