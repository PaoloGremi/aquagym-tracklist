/// Configurazione dell'app letta da --dart-define, per non hardcodare
/// credenziali Spotify nel codice sorgente.
///
/// Esempio di avvio:
/// flutter run \
///   --dart-define=SPOTIFY_CLIENT_ID=xxxxxxxxxxxxxxxxxxxx \
///   --dart-define=SPOTIFY_REDIRECT_URI=aquagymtracklist://callback
class AppConfig {
  AppConfig._();

  /// Client ID dell'app creata su https://developer.spotify.com/dashboard.
  static const String spotifyClientId = String.fromEnvironment(
    'SPOTIFY_CLIENT_ID',
    defaultValue: '',
  );

  /// Deve coincidere ESATTAMENTE con uno dei Redirect URI registrati
  /// nel dashboard Spotify per l'app. Usiamo uno scheme custom
  /// perché flutter_web_auth_2 intercetta il redirect via deep link,
  /// non serve un vero server web.
  static const String spotifyRedirectUri = String.fromEnvironment(
    'SPOTIFY_REDIRECT_URI',
    defaultValue: 'aquagymtracklist://callback',
  );

  /// Scope minimi necessari:
  /// - user-read-email: identificare l'utente collegato
  /// - playlist-read-private / playlist-read-collaborative: leggere le playlist
  /// - user-library-read: leggere i "Liked Songs"
  /// - streaming + app-remote-control: controllare la riproduzione via SDK
  static const List<String> spotifyScopes = [
    'user-read-email',
    'playlist-read-private',
    'playlist-read-collaborative',
    'user-library-read',
    'streaming',
    'app-remote-control',
  ];

  static const String spotifyAuthorizeUrl = 'https://accounts.spotify.com/authorize';
  static const String spotifyTokenUrl = 'https://accounts.spotify.com/api/token';
  static const String spotifyApiBaseUrl = 'https://api.spotify.com/v1';

  /// Tolleranza usata dal generatore di scalette: quanto può differire
  /// (in secondi) la durata effettiva di una fase da quella richiesta
  /// prima di essere considerata "non riempita".
  static const int setlistDurationToleranceSeconds = 20;

  static bool get isConfigured => spotifyClientId.isNotEmpty;

  static void assertConfigured() {
    if (!isConfigured) {
      throw StateError(
        'SPOTIFY_CLIENT_ID non configurato. Avvia l\'app con '
        '--dart-define=SPOTIFY_CLIENT_ID=<il tuo client id>. '
        'Vedi README.md per la procedura completa.',
      );
    }
  }
}
