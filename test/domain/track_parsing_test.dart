import 'package:flutter_test/flutter_test.dart';
import 'package:aquagym_tracklist/domain/models/track.dart';

void main() {
  group('Track.fromSpotifyJson', () {
    test('effettua il parsing di un track "nudo" (es. risultato /search)', () {
      final json = {
        'id': '3n3Ppam7vgaVa1iaRUc9Lp',
        'uri': 'spotify:track:3n3Ppam7vgaVa1iaRUc9Lp',
        'name': 'Mr. Brightside',
        'duration_ms': 222973,
        'artists': [
          {'name': 'The Killers'},
        ],
        'album': {
          'images': [
            {'url': 'https://example.com/art.jpg'},
          ],
        },
      };

      final track = Track.fromSpotifyJson(json);

      expect(track.spotifyId, '3n3Ppam7vgaVa1iaRUc9Lp');
      expect(track.title, 'Mr. Brightside');
      expect(track.artist, 'The Killers');
      expect(track.duration, const Duration(milliseconds: 222973));
      expect(track.albumArtUrl, 'https://example.com/art.jpg');
      expect(track.bpm, isNull, reason: 'il BPM non arriva mai dalla Web API');
    });

    test('effettua il parsing del wrapper {"track": {...}} di /playlists/{id}/tracks', () {
      final json = {
        'added_at': '2026-01-01T00:00:00Z',
        'track': {
          'id': 'abc123',
          'uri': 'spotify:track:abc123',
          'name': 'Some Song',
          'duration_ms': 180000,
          'artists': [
            {'name': 'Artist One'},
            {'name': 'Artist Two'},
          ],
          'album': {'images': []},
        },
      };

      final track = Track.fromSpotifyJson(json);

      expect(track.spotifyId, 'abc123');
      expect(track.artist, 'Artist One, Artist Two');
      expect(track.albumArtUrl, isNull);
    });

    test('gestisce campi mancanti con fallback ragionevoli', () {
      final json = {'id': 'xyz'};

      final track = Track.fromSpotifyJson(json);

      expect(track.title, 'Titolo sconosciuto');
      expect(track.artist, 'Artista sconosciuto');
      expect(track.duration, Duration.zero);
      expect(track.uri, 'spotify:track:xyz');
    });
  });

  group('Track db round-trip', () {
    test('toDbMap -> fromDbMap preserva tutti i campi incluso il bpm taggato', () {
      const track = Track(
        spotifyId: 'id1',
        uri: 'spotify:track:id1',
        title: 'Titolo',
        artist: 'Artista',
        duration: Duration(seconds: 200),
        bpm: 128,
      );

      final restored = Track.fromDbMap(track.toDbMap());

      expect(restored.spotifyId, track.spotifyId);
      expect(restored.bpm, 128);
      expect(restored.duration, track.duration);
    });
  });
}
