import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'auth.dart';

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

    Future<http.Response> attemptPlay(String tkn) {
      final uri = Uri.https('api.spotify.com', '/v1/me/player/play');
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
      // Attempt to open Spotify app to the track to activate a device
      try {
        final deep = Uri.parse('spotify:track:${widget.trackId}');
        final ok = await launchUrl(deep, mode: LaunchMode.externalApplication);
        if (!ok) {
          final web = Uri.parse('https://open.spotify.com/track/${widget.trackId}');
          await launchUrl(web, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}

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
                if (id != null && (type == 'smartphone' || name.toLowerCase().contains('iphone') || name.toLowerCase().contains('android'))) {
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

      // If there is no active device but we see a phone device, transfer playback there.
      if (activeDeviceId == null && phoneDeviceId != null && token != null) {
        final transferUri = Uri.https('api.spotify.com', '/v1/me/player');
        final tBody = jsonEncode({
          'device_ids': [phoneDeviceId],
          'play': true,
        });
        await _put(
          transferUri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: tBody,
        );
      }

      // Retry play once more after activation/transfer
      if (token != null) {
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
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _play,
                    icon: _isLoading && _isPlaying == false
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _pause,
                    icon: _isLoading && _isPlaying == true
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                ),
              ],
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
