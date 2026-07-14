import 'dart:async';

import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';

/// Wrapper attorno al package `spotify_sdk`, che espone su Flutter
/// l'Android App Remote SDK / iOS SDK di Spotify: controlliamo la
/// riproduzione sull'app Spotify ufficiale installata sul device.
///
/// L'app AquaGym Tracklist NON riproduce mai audio proprio: i brani sono
/// protetti da DRM e Spotify non consente di accedere allo stream audio
/// grezzo né di alterarne la velocità/tempo. Possiamo solo comandare
/// play/pause/skip/seek sul player Spotify.
///
/// Nota implementativa: la superficie esatta dei metodi di `spotify_sdk`
/// può variare leggermente tra versioni del package: verificare la firma
/// su pub.dev per la versione effettivamente risolta da `flutter pub get`
/// prima del primo build.
class SpotifyRemoteService {
  bool _connected = false;

  Future<bool> isSpotifyAppInstalled() async {
    // Lo scheme "spotify:" è gestito solo se l'app Spotify è installata.
    return canLaunchUrl(Uri.parse('spotify:'));
  }

  Future<void> connect() async {
    AppConfig.assertConfigured();
    final installed = await isSpotifyAppInstalled();
    if (!installed) {
      throw StateError(
        'App Spotify non trovata sul device. Installala per riprodurre '
        'la lezione (serve inoltre un account Spotify Premium).',
      );
    }
    await SpotifySdk.connectToSpotifyRemote(
      clientId: AppConfig.spotifyClientId,
      redirectUrl: AppConfig.spotifyRedirectUri,
    );
    _connected = true;
  }

  Future<void> disconnect() async {
    if (!_connected) return;
    await SpotifySdk.disconnect();
    _connected = false;
  }

  Future<void> play(String spotifyTrackUri) async {
    if (!_connected) await connect();
    await SpotifySdk.play(spotifyUri: spotifyTrackUri);
  }

  Future<void> pause() => SpotifySdk.pause();

  Future<void> resume() => SpotifySdk.resume();

  Future<void> skipNext() => SpotifySdk.skipNext();

  Future<void> skipPrevious() => SpotifySdk.skipPrevious();

  Future<void> seekTo(Duration position) =>
      SpotifySdk.seekTo(positionedMilliseconds: position.inMilliseconds);

  /// Stream dello stato del player Spotify (traccia corrente, posizione,
  /// play/pause, ecc.). Usato dal LivePlayerController per capire quando
  /// un brano è terminato e passare automaticamente al successivo.
  Stream<PlayerState> subscribePlayerState() {
    return SpotifySdk.subscribePlayerState();
  }
}
