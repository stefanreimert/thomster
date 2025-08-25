import 'package:flutter/material.dart';

// ---- Game Rules Bottom Sheet ----
class GameRulesSheet extends StatelessWidget {
  const GameRulesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -8)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFA259FF), Color(0xFF00FFE0)],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFA259FF), Color(0xFF00FFE0)],
                        ),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Game rules',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    children: const [
                      _RuleItem(
                        icon: Icons.qr_code_2_rounded,
                        title: 'Scan to play',
                        subtitle: 'Use the Scan QR-code button to scan any Spotify track code and start playback instantly.',
                      ),
                      _RuleItem(
                        icon: Icons.library_music_rounded,
                        title: 'Tracks only',
                        subtitle: 'Please scan Spotify track links. Playlists, albums or artists won’t work in this mode.',
                      ),
                      _RuleItem(
                        icon: Icons.smartphone_rounded,
                        title: 'Have Spotify ready',
                        subtitle: 'Ensure your phone is an active Spotify device. We try to auto-transfer playback if needed.',
                      ),
                      _RuleItem(
                        icon: Icons.schedule_rounded,
                        title: 'Take turns',
                        subtitle: 'Be fair—let everyone scan their picks. Keep the vibe going.',
                      ),
                      _RuleItem(
                        icon: Icons.volume_up_rounded,
                        title: 'Mind the volume',
                        subtitle: 'Adjust volume responsibly for the room and people around you.',
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(cs.primary),
                    foregroundColor: const WidgetStatePropertyAll(Colors.white),
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _RuleItem({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFFA259FF), Color(0xFF00FFE0)]),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
