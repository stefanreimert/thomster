import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Spotify OAuth with PKCE + simple persisted auth state.
class AuthService extends ChangeNotifier {
  // Store only what is needed on-device; do NOT store client secret here.
  static const String _clientId = 'c4968369a7f34950be1b20ed66b7e684';
  static const String _redirectUri = 'thomster://auth';
  static const String _callbackScheme = 'thomster';
  static const List<String> _scopes = [
    'user-read-playback-state',
    'user-modify-playback-state',
    'user-read-currently-playing',
  ];

  static const _keyIsAuthenticated = 'auth.isAuthenticated';
  static const _keyAccessToken = 'auth.accessToken';
  static const _keyRefreshToken = 'auth.refreshToken';
  static const _keyTokenExpiry = 'auth.tokenExpiry';

  final SharedPreferences _prefs;
  bool _isAuthenticated;

  AuthService._(this._prefs, this._isAuthenticated);

  static Future<AuthService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final isAuthed = prefs.getBool(_keyIsAuthenticated) ?? false;
    return AuthService._(prefs, isAuthed);
  }

  bool get isAuthenticated => _isAuthenticated;

  String? get accessToken => _prefs.getString(_keyAccessToken);
  String? get refreshToken => _prefs.getString(_keyRefreshToken);
  DateTime? get tokenExpiry {
    final ms = _prefs.getInt(_keyTokenExpiry);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  bool get isAccessTokenExpired {
    final exp = tokenExpiry;
    if (exp == null) return true;
    // Consider token expired if within 30 seconds of expiry.
    return DateTime.now().isAfter(exp.subtract(const Duration(seconds: 30)));
  }

  Future<void> login() async {
    final verifier = _generateCodeVerifier();
    final challenge = _codeChallengeS256(verifier);

    final authUri = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': _clientId,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'scope': _scopes.join(' '),
      // Optionally, state: we could add CSRF protection token if desired.
    });

    // This opens Spotify auth in a browser and listens for the custom-scheme callback.
    final result = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: _callbackScheme,
    );

    // Extract the "code" query parameter from the redirect result.
    final returned = Uri.parse(result);
    final authCode = returned.queryParameters['code'];
    if (authCode == null || authCode.isEmpty) {
      throw Exception('Authorization code missing');
    }

    // Exchange authorization code for access/refresh tokens.
    final tokenResp = await http.post(
      Uri.https('accounts.spotify.com', '/api/token'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'client_id': _clientId,
        'grant_type': 'authorization_code',
        'code': authCode,
        'redirect_uri': _redirectUri,
        'code_verifier': verifier,
      },
    );

    if (tokenResp.statusCode != 200) {
      throw Exception('Token exchange failed: ${tokenResp.statusCode} ${tokenResp.body}');
    }

    final data = jsonDecode(tokenResp.body) as Map<String, dynamic>;
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;

    if (access == null) {
      throw Exception('Missing access token');
    }

    final expiry = DateTime.now().add(Duration(seconds: expiresIn));

    await _prefs.setString(_keyAccessToken, access);
    if (refresh != null) {
      await _prefs.setString(_keyRefreshToken, refresh);
    }
    await _prefs.setInt(_keyTokenExpiry, expiry.millisecondsSinceEpoch);

    _isAuthenticated = true;
    await _prefs.setBool(_keyIsAuthenticated, true);
    notifyListeners();
  }

  Future<void> refreshAccessToken() async {
    final refresh = refreshToken;
    if (refresh == null) return;

    final resp = await http.post(
      Uri.https('accounts.spotify.com', '/api/token'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'client_id': _clientId,
        'grant_type': 'refresh_token',
        'refresh_token': refresh,
      },
    );

    if (resp.statusCode != 200) {
      // If refresh fails, clear auth state.
      await logout(openRevokePage: false);
      return;
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final access = data['access_token'] as String?;
    final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;

    if (access == null) {
      await logout(openRevokePage: false);
      return;
    }

    final expiry = DateTime.now().add(Duration(seconds: expiresIn));
    await _prefs.setString(_keyAccessToken, access);
    await _prefs.setInt(_keyTokenExpiry, expiry.millisecondsSinceEpoch);
    notifyListeners();
  }

  Future<void> logout({bool openRevokePage = true}) async {
    _isAuthenticated = false;
    await _prefs.setBool(_keyIsAuthenticated, false);
    await _prefs.remove(_keyAccessToken);
    await _prefs.remove(_keyRefreshToken);
    await _prefs.remove(_keyTokenExpiry);
    notifyListeners();

    if (openRevokePage) {
      final uri = Uri.parse('https://www.spotify.com/account/apps/');
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Ignore if cannot open; user can revoke manually later.
      }
    }
  }

  // --- Helpers ---
  String _generateCodeVerifier() {
    final rand = Random.secure();
    final bytes = List<int>.generate(64, (_) => rand.nextInt(256));
    return _base64UrlNoPadding(bytes);
  }

  String _codeChallengeS256(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return _base64UrlNoPadding(digest.bytes);
  }

  String _base64UrlNoPadding(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}