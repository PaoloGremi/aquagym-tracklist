/// Una playlist Spotify dell'utente collegato (solo metadati: il contenuto
/// dei brani viene caricato on-demand quando l'istruttore la importa).
class SpotifyPlaylist {
  final String id;
  final String name;
  final String? imageUrl;
  final int trackCount;
  final String ownerName;

  const SpotifyPlaylist({
    required this.id,
    required this.name,
    required this.trackCount,
    required this.ownerName,
    this.imageUrl,
  });

  factory SpotifyPlaylist.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List?) ?? const [];
    return SpotifyPlaylist(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Playlist senza nome',
      trackCount: json['tracks']?['total'] as int? ?? 0,
      ownerName: json['owner']?['display_name'] as String? ?? 'Sconosciuto',
      imageUrl: images.isNotEmpty ? images.first['url'] as String? : null,
    );
  }
}
