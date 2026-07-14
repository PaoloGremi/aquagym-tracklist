import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_db/local_database.dart';
import '../../data/repositories/lesson_repository.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../data/repositories/track_repository.dart';
import '../../data/spotify/spotify_api_client.dart';
import '../../data/spotify/spotify_auth_service.dart';
import '../../data/spotify/spotify_remote_service.dart';
import '../../domain/usecases/generate_setlist_usecase.dart';

/// [LocalDatabase] richiede un `init()` asincrono (apertura box Hive) prima
/// che qualunque schermata possa leggere/scrivere dati. Per questo NON lo
/// istanziamo qui: main.dart lo crea, chiama `await db.init()` e poi
/// sovrascrive questo provider con l'istanza già pronta tramite
/// `ProviderScope(overrides: [localDatabaseProvider.overrideWithValue(db)])`.
/// Se questo provider viene letto senza override, l'errore esplicito aiuta
/// a diagnosticare subito un main.dart configurato male.
final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  throw UnimplementedError(
    'localDatabaseProvider non sovrascritto: chiamare LocalDatabase().init() '
    'in main.dart prima di runApp() e passarlo come override.',
  );
});

final spotifyAuthServiceProvider = Provider<SpotifyAuthService>((ref) {
  return SpotifyAuthService();
});

final spotifyApiClientProvider = Provider<SpotifyApiClient>((ref) {
  return SpotifyApiClient(ref.watch(spotifyAuthServiceProvider));
});

final spotifyRemoteServiceProvider = Provider<SpotifyRemoteService>((ref) {
  return SpotifyRemoteService();
});

final generateSetlistUseCaseProvider = Provider<GenerateSetlistUseCase>((ref) {
  return GenerateSetlistUseCase();
});

final trackRepositoryProvider = Provider<TrackRepository>((ref) {
  return TrackRepository(
    ref.watch(localDatabaseProvider),
    ref.watch(spotifyApiClientProvider),
  );
});

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  return PlaylistRepository(ref.watch(spotifyApiClientProvider));
});

final lessonRepositoryProvider = Provider<LessonRepository>((ref) {
  return LessonRepository(
    ref.watch(localDatabaseProvider),
    ref.watch(generateSetlistUseCaseProvider),
  );
});
