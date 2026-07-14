import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

class SpotifyAuthException implements Exception {
  final String message;
  SpotifyAuthException(this.message);
  @override
  String toString() => 'SpotifyAuthException: $message';
}

class SpotifyTokens {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  const SpotifyTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 30)));
}

/// Gestisce il login Spotify con OAuth 2.0 Authorization Code + PKCE, che è
/// il flusso corretto per app mobile pubbliche (nessun client secret
/// distribuito con l'app). I token vengono persistiti in secure storage.
class SpotifyAuthService {
  static const _kAccessToken = 'spotify_access_token';
  static const _kRefreshToken = 'spotify_refresh_token';
  static const _kExpiresAt = 'spotify_expires_at';

  final FlutterSecureStorage _storage;
  final http.Client _http;

  SpotifyAuthService({
    FlutterSecureStorage? storage,
    http.Client? httpClient,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _http = httpClient ?? http.Client();

  String _generateCodeVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rand = Random.secure();
    return List.generate(96, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _codeChallengeFrom(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Avvia il flusso di login: apre il browser di sistema sulla pagina di
  /// autorizzazione Spotify e intercetta il redirect via deep link
  /// (flutter_web_auth_2), poi scambia il code con i token.
  Future<SpotifyTokens> login() async {
    AppConfig.assertConfigured();

    final verifier = _generateCodeVerifier();
    final challenge = _codeChallengeFrom(verifier);
    final state = _generateCodeVerifier().substring(0, 16);

    final authorizeUri = Uri.parse(AppConfig.spotifyAuthorizeUrl).replace(
      queryParameters: {
        'client_id': AppConfig.spotifyClientId,
        'response_type': 'code',
        'redirect_uri': AppConfig.spotifyRedirectUri,
        'code_challenge_method': 'S256',
        'code_challenge': challenge,
        'state': state,
        'scope': AppConfig.spotifyScopes.join(' '),
      },
    );

    final callbackScheme = Uri.parse(AppConfig.spotifyRedirectUri).scheme;

    final String resultUrl;
    try {
      resultUrl = await FlutterWebAuth2.authenticate(
        url: authorizeUri.toString(),
        callbackUrlScheme: callbackScheme,
      );
    } catch (e) {
      throw SpotifyAuthException('Login annullato o fallito: $e');
    }

    final redirected = Uri.parse(resultUrl);
    final returnedState = redirected.queryParameters['state'];
    final code = redirected.queryParameters['code'];
    final error = redirected.queryParameters['error'];

    if (error != null) {
      throw SpotifyAuthException('Spotify ha rifiutato il login: $error');
    }
    if (returnedState != state) {
      throw SpotifyAuthException('State mismatch: possibile tentativo di CSRF.');
    }
    if (code == null) {
      throw SpotifyAuthException('Nessun authorization code ricevuto.');
    }

    return _exchangeCodeForTokens(code, verifier);
  }

  Future<SpotifyTokens> _exchangeCodeForTokens(String code, String verifier) async {
    final response = await _http.post(
      Uri.parse(AppConfig.spotifyTokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': AppConfig.spotifyClientId,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': AppConfig.spotifyRedirectUri,
        'code_verifier': verifier,
      },
    );

    if (response.statusCode != 200) {
      throw SpotifyAuthException(
        'Scambio token fallito (${response.statusCode}): ${response.body}',
      );
    }

    final tokens = _tokensFromJson(jsonDecode(response.body) as Map<String, dynamic>);
    await _persist(tokens);
    return tokens;
  }

  Future<SpotifyTokens> _refresh(String refreshToken) async {
    final response = await _http.post(
      Uri.parse(AppConfig.spotifyTokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': AppConfig.spotifyClientId,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
    );

    if (response.statusCode != 200) {
      throw SpotifyAuthException(
        'Refresh token fallito (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    // Spotify a volte non ritorna un nuovo refresh_token: in quel caso
    // manteniamo quello attuale.
    final tokens = SpotifyTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String? ?? refreshToken,
      expiresAt: DateTime.now().add(Duration(seconds: json['expires_in'] as int)),
    );
    await _persist(tokens);
    return tokens;
  }

  SpotifyTokens _tokensFromJson(Map<String, dynamic> json) {
    return SpotifyTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: DateTime.now().add(Duration(seconds: json['expires_in'] as int)),
    );
  }

  Future<void> _persist(SpotifyTokens tokens) async {
    await _storage.write(key: _kAccessToken, value: tokens.accessToken);
    await _storage.write(key: _kRefreshToken, value: tokens.refreshToken);
    await _storage.write(key: _kExpiresAt, value: tokens.expiresAt.toIso8601String());
  }

  Future<SpotifyTokens?> _readPersisted() async {
    final access = await _storage.read(key: _kAccessToken);
    final refresh = await _storage.read(key: _kRefreshToken);
    final expiresAtRaw = await _storage.read(key: _kExpiresAt);
    if (access == null || refresh == null || expiresAtRaw == null) return null;
    return SpotifyTokens(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: DateTime.parse(expiresAtRaw),
    );
  }

  Future<bool> get isLoggedIn async => (await _readPersisted()) != null;

  /// Ritorna un access token valido, effettuando il refresh in automatico
  /// se necessario. Lancia [SpotifyAuthException] se l'utente non è mai
  /// stato loggato o il refresh fallisce (sessione scaduta -> richiede
  /// nuovo login esplicito).
  Future<String> getValidAccessToken() async {
    final stored = await _readPersisted();
    if (stored == null) {
      throw SpotifyAuthException('Utente non collegato a Spotify.');
    }
    if (!stored.isExpired) return stored.accessToken;

    final refreshed = await _refresh(stored.refreshToken);
    return refreshed.accessToken;
  }

  Future<void> logout() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kExpiresAt);
  }
}
