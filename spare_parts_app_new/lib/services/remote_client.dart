import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'package:flutter/foundation.dart';
import 'auth_exceptions.dart';

class RemoteClient {
  final String baseUrl = Constants.baseUrl;
  static const int _maxRetries = 4;
  static const Duration _timeout = Duration(seconds: 60);
  static const Duration _retryDelay = Duration(seconds: 2);

  static VoidCallback? onUnauthorized;

  Future<Map<String, String>> _getHeaders(Map<String, String>? extra) async {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
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

  Future<dynamic> _requestWithRetry(
    Future<http.Response> Function() requestFn, {
    bool isList = false,
    String? path,
  }) async {
    int attempts = 0;
    while (attempts < _maxRetries) {
      try {
        if (kDebugMode && path != null) {
          debugPrint('RemoteClient: Requesting $baseUrl$path');
        }
        final res = await requestFn().timeout(_timeout);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          if (res.body.isEmpty) return isList ? [] : null;
          return jsonDecode(res.body);
        }

        // Handle Token Expiration (401 Unauthorized)
        if (res.statusCode == 401) {
          onUnauthorized?.call();
          throw TokenExpiredException();
        }

        // If it's a 503, 502, or 429 (Rate Limit), it might be Railway waking up or rate limiting
        if (res.statusCode == 502 ||
            res.statusCode == 503 ||
            res.statusCode == 429) {
          attempts++;
          if (attempts < _maxRetries) {
            final delay = _retryDelay * attempts;
            debugPrint(
                'RemoteClient: HTTP ${res.statusCode} (attempt $attempts). Retrying in ${delay.inSeconds}s...');
            await Future.delayed(delay);
            continue;
          }
        }
        throw 'HTTP ${res.statusCode}: ${res.body}';
      } on SocketException catch (e) {
        attempts++;
        debugPrint('RemoteClient: SocketException (attempt $attempts): $e');
        if (attempts >= _maxRetries) rethrow;
        await Future.delayed(_retryDelay * attempts);
      } on TimeoutException catch (e) {
        attempts++;
        debugPrint('RemoteClient: TimeoutException (attempt $attempts): $e');
        if (attempts >= _maxRetries) rethrow;
        await Future.delayed(_retryDelay * attempts);
      } catch (e) {
        debugPrint('RemoteClient: Error: $e');
        rethrow;
      }
    }
  }

  Future<dynamic> postJson(
    String path,
    dynamic body, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
  }) async {
    final authHeaders = await _getHeaders(headers);
    final uri =
        Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
    return _requestWithRetry(
      () => http.post(
        uri,
        headers: authHeaders,
        body: body != null ? jsonEncode(body) : null,
      ),
      path: path,
    );
  }

  Future<dynamic> postMultipart(
    String path, {
    Map<String, String>? fields,
    Map<String, String>? headers,
    required String fileField,
    required String fileName,
    required List<int> bytes,
    String? contentType,
  }) async {
    final authHeaders = await _getHeaders(headers);
    authHeaders.remove('Content-Type');
    final uri = Uri.parse('$baseUrl$path');
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(authHeaders);
    if (fields != null) {
      req.fields.addAll(fields);
    }

    http.MediaType? mediaType;
    if (contentType != null) {
      final parts = contentType.split('/');
      if (parts.length == 2) {
        mediaType = http.MediaType(parts[0], parts[1]);
      }
    }

    req.files.add(http.MultipartFile.fromBytes(fileField, bytes,
        filename: fileName, contentType: mediaType));

    // For multipart, we can't easily use _requestWithRetry because of the stream
    // but we can add a timeout to the send() call.
    final streamed = await req.send().timeout(_timeout);
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
    return _requestWithRetry(
      () => http.get(
        Uri.parse('$baseUrl$path'),
        headers: authHeaders,
      ),
      path: path,
    );
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String>? headers,
  }) async {
    final authHeaders = await _getHeaders(headers);
    final res = await _requestWithRetry(
      () => http.get(
        Uri.parse('$baseUrl$path'),
        headers: authHeaders,
      ),
      isList: true,
      path: path,
    );
    return res as List<dynamic>;
  }

  Future<dynamic> putJson(
    String path,
    dynamic body, {
    Map<String, String>? headers,
  }) async {
    final authHeaders = await _getHeaders(headers);
    return _requestWithRetry(
      () => http.put(
        Uri.parse('$baseUrl$path'),
        headers: authHeaders,
        body: jsonEncode(body),
      ),
      path: path,
    );
  }

  Future<void> delete(String path, {Map<String, String>? headers}) async {
    final authHeaders = await _getHeaders(headers);
    await _requestWithRetry(
      () => http.delete(
        Uri.parse('$baseUrl$path'),
        headers: authHeaders,
      ),
      path: path,
    );
  }
}
