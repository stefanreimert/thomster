import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'app_remote.dart';

class PlaybackPage extends StatefulWidget {
  final AuthService auth;
  final String trackId;
  final String? originalUrl;

  const PlaybackPage({
    super.key,
    required this.auth,
    required this.trackId,
    this.originalUrl,
  });

  @override
  State<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends State<PlaybackPage> {
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _autoStart();
  }


  Future<void> _activateViaAppRemote() async {
    if (kIsWeb) return;
    final p = defaultTargetPlatform;
    if (!(p == TargetPlatform.android || p == TargetPlatform.iOS)) return;
    try {
      final activator = AppRemoteActivator();
      await activator.activateSilently(
        clientId: widget.auth.clientId,
        redirectUri: widget.auth.redirectUri,
      );
    } catch (_) {}
  }

  Future<void> _autoStart() async {
    // Start playing the scanned song right away without pre-activating App Remote
    // to avoid any chance of the previously paused track resuming.
    if (!mounted) return;
    Future.microtask(() => _play());
  }

  Future<String?> _ensureAccessToken() async {
    if (widget.auth.isAccessTokenExpired) {
      await widget.auth.refreshAccessToken();
    }
    return widget.auth.accessToken;
  }

  Future<http.Response> _put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return http.put(uri, headers: headers, body: body);
  }

  Future<bool> _withAuthRetry(Future<http.Response> Function(String token) call) async {
    final token1 = await _ensureAccessToken();
    if (token1 == null) {
      setState(() => _lastError = 'Missing access token. Please login again.');
      return false;
    }
    var resp = await call(token1);
    if (resp.statusCode == 401) {
      // Try refresh once.
      await widget.auth.refreshAccessToken();
      final token2 = widget.auth.accessToken;
      if (token2 == null) return false;
      resp = await call(token2);
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return true;
    }

    // Parse common errors
    String msg = 'Request failed (${resp.statusCode})';
    try {
      if (resp.body.isNotEmpty) {
        final map = jsonDecode(resp.body) as Map<String, dynamic>;
        final err = map['error'];
        if (err is Map<String, dynamic>) {
          final m = err['message'];
          if (m is String && m.isNotEmpty) msg = m;
        }
      }
    } catch (_) {}

    setState(() => _lastError = msg);
    return false;
  }

  Future<void> _play() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _lastError = null;
    });

    String? token = await _ensureAccessToken();
    if (token == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _lastError = 'Missing access token. Please login again.';
        });
      }
      return;
    }

    // Safety: pause any current playback to prevent hearing an old track before we start the scanned one.
    try {
      final pauseUri = Uri.https('api.spotify.com', '/v1/me/player/pause');
      await _put(
        pauseUri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
    } catch (_) {}

    Future<http.Response> attemptPlay(String tkn, {String? deviceId}) {
      final uri = Uri.https(
        'api.spotify.com',
        '/v1/me/player/play',
        deviceId != null ? {'device_id': deviceId} : null,
      );
      final body = jsonEncode({
        'uris': ['spotify:track:${widget.trackId}'],
      });
      return _put(
        uri,
        headers: {
          'Authorization': 'Bearer $tkn',
          'Content-Type': 'application/json',
        },
        body: body,
      );
    }


    Future<String> parseErr(http.Response resp) async {
      String msg = 'Request failed (${resp.statusCode})';
      try {
        if (resp.body.isNotEmpty) {
          final map = jsonDecode(resp.body) as Map<String, dynamic>;
          final err = map['error'];
          if (err is Map<String, dynamic>) {
            final m = err['message'];
            if (m is String && m.isNotEmpty) msg = m;
          }
        }
      } catch (_) {}
      return msg;
    }

    http.Response resp = await attemptPlay(token);

    // If unauthorized, try refresh once and retry.
    if (resp.statusCode == 401) {
      await widget.auth.refreshAccessToken();
      token = widget.auth.accessToken;
      if (token != null) {
        resp = await attemptPlay(token);
      }
    }

    // If still not successful, try to activate Spotify device and retry.
    if (resp.statusCode == 404 || (resp.statusCode == 403)) {
      // Do not launch external Spotify app; stay in-app. Instead, try to find/activate a device via transfer and retry.
      // Best-effort: on mobile, silently connect via App Remote to register the phone device.
      await _activateViaAppRemote();
      await Future.delayed(const Duration(milliseconds: 200));

      // Poll for an active device for up to ~10 seconds
      final devicesUri = Uri.https('api.spotify.com', '/v1/me/player/devices');
      String? activeDeviceId;
      String? phoneDeviceId;
      for (int i = 0; i < 20; i++) {
        if (!mounted) break;
        await Future.delayed(const Duration(milliseconds: 500));
        final dResp = await http.get(devicesUri, headers: {
          'Authorization': 'Bearer ${token ?? ''}',
        });
        if (dResp.statusCode == 401) {
          await widget.auth.refreshAccessToken();
          token = widget.auth.accessToken;
          if (token == null) continue;
        } else if (dResp.statusCode >= 200 && dResp.statusCode < 300) {
          try {
            final map = jsonDecode(dResp.body) as Map<String, dynamic>;
            final list = (map['devices'] as List?) ?? [];
            activeDeviceId = null;
            phoneDeviceId = null;
            for (final it in list) {
              if (it is Map<String, dynamic>) {
                final id = it['id'] as String?;
                final active = it['is_active'] as bool? ?? false;
                final type = (it['type'] as String?)?.toLowerCase() ?? '';
                final name = (it['name'] as String?) ?? '';
                if (active && id != null) {
                  activeDeviceId = id;
                }
                if (id != null && (type == 'smartphone' || name.toLowerCase().contains('iphone') || name.toLowerCase().contains('android') || name.toLowerCase().contains('this phone'))) {
                  phoneDeviceId = id;
                }
              }
            }
            if (activeDeviceId != null) {
              break;
            }
          } catch (_) {}
        }
      }

      // If an active device is available, try playing directly on it
      if (activeDeviceId != null && token != null) {
        resp = await attemptPlay(token, deviceId: activeDeviceId);
      }

      // If there is no active device but we see a phone device, transfer playback there, wait briefly, then target it explicitly.
      if ((resp.statusCode == 404 || resp.statusCode == 403) && activeDeviceId == null && phoneDeviceId != null && token != null) {
        final transferUri = Uri.https('api.spotify.com', '/v1/me/player');
        final tBody = jsonEncode({
          'device_ids': [phoneDeviceId],
          'play': false,
        });
        await _put(
          transferUri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: tBody,
        );
        // Give Spotify a moment to activate the device
        await Future.delayed(const Duration(milliseconds: 600));
        resp = await attemptPlay(token, deviceId: phoneDeviceId);
      }

      // Final fallback retry without device targeting
      if (token != null && (resp.statusCode == 404 || resp.statusCode == 403)) {
        resp = await attemptPlay(token);
      }
    }

    bool success = resp.statusCode >= 200 && resp.statusCode < 300;

    if (!success) {
      final msg = await parseErr(resp);
      if (mounted) {
        setState(() {
          _lastError = msg;
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isPlaying = success ? true : _isPlaying;
      });
    }
  }

  Future<void> _pause() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _lastError = null;
    });

    final ok = await _withAuthRetry((token) async {
      final uri = Uri.https('api.spotify.com', '/v1/me/player/pause');
      return _put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
    });

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isPlaying = ok ? false : _isPlaying;
      });
    }
  }

  Future<void> _resume() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _lastError = null;
    });

    final ok = await _withAuthRetry((token) async {
      final uri = Uri.https('api.spotify.com', '/v1/me/player/play');
      final body = jsonEncode({
        'uris': ['spotify:track:${widget.trackId}'],
        'position_ms': 0,
      });
      return _put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );
    });

    if (ok) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = true;
        });
      }
      return;
    }

    // Fallback: try full play flow to start the scanned track.
    if (mounted) {
      setState(() {
        _isLoading = false; // allow _play() to run
        _lastError = null;  // clear transient error before fallback
      });
    }
    await _play();
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Playback';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Track ID: ${widget.trackId}', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            if (widget.originalUrl != null)
              Text(
                widget.originalUrl!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isLoading ? null : (_isPlaying ? _pause : _resume),
              icon: _isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              label: Text(_isPlaying ? 'Pause' : 'Resume'),
            ),
            const SizedBox(height: 12),
            if (_lastError != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            Text(
              _isPlaying ? 'Status: Playing' : 'Status: Paused/Idle',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
