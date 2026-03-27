import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth.dart';

class SpotifyDevice {
  final String id;
  final String name;
  final String type;
  final bool isActive;

  const SpotifyDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
  });

  factory SpotifyDevice.fromJson(Map<String, dynamic> json) {
    return SpotifyDevice(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown Device',
      type: json['type'] as String? ?? 'Unknown',
      isActive: json['is_active'] as bool? ?? false,
    );
  }

  @override
  String toString() => '$name ($type)';
}

class DeviceService {
  final AuthService auth;

  DeviceService(this.auth);

  Future<String?> _ensureAccessToken() async {
    if (auth.isAccessTokenExpired) {
      await auth.refreshAccessToken();
    }
    return auth.accessToken;
  }

  Future<List<SpotifyDevice>> getAvailableDevices() async {
    final token = await _ensureAccessToken();
    if (token == null) {
      throw Exception('Access token not available');
    }

    final uri = Uri.https('api.spotify.com', '/v1/me/player/devices');
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 401) {
      // Try refresh once
      await auth.refreshAccessToken();
      final newToken = auth.accessToken;
      if (newToken == null) {
        throw Exception('Unable to refresh access token');
      }

      final retryResponse = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $newToken',
          'Content-Type': 'application/json',
        },
      );

      if (retryResponse.statusCode != 200) {
        throw Exception('Failed to fetch devices: ${retryResponse.statusCode}');
      }

      return _parseDevicesResponse(retryResponse);
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch devices: ${response.statusCode}');
    }

    return _parseDevicesResponse(response);
  }

  List<SpotifyDevice> _parseDevicesResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final devicesList = data['devices'] as List<dynamic>? ?? [];
    
    return devicesList
        .cast<Map<String, dynamic>>()
        .map((deviceJson) => SpotifyDevice.fromJson(deviceJson))
        .toList();
  }
}