import 'package:flutter/material.dart';
import 'auth.dart';
import 'widgets/qr_scanner_modal.dart';
import 'playback_page.dart';
import 'spotify_utils.dart';
import 'widgets/game_rules_sheet.dart';
import 'widgets/device_selector.dart';
import 'device_service.dart';

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
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFA259FF), brightness: Brightness.dark).copyWith(
          primary: const Color(0xFFA259FF),
          secondary: const Color(0xFF00FFE0),
          tertiary: const Color(0xFF00FFE0),
          surface: const Color(0xFF0E1220),
          background: const Color(0xFF0B0F1A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0F1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            backgroundColor: const WidgetStatePropertyAll(Color(0xFFA259FF)),
            foregroundColor: const WidgetStatePropertyAll(Colors.white),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
            side: const WidgetStatePropertyAll(BorderSide(color: Color(0xFF00FFE0), width: 1.5)),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            foregroundColor: const WidgetStatePropertyAll(Color(0xFF00FFE0)),
            backgroundColor: const WidgetStatePropertyAll(Color(0x59000000)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.03),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFA259FF), width: 2)),
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white54),
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withOpacity(0.04),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          margin: const EdgeInsets.all(12),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1A1F2E),
          contentTextStyle: const TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white.withOpacity(0.06),
          labelStyle: const TextStyle(color: Colors.white),
          selectedColor: const Color(0xFFA259FF).withOpacity(0.4),
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF00FFE0),
        ),
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
      if (!mounted) {
        setState(() {
          _isAuthenticating = false;
        });
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authenticatie mislukt. Probeer het opnieuw.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: BrandGradient(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Thomster',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Scan een Spotify-nummer en speel direct af',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ],
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
                        Text('Verbinden...'),
                      ],
                    )
                  : const Text('Verbind met Spotify'),
            ),
          ),
        ),
      ),
    );
  }
}

class ConnectSpotifyScreen extends StatefulWidget {
  final AuthService auth;
  const ConnectSpotifyScreen({super.key, required this.auth});

  @override
  State<ConnectSpotifyScreen> createState() => _ConnectSpotifyScreenState();
}

class _ConnectSpotifyScreenState extends State<ConnectSpotifyScreen> {
  SpotifyDevice? _selectedDevice;

  void _onDeviceSelected(SpotifyDevice? device) {
    setState(() {
      _selectedDevice = device;
    });
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Uitloggen',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await widget.auth.logout();
              // AuthGate will rebuild to WelcomeScreen after logout.
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: BrandGradient(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Scan en speel!',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 24),
                  DeviceSelector(
                    auth: widget.auth,
                    selectedDevice: _selectedDevice,
                    onDeviceSelected: _onDeviceSelected,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ScanQrBigButton(
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
                                  return QrValidation.error('Kon de Spotify-link niet openen. Probeer het opnieuw.');
                                } else {
                                  toProcess = resolved.toString();
                                }
                              }
                            }

                            final trackId = SpotifyUtils.extractSpotifyTrackId(toProcess);
                            if (trackId == null) {
                              if (uri != null && SpotifyUtils.isSpotifyHost(uri.host)) {
                                return QrValidation.error('Deze Spotify-link is geen nummer. Scan een nummerlink.');
                              } else {
                                return QrValidation.error('Geen Spotify-track QR. Scan een Spotify-tracklink.');
                              }
                            }

                            // IMPORTANT: return the trackId, not the URL
                            return QrValidation.valid(trackId);
                          },
                        );
                        if (scanned == null || scanned.isEmpty) return;

                        // 'scanned' is the trackId now (provided by validator)
                        final trackId = scanned;
                        if (context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlaybackPage(
                                auth: widget.auth,
                                trackId: trackId,
                                originalUrl: null,
                                selectedDevice: _selectedDevice,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const GameRulesSheet(),
                        );
                      },
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('Spelregels'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ---- Shared branded UI helpers ----
class BrandGradient extends StatelessWidget {
  final Widget child;
  const BrandGradient({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFA259FF), // Electric Purple
            Color(0xFF00FFE0), // Neon Cyan
          ],
        ),
      ),
      child: child,
    );
  }
}

class ScanQrBigButton extends StatelessWidget {
  final VoidCallback onPressed;
  const ScanQrBigButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(18);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 280),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFFB97AFF), // Light Purple
              Color(0xFFA259FF), // Electric Purple
            ],
          ),
          borderRadius: borderRadius,
          border: Border.all(color: const Color(0xFFA259FF), width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x803A1B6E), blurRadius: 16, offset: Offset(0, 8)), // purple glow
            BoxShadow(color: Color(0x33A259FF), blurRadius: 20, offset: Offset(0, 6)), // subtle purple rim
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onPressed,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Scan QR-code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

