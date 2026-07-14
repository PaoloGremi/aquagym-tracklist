import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/track_repository.dart';
import '../../domain/models/phase_type.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/track.dart';
import 'core_providers.dart';

/// Elenco delle playlist Spotify dell'utente (sempre fresco da rete).
final userPlaylistsProvider = FutureProvider<List<SpotifyPlaylist>>((ref) {
  return ref.watch(playlistRepositoryProvider).getUserPlaylists();
});

/// Libreria locale di brani importati (taggati o meno).
class LibraryController extends StateNotifier<AsyncValue<List<Track>>> {
  final TrackRepository _repo;

  LibraryController(this._repo) : super(const AsyncValue.loading()) {
    _load();
  }

  void _load() {
    state = AsyncValue.data(_repo.getLibrary());
  }

  Future<void> importPlaylist(String playlistId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.importPlaylistTracks(playlistId);
      _load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> importLikedSongs() async {
    state = const AsyncValue.loading();
    try {
      await _repo.importLikedTracks();
      _load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<List<Track>> searchSpotify(String query) => _repo.searchSpotify(query);

  Future<void> addToLibrary(Track track) async {
    await _repo.addTrackToLibrary(track);
    _load();
  }

  Future<void> tagBpm(String spotifyId, int bpm, {PhaseType? preferredPhase}) async {
    await _repo.tagBpm(spotifyId, bpm, preferredPhase: preferredPhase);
    _load();
  }

  Future<void> removeFromLibrary(String spotifyId) async {
    await _repo.removeFromLibrary(spotifyId);
    _load();
  }
}

final libraryControllerProvider =
    StateNotifierProvider<LibraryController, AsyncValue<List<Track>>>((ref) {
  return LibraryController(ref.watch(trackRepositoryProvider));
});
