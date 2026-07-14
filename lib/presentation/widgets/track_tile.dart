import 'package:flutter/material.dart';

import '../../domain/models/track.dart';

/// Riga riutilizzabile per mostrare un brano: copertina, titolo, artista,
/// durata e badge BPM (o invito a taggarlo se assente).
class TrackTile extends StatelessWidget {
  final Track track;
  final VoidCallback? onTap;
  final Widget? trailing;

  const TrackTile({super.key, required this.track, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final minutes = track.duration.inMinutes;
    final seconds = track.duration.inSeconds.remainder(60);

    return ListTile(
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: track.albumArtUrl != null
            ? Image.network(
                track.albumArtUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholderArt(),
              )
            : _placeholderArt(),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${track.artist} · $minutes:${seconds.toString().padLeft(2, '0')}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing ?? _bpmBadge(context),
    );
  }

  Widget _placeholderArt() {
    return Container(
      width: 48,
      height: 48,
      color: Colors.blueGrey.shade100,
      child: const Icon(Icons.music_note, color: Colors.blueGrey),
    );
  }

  Widget _bpmBadge(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!track.isTagged) {
      return Chip(
        label: const Text('Tagga BPM'),
        backgroundColor: scheme.errorContainer,
        labelStyle: TextStyle(color: scheme.onErrorContainer, fontSize: 12),
      );
    }
    return Chip(
      label: Text('${track.bpm} BPM'),
      backgroundColor: scheme.primaryContainer,
      labelStyle: TextStyle(color: scheme.onPrimaryContainer, fontSize: 12),
    );
  }
}
