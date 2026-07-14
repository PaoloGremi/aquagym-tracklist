import 'phase_type.dart';

/// Un brano Spotify importato nella libreria locale dell'istruttore.
///
/// [bpm] è NULL finché l'istruttore non lo tagga manualmente: Spotify ha
/// deprecato l'endpoint `audio-features` per le nuove app dal 27/11/2024,
/// quindi il BPM non è più ottenibile automaticamente dalle API pubbliche.
class Track {
  final String spotifyId; // id "grezzo", es. "3n3Ppam7vgaVa1iaRUc9Lp"
  final String uri; // "spotify:track:3n3Ppam7vgaVa1iaRUc9Lp", usato per il play
  final String title;
  final String artist;
  final String? albumArtUrl;
  final Duration duration;
  final int? bpm;
  final PhaseType? preferredPhase;

  const Track({
    required this.spotifyId,
    required this.uri,
    required this.title,
    required this.artist,
    required this.duration,
    this.albumArtUrl,
    this.bpm,
    this.preferredPhase,
  });

  bool get isTagged => bpm != null;

  bool matchesBpmRange(int min, int max) => bpm != null && bpm! >= min && bpm! <= max;

  Track copyWith({
    String? title,
    String? artist,
    String? albumArtUrl,
    Duration? duration,
    int? bpm,
    bool clearBpm = false,
    PhaseType? preferredPhase,
    bool clearPreferredPhase = false,
  }) {
    return Track(
      spotifyId: spotifyId,
      uri: uri,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      albumArtUrl: albumArtUrl ?? this.albumArtUrl,
      duration: duration ?? this.duration,
      bpm: clearBpm ? null : (bpm ?? this.bpm),
      preferredPhase: clearPreferredPhase ? null : (preferredPhase ?? this.preferredPhase),
    );
  }

  /// Costruisce un [Track] a partire da un oggetto "track" restituito dalla
  /// Spotify Web API. Gestisce sia il caso di un track "nudo" (es. risultato
  /// di /search o /me/tracks[].track) sia il wrapper `{ "track": {...} }`
  /// usato da /playlists/{id}/tracks negli item.
  factory Track.fromSpotifyJson(Map<String, dynamic> json) {
    final raw = (json['track'] is Map<String, dynamic>)
        ? json['track'] as Map<String, dynamic>
        : json;

    final images = (raw['album']?['images'] as List?) ?? const [];
    final artists = (raw['artists'] as List?) ?? const [];

    return Track(
      spotifyId: raw['id'] as String,
      uri: raw['uri'] as String? ?? 'spotify:track:${raw['id']}',
      title: raw['name'] as String? ?? 'Titolo sconosciuto',
      artist: artists.isNotEmpty
          ? artists.map((a) => a['name']).whereType<String>().join(', ')
          : 'Artista sconosciuto',
      albumArtUrl: images.isNotEmpty ? images.first['url'] as String? : null,
      duration: Duration(milliseconds: raw['duration_ms'] as int? ?? 0),
      // bpm intenzionalmente non popolato qui: arriva solo dal tagging manuale
      // o, in fase di import, viene preservato da un eventuale tag già salvato
      // in locale (vedi TrackRepository.importPlaylistTracks).
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'spotifyId': spotifyId,
      'uri': uri,
      'title': title,
      'artist': artist,
      'albumArtUrl': albumArtUrl,
      'durationMs': duration.inMilliseconds,
      'bpm': bpm,
      'preferredPhase': preferredPhase?.name,
    };
  }

  factory Track.fromDbMap(Map map) {
    return Track(
      spotifyId: map['spotifyId'] as String,
      uri: map['uri'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      albumArtUrl: map['albumArtUrl'] as String?,
      duration: Duration(milliseconds: map['durationMs'] as int),
      bpm: map['bpm'] as int?,
      preferredPhase: map['preferredPhase'] != null
          ? PhaseType.values.byName(map['preferredPhase'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) => other is Track && other.spotifyId == spotifyId;

  @override
  int get hashCode => spotifyId.hashCode;
}
