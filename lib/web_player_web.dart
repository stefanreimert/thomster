import 'dart:async';
import 'dart:js' as js;
import 'dart:js_util' as jsu;

typedef TokenProvider = Future<String?> Function();

class WebSpotifyPlayer {
  dynamic _player; // JS Player instance
  String? _deviceId;
  late TokenProvider _getToken;

  Future<void> init({required TokenProvider getToken, String name = 'Thomster Web Player'}) async {
    _getToken = getToken;

    // Wait for SDK ready (window.Spotify) or the onSpotifyWebPlaybackSDKReady callback.
    if (!jsu.hasProperty(jsu.globalThis, 'Spotify')) {
      final completer = Completer<void>();
      // Set the global callback that the SDK calls when it's ready.
      jsu.setProperty(jsu.globalThis, 'onSpotifyWebPlaybackSDKReady', js.allowInterop(() {
        if (!completer.isCompleted) completer.complete();
      }));
      // If the script was already loaded between checks, the callback might not fire;
      // so also poll a few times quickly.
      for (int i = 0; i < 50; i++) {
        if (jsu.hasProperty(jsu.globalThis, 'Spotify')) break;
        await Future.delayed(const Duration(milliseconds: 20));
      }
      if (!jsu.hasProperty(jsu.globalThis, 'Spotify')) {
        // Await callback up to 10s in case of slow network.
        await completer.future.timeout(const Duration(seconds: 10), onTimeout: () {});
      }
    }

    if (!jsu.hasProperty(jsu.globalThis, 'Spotify')) {
      throw StateError('Spotify Web Playback SDK not available on this page.');
    }

    final spotify = jsu.getProperty(jsu.globalThis, 'Spotify');
    final playerCtor = jsu.getProperty(spotify, 'Player');

    final options = jsu.newObject();
    jsu.setProperty(options, 'name', name);
    jsu.setProperty(options, 'getOAuthToken', js.allowInterop((cb) async {
      try {
        final token = await _getToken();
        if (token != null) {
          // Call the provided JS callback with the token
          jsu.callMethod(cb, 'call', [null, token]);
        }
      } catch (_) {}
    }));

    _player = jsu.callConstructor(playerCtor, [options]);

    // Listeners
    jsu.callMethod(_player, 'addListener', [
      'ready',
      js.allowInterop((obj) {
        final id = jsu.getProperty(obj, 'device_id');
        if (id is String) {
          _deviceId = id;
        }
      })
    ]);

    jsu.callMethod(_player, 'addListener', [
      'not_ready',
      js.allowInterop((obj) {
        // Device went offline
        final id = jsu.getProperty(obj, 'device_id');
        if (_deviceId == id) {
          _deviceId = null;
        }
      })
    ]);

    // Optionally listen to errors (no-op here to keep minimal)
    for (final evt in const [
      'initialization_error',
      'authentication_error',
      'account_error',
      'playback_error',
    ]) {
      jsu.callMethod(_player, 'addListener', [evt, js.allowInterop((obj) {})]);
    }
  }

  Future<String?> connectAndGetDeviceId({Duration timeout = const Duration(seconds: 10)}) async {
    if (_player == null) {
      throw StateError('Player not initialized');
    }
    try {
      await jsu.promiseToFuture(jsu.callMethod(_player, 'connect', []));
      // connect() returns a boolean; nothing to use here.
    } catch (_) {}

    final deadline = DateTime.now().add(timeout);
    while (_deviceId == null && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return _deviceId;
  }

  String? get deviceId => _deviceId;

  Future<void> resume() async {
    if (_player == null) return;
    try {
      await jsu.promiseToFuture(jsu.callMethod(_player, 'resume', []));
    } catch (_) {}
  }

  Future<void> pause() async {
    if (_player == null) return;
    try {
      await jsu.promiseToFuture(jsu.callMethod(_player, 'pause', []));
    } catch (_) {}
  }
}
