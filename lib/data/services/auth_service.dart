import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _usernameKey = 'auth_username';
  final SharedPreferences _prefs;

  AuthService(this._prefs);

  Future<void> saveToken(String token) async {
    await _prefs.setString(_tokenKey, token);
  }

  Future<void> saveUsername(String username) async {
    await _prefs.setString(_usernameKey, username);
  }

  String? getToken() {
    return _prefs.getString(_tokenKey);
  }

  String? getUsername() {
    return _prefs.getString(_usernameKey);
  }

  Future<void> clearToken() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_usernameKey);
  }

  bool isTokenValid() {
    final token = getToken();
    if (token == null) return false;

    try {
      final decodedToken = JwtDecoder.decode(token);
      final expiration = DateTime.fromMillisecondsSinceEpoch(decodedToken['exp'] * 1000);
      return DateTime.now().isBefore(expiration);
    } catch (e) {
      debugPrint('Error decoding token: $e');
      return false;
    }
  }

  Map<String, dynamic>? getDecodedToken() {
    final token = getToken();
    if (token == null) return null;

    try {
      return JwtDecoder.decode(token);
    } catch (e) {
      debugPrint('Error decoding token: $e');
      return null;
    }
  }

  String? get username => getDecodedToken()?['username'];
  String? get employeeId => getDecodedToken()?['employeeId'];
  int? get role => getDecodedToken()?['role'];
}
