import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'app_remote.dart';
import 'widgets/qr_scanner_modal.dart';
import 'spotify_utils.dart';

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

class _PlaybackPageState extends State<PlaybackPage> with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _lastError;
  late final AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 6));
    // Start in stopped state; will be synced when playback state changes.
    _syncBgAnimation();
    _autoStart();
  }

  void _syncBgAnimation() {
    if (_isPlaying) {
      if (!_bgController.isAnimating) {
        _bgController.repeat();
      }
    } else {
      if (_bgController.isAnimating) {
        _bgController.stop();
      }
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
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
      _syncBgAnimation();
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
      _syncBgAnimation();
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
      // Resume current playback (no body). If this fails (e.g., no active context),
      // we fall back to _play() below to start the scanned track.
      return _put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
    });

    if (ok) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = true;
        });
        _syncBgAnimation();
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

  Future<void> _scanAgain() async {
    if (_isLoading) return;
    final scanned = await QrScannerModal.open(
      context,
      validator: (raw) async {
        String toProcess = raw;
        final uri = SpotifyUtils.parseWithHttpsFallback(raw);
        if (uri != null && SpotifyUtils.isSpotifyHost(uri.host)) {
          if (SpotifyUtils.isShortSpotifyHost(uri.host)) {
            final resolved = await SpotifyUtils.resolveFinalUrl(uri);
            if (resolved == null) {
              return QrValidation.error("Couldn't resolve the Spotify link. Please try again.");
            } else {
              toProcess = resolved.toString();
            }
          }
        }

        final trackId = SpotifyUtils.extractSpotifyTrackId(toProcess);
        if (trackId == null) {
          if (uri != null && SpotifyUtils.isSpotifyHost(uri.host)) {
            return QrValidation.error('This Spotify link is not a track. Please scan a track link.');
          } else {
            return QrValidation.error('Not a Spotify track QR. Please scan a Spotify track link.');
          }
        }

        return QrValidation.valid(trackId);
      },
    );

    if (scanned == null || scanned.isEmpty) return;
    if (!mounted) return;

    // Navigate to a new PlaybackPage with the newly scanned trackId.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PlaybackPage(
          auth: widget.auth,
          trackId: scanned,
          originalUrl: null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Playback';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Vibrant animated gradient backdrop
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              final angle = _bgController.value * 2 * math.pi;
              return Container(
                decoration: BoxDecoration(
                  gradient: SweepGradient(
                    center: Alignment.center,
                    startAngle: 0.0,
                    endAngle: 2 * math.pi,
                    transform: GradientRotation(angle),
                    colors: [
                      const Color(0xFF00E5FF), // Cyan
                      const Color(0xFF7C4DFF), // Purple
                      const Color(0xFFFF4081), // Pink
                      const Color(0xFFFFEA00), // Yellow
                      const Color(0xFF00E5FF), // Cyan (loop)
                    ],
                    stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                  ),
                ),
              );
            },
          ),
          // Moving radial highlight overlay for extra motion
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              final t = _bgController.value * 2 * math.pi;
              final align = Alignment(math.cos(t) * 0.6, math.sin(t) * 0.6);
              return IgnorePointer(
                ignoring: true,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: align,
                      radius: 0.6,
                      colors: [
                        Colors.white.withOpacity(0.12),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                      color: Colors.white.withOpacity(0.04),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          blurRadius: 24,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Header + track info
                              Text(
                                'Now Playing',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Track ID',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                widget.trackId,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      letterSpacing: 0.5,
                                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                                    ),
                              ),
                              if (widget.originalUrl != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  widget.originalUrl!,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              const SizedBox(height: 24),

                              // Big Play/Pause button with glow + pulse
                              AnimatedBuilder(
                                animation: _bgController,
                                builder: (context, child) {
                                  final phase = _bgController.value * 2 * math.pi * 2; // faster pulse
                                  final wave = math.sin(phase);
                                  final scale = _isPlaying ? (1.0 + 0.04 * wave) : 1.0;
                                  final intensity = _isPlaying ? (0.5 + 0.5 * (wave * 0.5 + 0.5)) : 0.45;
                                  final blur = 30.0 + (_isPlaying ? 12.0 * (wave * 0.5 + 0.5) : 0.0);
                                  final spread = 2.0 + (_isPlaying ? 2.0 * (wave * 0.5 + 0.5) : 0.0);
                                  return Transform.scale(
                                    scale: scale,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(intensity),
                                            blurRadius: blur,
                                            spreadRadius: spread,
                                          ),
                                        ],
                                      ),
                                      child: FilledButton(
                                        onPressed: _isLoading ? null : (_isPlaying ? _pause : _resume),
                                        style: const ButtonStyle(
                                          shape: WidgetStatePropertyAll(CircleBorder()),
                                          padding: WidgetStatePropertyAll(EdgeInsets.all(28)),
                                        ),
                                        child: SizedBox(
                                          width: 72,
                                          height: 72,
                                          child: Center(
                                            child: _isLoading
                                                ? const SizedBox(
                                                    width: 28,
                                                    height: 28,
                                                    child: CircularProgressIndicator(strokeWidth: 3),
                                                  )
                                                : Icon(
                                                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                    size: 48,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _isPlaying ? 'Pause' : 'Resume',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),

                              if (_isPlaying)
                                AnimatedBuilder(
                                  animation: _bgController,
                                  builder: (context, child) {
                                    final v = _bgController.value;
                                    final heights = List<double>.generate(5, (i) {
                                      final phase = v * 2 * math.pi * 2 + i * 1.2;
                                      final s = (math.sin(phase) + 1) / 2;
                                      return ui.lerpDouble(6, 28, s)!;
                                    });
                                    final cols = const [
                                      Color(0xFF00E5FF),
                                      Color(0xFF7C4DFF),
                                      Color(0xFFFF4081),
                                      Color(0xFFFFEA00),
                                      Color(0xFF00E5FF),
                                    ];
                                    return SizedBox(
                                      height: 32,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          for (int i = 0; i < heights.length; i++)
                                            Container(
                                              width: 6,
                                              height: heights[i],
                                              margin: const EdgeInsets.symmetric(horizontal: 3),
                                              decoration: BoxDecoration(
                                                color: cols[i].withOpacity(0.9),
                                                borderRadius: BorderRadius.circular(3),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: cols[i].withOpacity(0.35),
                                                    blurRadius: 10,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              const SizedBox(height: 20),
                              // Scan again secondary action
                              OutlinedButton.icon(
                                onPressed: _isLoading ? null : _scanAgain,
                                icon: const Icon(Icons.qr_code_scanner),
                                label: const Text('Scan again'),
                              ),

                              const SizedBox(height: 16),
                              if (_lastError != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(12),
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

                              const SizedBox(height: 8),
                              Text(
                                _isPlaying ? 'Status: Playing' : 'Status: Paused/Idle',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
