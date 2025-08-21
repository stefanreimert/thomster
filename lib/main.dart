import 'package:flutter/material.dart';

void main() {
  runApp(const ThomsterApp());
}

class ThomsterApp extends StatelessWidget {
  const ThomsterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thomster',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

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
      // TODO: Replace with real Spotify auth flow later.
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      // Navigate to the next page only after auth completes successfully.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ConnectSpotifyScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication failed. Please try again.')),
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
  const ConnectSpotifyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // To be implemented later
          },
          child: const Text('Scan QR-code'),
        ),
      ),
    );
  }
}
