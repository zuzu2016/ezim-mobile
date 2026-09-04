import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/auth_response.dart';
import '../models/me_response.dart';

class ApiService {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'https://ezimone.com/api';
  static String get webviewHost => dotenv.env['WEBVIEW_HOST'] ?? 'https://ezimone.com';
  static const String _userAgent = 'EZIM-Mobile/1.0.0 (Flutter; Dart)';

  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: _publicHeaders(),
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return LoginResponse.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 422) {
      final data = jsonDecode(response.body);
      final errors = data['errors'] ?? {};
      final msg = errors.values.isNotEmpty
          ? errors.values.first.join(', ')
          : 'Invalid credentials';
      throw Exception(msg);
    } else if (response.statusCode == 401) {
      throw Exception('Invalid email or password');
    } else {
      throw Exception('Login failed: ${response.statusCode}');
    }
  }

  Future<void> logout({required String token}) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/logout'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  Future<MeResponse> getMe({required String token}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/me'),
      headers: _headers(token),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final payload = data['data'] ?? data;
      return MeResponse.fromJson(payload);
    } else if (response.statusCode == 401) {
      throw Exception('Token expired');
    } else {
      throw Exception('Failed to fetch user data: ${response.statusCode}');
    }
  }

  /// Request a short-lived wv_token for WebView authentication.
  /// Returns the full URL with ?wv_token= appended.
  Future<String> getWebViewUrl({
    required String token,
    required String path,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/webview-token'),
      headers: _headers(token),
      body: jsonEncode({'path': path}),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final wvToken = data['token'] as String;
      final host = webviewHost;
      return '$host$path?wv_token=$wvToken';
    } else if (response.statusCode == 401) {
      throw Exception('Token expired');
    } else {
      throw Exception('Failed to get WebView URL: ${response.statusCode}');
    }
  }

  Future<int> getUnreadCount({required String token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/unread-count'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['data']['count'] ?? 0) as int;
      } else if (response.statusCode == 401) {
        throw Exception('Token expired');
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markNotificationRead({
    required String token,
    required int notificationId,
  }) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  Future<void> saveFcmToken({
    required String token,
    required String fcmToken,
    required String platform,
  }) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/fcm-token'),
        headers: _headers(token),
        body: jsonEncode({'token': fcmToken, 'platform': platform}),
      ).timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  Map<String, String> _headers(String token) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'User-Agent': _userAgent,
      };

  Map<String, String> _publicHeaders() => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': _userAgent,
      };
}
