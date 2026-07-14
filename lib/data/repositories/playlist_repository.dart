import '../../domain/models/playlist.dart';
import '../spotify/spotify_api_client.dart';

/// Legge le playlist dell'utente Spotify collegato. Nessuna persistenza
/// locale: l'elenco playlist è sempre richiesto fresco a Spotify, solo il
/// loro CONTENUTO (i brani) viene importato in libreria su richiesta
/// esplicita dell'istruttore (vedi TrackRepository.importPlaylistTracks).
class PlaylistRepository {
  final SpotifyApiClient _api;

  PlaylistRepository(this._api);

  Future<List<SpotifyPlaylist>> getUserPlaylists() => _api.getUserPlaylists();
}
