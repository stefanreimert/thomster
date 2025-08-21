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

    final ok = await _withAuthRetry((token) async {
      final uri = Uri.https('api.spotify.com', '/v1/me/player/play');
      final body = jsonEncode({
        'uris': ['spotify:track:${widget.trackId}'],
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

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isPlaying = ok ? true : _isPlaying;
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

  Future<void> _openInSpotify() async {
    final url = widget.originalUrl ?? 'https://open.spotify.com/track/${widget.trackId}';
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
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
            OutlinedButton.icon(
              onPressed: _openInSpotify,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in Spotify'),
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
