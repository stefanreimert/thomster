import 'package:flutter/material.dart';
import 'auth.dart';

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
          onPressed: () {
            // To be implemented later
          },
          child: const Text('Scan QR-code'),
        ),
      ),
    );
  }
}
