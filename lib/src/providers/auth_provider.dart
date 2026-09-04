import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../models/auth_response.dart';
import '../models/me_response.dart';

class AuthProvider extends ChangeNotifier {
  static const String _tokenKey = 'ezim_sanctum_token';

  final _secureStorage = const FlutterSecureStorage();
  final _apiService = ApiService();

  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _token;
  AuthUser? _user;
  MeResponse? _meResponse;
  String? _error;
  int _unreadCount = 0;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get token => _token;
  AuthUser? get user => _user;
  MeResponse? get meResponse => _meResponse;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      _token = await _secureStorage.read(key: _tokenKey);
      if (_token != null) {
        try {
          final response = await _apiService.getMe(token: _token!);
          _meResponse = response;
          _user = response.user;
          _isAuthenticated = true;
          await refreshUnreadCount();
        } catch (e) {
          final msg = e.toString();
          if (msg.contains('401') || msg.contains('Token expired') || msg.contains('Unauthenticated')) {
            await _clearSession();
          } else {
            _isAuthenticated = true;
          }
        }
      }
    } catch (e) {
      await _clearSession();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.login(email: email, password: password);
      _token = response.token;

      try {
        final meResponse = await _apiService.getMe(token: _token!);
        _meResponse = meResponse;
        _user = meResponse.user;
      } catch (e) {
        if (e.toString().contains('401') || e.toString().contains('Token expired')) {
          _error = 'Session expired. Please login again.';
          _isAuthenticated = false;
          return false;
        }
      }

      await _secureStorage.write(key: _tokenKey, value: _token!);
      _isAuthenticated = true;
      await refreshUnreadCount();
      return true;
    } catch (e) {
      _error = e.toString();
      _isAuthenticated = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      if (_token != null) {
        await _apiService.logout(token: _token!);
      }
    } catch (_) {}
    await _clearSession();
    notifyListeners();
  }

  Future<void> refreshUserData() async {
    if (_token == null) return;
    try {
      final meResponse = await _apiService.getMe(token: _token!);
      _meResponse = meResponse;
      _user = meResponse.user;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshUnreadCount() async {
    if (_token == null) return;
    final count = await _apiService.getUnreadCount(token: _token!);
    _unreadCount = count;
    notifyListeners();
  }

  /// Called by WebView JS channel when a notification is marked read in-page
  Future<void> decrementUnreadCount() async {
    if (_unreadCount > 0) {
      _unreadCount--;
      notifyListeners();
    }
  }

  /// Force logout on 401 from WebView
  Future<void> handleUnauthorized() async {
    await _clearSession();
    notifyListeners();
  }

  Future<void> _clearSession() async {
    _token = null;
    _user = null;
    _meResponse = null;
    _isAuthenticated = false;
    _unreadCount = 0;
    await _secureStorage.delete(key: _tokenKey);
  }

  String getDashboardPath() {
    final role = _user?.role ?? 'partner';
    return switch (role) {
      'super_admin' || 'admin' => '/dashboard',
      'general_manager' => '/general-manager/dashboard',
      'accountant' => '/accountant/dashboard',
      'finance' => '/finance/dashboard',
      'cashier' => '/cashier/dashboard',
      'internal_team' => '/internal-team/dashboard',
      'clearance_team' => '/clearance-team/dashboard',
      'storekeeper' => '/storekeeper/dashboard',
      'seller' => '/seller/dashboard',
      'partner' => '/partner/dashboard',
      _ => '/dashboard',
    };
  }
}
