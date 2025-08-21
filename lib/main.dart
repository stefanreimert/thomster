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

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ConnectSpotifyScreen(),
                  ),
                );
              },
              child: const Text('Connect to spotify'),
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
