typedef TokenProvider = Future<String?> Function();

class WebSpotifyPlayer {
  Future<void> init({required TokenProvider getToken, String name = 'Thomster Web Player'}) async {
    throw UnsupportedError('WebSpotifyPlayer is only available on web builds');
  }

  Future<String?> connectAndGetDeviceId({Duration timeout = const Duration(seconds: 10)}) async {
    return null;
  }

  String? get deviceId => null;

  Future<void> resume() async {}
  Future<void> pause() async {}
}
