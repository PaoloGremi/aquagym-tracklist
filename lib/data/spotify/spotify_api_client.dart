import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/track.dart';
import 'spotify_auth_service.dart';

class SpotifyApiException implements Exception {
  final int statusCode;
  final String message;
  SpotifyApiException(this.statusCode, this.message);
  @override
  String toString() => 'SpotifyApiException($statusCode): $message';
}

/// Client per la Spotify Web API (dati: playlist, liked songs, ricerca).
/// Il BPM NON viene richiesto qui: vedi nota di deprecazione in Track.
class SpotifyApiClient {
  final SpotifyAuthService _auth;
  final http.Client _http;

  SpotifyApiClient(this._auth, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getValidAccessToken();
    return {'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await _http.get(uri, headers: await _headers());
    if (response.statusCode == 401) {
      // token potenzialmente invalidato lato Spotify: un solo retry dopo
      // aver forzato un nuovo getValidAccessToken (che internamente
      // rifà il refresh se scaduto). Se fallisce di nuovo, propaghiamo.
      final retryHeaders = await _headers();
      final retry = await _http.get(uri, headers: retryHeaders);
      if (retry.statusCode != 200) {
        throw SpotifyApiException(retry.statusCode, retry.body);
      }
      return jsonDecode(retry.body) as Map<String, dynamic>;
    }
    if (response.statusCode != 200) {
      throw SpotifyApiException(response.statusCode, response.body);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Scorre tutte le pagine seguendo il campo "next" finché non è null,
  /// applicando [extractItems] a ciascuna pagina.
  Future<List<T>> _paginate<T>(
    Uri firstPage,
    List<T> Function(Map<String, dynamic> page) extractItems,
    String Function(Map<String, dynamic> page) itemsRootKeyOrSelf,
  ) async {
    final results = <T>[];
    Uri? next = firstPage;
    while (next != null) {
      final page = await _get(next);
      // Alcuni endpoint (es. /me/tracks, /playlists/{id}/tracks) ritornano
      // direttamente l'oggetto paginato; altri (es. /me/playlists) uguale.
      results.addAll(extractItems(page));
      final nextUrl = page['next'] as String?;
      next = nextUrl != null ? Uri.parse(nextUrl) : null;
    }
    return results;
  }

  Future<List<SpotifyPlaylist>> getUserPlaylists() {
    final uri = Uri.parse('${AppConfig.spotifyApiBaseUrl}/me/playlists')
        .replace(queryParameters: {'limit': '50'});
    return _paginate<SpotifyPlaylist>(
      uri,
      (page) => (page['items'] as List)
          .map((e) => SpotifyPlaylist.fromJson(e as Map<String, dynamic>))
          .toList(),
      (page) => 'items',
    );
  }

  Future<List<Track>> getPlaylistTracks(String playlistId) {
    final uri = Uri.parse(
      '${AppConfig.spotifyApiBaseUrl}/playlists/$playlistId/tracks',
    ).replace(queryParameters: {'limit': '100'});
    return _paginate<Track>(
      uri,
      (page) => (page['items'] as List)
          .where((e) => e['track'] != null)
          .map((e) => Track.fromSpotifyJson(e as Map<String, dynamic>))
          .toList(),
      (page) => 'items',
    );
  }

  Future<List<Track>> getLikedTracks() {
    final uri = Uri.parse('${AppConfig.spotifyApiBaseUrl}/me/tracks')
        .replace(queryParameters: {'limit': '50'});
    return _paginate<Track>(
      uri,
      (page) => (page['items'] as List)
          .map((e) => Track.fromSpotifyJson(e as Map<String, dynamic>))
          .toList(),
      (page) => 'items',
    );
  }

  Future<List<Track>> searchTracks(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.parse('${AppConfig.spotifyApiBaseUrl}/search').replace(
      queryParameters: {
        'q': query,
        'type': 'track',
        'limit': '$limit',
      },
    );
    final page = await _get(uri);
    final items = (page['tracks']?['items'] as List?) ?? const [];
    return items
        .map((e) => Track.fromSpotifyJson(e as Map<String, dynamic>))
        .toList();
  }
}
