import 'dart:async';

import 'package:spotify_sdk/spotify_sdk.dart';

class AppRemoteActivator {
  Future<void> activateSilently({required String clientId, required String redirectUri}) async {
    try {
      final connected = await SpotifySdk.connectToSpotifyRemote(
        clientId: clientId,
        redirectUrl: redirectUri,
      );
      if (connected) {
        // Try to resume and quickly pause to register device as active without leaving our app.
        try {
          await SpotifySdk.resume();
          // Small delay to ensure the device registers
          await Future.delayed(const Duration(milliseconds: 300));
          await SpotifySdk.pause();
        } catch (_) {
          // Ignore resume/pause failures; device may already be active.
        }
      }
    } catch (_) {
      // Swallow errors to keep UX seamless; activation is best-effort.
    }
  }
}
