import 'package:http/http.dart' as http;

class SpotifyUtils {
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
    Uri? uri = parseWithHttpsFallback(trimmed);
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
  static Uri? parseWithHttpsFallback(String input) {
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

  static bool isSpotifyHost(String host) {
    return host == 'open.spotify.com' || host.endsWith('.spotify.com') || host == 'spotify.link' || host.endsWith('.spotify.link') || host == 'spoti.fi';
  }

  static bool isShortSpotifyHost(String host) {
    return host == 'spotify.link' || host.endsWith('.spotify.link') || host == 'spoti.fi';
  }

  static Future<Uri?> resolveFinalUrl(Uri uri) async {
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      return resp.request?.url ?? uri;
    } catch (_) {
      return null;
    }
  }
}
