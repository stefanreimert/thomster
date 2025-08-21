import 'package:flutter/material.dart';
import 'auth.dart';
import 'widgets/qr_scanner_modal.dart';
import 'playback_page.dart';
import 'spotify_utils.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = await AuthService.create();
  runApp(ThomsterApp(auth: auth));
}

class ThomsterApp extends StatelessWidget {
  final AuthService auth;
  const ThomsterApp({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thomster',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: AuthGate(auth: auth),
    );
  }
}

class AuthGate extends StatelessWidget {
  final AuthService auth;
  const AuthGate({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        if (auth.isAuthenticated) {
          return ConnectSpotifyScreen(auth: auth);
        }
        return WelcomeScreen(auth: auth);
      },
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  final AuthService auth;
  const WelcomeScreen({super.key, required this.auth});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isAuthenticating = false;

  Future<void> _startAuth() async {
    setState(() {
      _isAuthenticating = true;
    });

    try {
      await widget.auth.login();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication failed. Please try again.')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const SafeArea(
        child: Center(
          child: Text(
            'Thomster',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isAuthenticating ? null : _startAuth,
              child: _isAuthenticating
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Connecting...'),
                      ],
                    )
                  : const Text('Connect to spotify'),
            ),
          ),
        ),
      ),
    );
  }
}

class ConnectSpotifyScreen extends StatelessWidget {
  final AuthService auth;
  const ConnectSpotifyScreen({super.key, required this.auth});

  // Extracts a Spotify track ID from various QR contents.
  static String? extractSpotifyTrackId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Handle spotify:track:{id}
    if (trimmed.startsWith('spotify:')) {
      final parts = trimmed.split(':');
      if (parts.length >= 3 && parts[1] == 'track') {
        final id = parts[2];
        final valid = RegExp(r'^[A-Za-z0-9]{22}$');
        return valid.hasMatch(id) ? id : null;
      }
    }

    // Handle https://open.spotify.com/... variants (also handle missing scheme)
    Uri? uri = _parseWithHttpsFallback(trimmed);
    if (uri != null && (uri.host == 'open.spotify.com' || uri.host.endsWith('.spotify.com'))) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      // Find the index of 'track' in the path, allowing locale prefixes like /intl-nl/
      final idx = segments.indexOf('track');
      if (idx != -1 && idx + 1 < segments.length) {
        final id = segments[idx + 1];
        final valid = RegExp(r'^[A-Za-z0-9]{22}$');
        return valid.hasMatch(id) ? id : null;
      }
    }

    return null;
  }

  // Parse a string into a Uri, adding https:// if missing.
  static Uri? _parseWithHttpsFallback(String input) {
    try {
      final uri = Uri.parse(input);
      if (uri.hasScheme && uri.host.isNotEmpty) return uri;
    } catch (_) {}
    try {
      final uri = Uri.parse('https://$input');
      if (uri.host.isNotEmpty) return uri;
    } catch (_) {}
    return null;
  }

  static bool _isSpotifyHost(String host) {
    return host == 'open.spotify.com' || host.endsWith('.spotify.com') || host == 'spotify.link' || host.endsWith('.spotify.link') || host == 'spoti.fi';
  }

  static bool _isShortSpotifyHost(String host) {
    return host == 'spotify.link' || host.endsWith('.spotify.link') || host == 'spoti.fi';
  }

  static Future<Uri?> _resolveFinalUrl(Uri uri) async {
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      return resp.request?.url ?? uri;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              // AuthGate will rebuild to WelcomeScreen after logout.
            },
          ),
        ],
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
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

                // Valid -> return the (possibly resolved) URL so we can continue.
                return QrValidation.valid(toProcess);
              },
            );
            if (scanned == null || scanned.isEmpty) return;

            // Already validated in scanner; extract trackId and navigate immediately.
            final quickTrackId = SpotifyUtils.extractSpotifyTrackId(scanned);
            if (quickTrackId != null) {
              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlaybackPage(
                      auth: auth,
                      trackId: quickTrackId,
                      originalUrl: scanned,
                    ),
                  ),
                );
              }
              return;
            }

            if (context.mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Dialog(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Processing...'),
                      ],
                    ),
                  ),
                ),
              );
            }

            String toProcess = scanned;
            String? errorMessage;

            try {
              final uri = _parseWithHttpsFallback(scanned);
              if (uri != null && _isSpotifyHost(uri.host)) {
                if (_isShortSpotifyHost(uri.host)) {
                  final resolved = await _resolveFinalUrl(uri);
                  if (resolved == null) {
                    errorMessage = "Couldn't resolve the Spotify link. Please try again.";
                  } else {
                    toProcess = resolved.toString();
                  }
                }
              }

              final trackId = extractSpotifyTrackId(toProcess);
              if (trackId == null) {
                if (uri != null && _isSpotifyHost(uri.host)) {
                  errorMessage ??= 'This Spotify link is not a track. Please scan a track link.';
                } else {
                  errorMessage ??= 'Not a Spotify track QR. Please scan a Spotify track link.';
                }
              } else {
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlaybackPage(
                        auth: auth,
                        trackId: trackId,
                        originalUrl: scanned,
                      ),
                    ),
                  );
                  return;
                }
              }
            } catch (_) {
              errorMessage = 'Failed to process QR. Please try again.';
            }

            if (context.mounted) {
              Navigator.of(context, rootNavigator: true).pop();
              if (errorMessage != null) {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Invalid QR-code'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(errorMessage!),
                          const SizedBox(height: 12),
                          const Text('Scanned content:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: SelectableText(
                              scanned,
                              maxLines: 6,
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            }
          },
          child: const Text('Scan QR-code'),
        ),
      ),
    );
  }
}
