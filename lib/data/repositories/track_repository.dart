import '../../domain/models/phase_type.dart';
import '../../domain/models/track.dart';
import '../local_db/local_database.dart';
import '../spotify/spotify_api_client.dart';

/// Gestisce la libreria locale di brani (import da Spotify + BPM taggati).
///
/// I brani "vivono" davvero nella libreria solo dopo essere stati importati
/// esplicitamente (da una playlist, dai Liked Songs, o aggiunti singolarmente
/// da una ricerca): l'app non salva in locale l'intero catalogo Spotify.
class TrackRepository {
  final LocalDatabase _db;
  final SpotifyApiClient _api;

  TrackRepository(this._db, this._api);

  List<Track> getLibrary() => _db.getAllTracks();

  List<Track> get taggedLibrary =>
      _db.getAllTracks().where((t) => t.isTagged).toList();

  /// Importa i brani di una playlist Spotify nella libreria locale.
  /// Se un brano è già presente in locale (già importato prima), il suo
  /// BPM/etichetta fase già taggati vengono preservati: l'import NON
  /// sovrascrive un tag manuale esistente.
  Future<List<Track>> importPlaylistTracks(String playlistId) async {
    final remoteTracks = await _api.getPlaylistTracks(playlistId);
    return _mergeAndPersist(remoteTracks);
  }

  Future<List<Track>> importLikedTracks() async {
    final remoteTracks = await _api.getLikedTracks();
    return _mergeAndPersist(remoteTracks);
  }

  Future<List<Track>> searchSpotify(String query) => _api.searchTracks(query);

  /// Aggiunge un singolo brano (es. da un risultato di ricerca) alla
  /// libreria locale, senza BPM (da taggare subito dopo).
  Future<void> addTrackToLibrary(Track track) async {
    final existing = _db.getTrack(track.spotifyId);
    await _db.upsertTrack(existing ?? track);
  }

  Future<List<Track>> _mergeAndPersist(List<Track> remoteTracks) async {
    final merged = <Track>[];
    for (final remote in remoteTracks) {
      final existing = _db.getTrack(remote.spotifyId);
      final toSave = existing != null
          ? remote.copyWith(bpm: existing.bpm, preferredPhase: existing.preferredPhase)
          : remote;
      await _db.upsertTrack(toSave);
      merged.add(toSave);
    }
    return merged;
  }

  Future<void> tagBpm(
    String spotifyId,
    int bpm, {
    PhaseType? preferredPhase,
  }) async {
    final track = _db.getTrack(spotifyId);
    if (track == null) {
      throw StateError('Brano $spotifyId non presente in libreria.');
    }
    final updated = track.copyWith(bpm: bpm, preferredPhase: preferredPhase);
    await _db.upsertTrack(updated);
  }

  Future<void> removeFromLibrary(String spotifyId) => _db.deleteTrack(spotifyId);
}
