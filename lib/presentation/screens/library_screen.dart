import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/track.dart';
import '../providers/library_provider.dart';
import '../widgets/tap_tempo_dialog.dart';
import '../widgets/track_tile.dart';

/// Due tab: "Playlist Spotify" (per importare) e "Libreria" (brani già
/// importati, dove si tagga il BPM). Il tagging è manuale per i motivi
/// spiegati in domain/models/track.dart.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Brani'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Playlist Spotify'),
            Tab(text: 'La mia libreria'),
          ]),
        ),
        body: const TabBarView(
          children: [_PlaylistsTab(), _LibraryTab()],
        ),
        floatingActionButton: const _SearchFab(),
      ),
    );
  }
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(userPlaylistsProvider);
    final libraryState = ref.watch(libraryControllerProvider);
    final isImporting = libraryState.isLoading;

    return playlistsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Errore nel caricamento playlist: $e')),
      data: (playlists) {
        if (playlists.isEmpty) {
          return const Center(child: Text('Nessuna playlist trovata su Spotify.'));
        }
        return ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.favorite, color: Colors.pink),
              title: const Text('Liked Songs'),
              subtitle: const Text('Importa i tuoi brani "Mi piace"'),
              trailing: isImporting
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download),
              onTap: isImporting
                  ? null
                  : () => ref.read(libraryControllerProvider.notifier).importLikedSongs(),
            ),
            const Divider(),
            for (final playlist in playlists)
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: playlist.imageUrl != null
                      ? Image.network(playlist.imageUrl!, width: 44, height: 44, fit: BoxFit.cover)
                      : Container(width: 44, height: 44, color: Colors.blueGrey.shade100),
                ),
                title: Text(playlist.name),
                subtitle: Text('${playlist.trackCount} brani · ${playlist.ownerName}'),
                trailing: isImporting
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download),
                onTap: isImporting
                    ? null
                    : () => ref.read(libraryControllerProvider.notifier).importPlaylist(playlist.id),
              ),
          ],
        );
      },
    );
  }
}

class _LibraryTab extends ConsumerWidget {
  const _LibraryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(libraryControllerProvider);

    return libraryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Errore: $e')),
      data: (tracks) {
        if (tracks.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Libreria vuota. Importa una playlist o i Liked Songs dalla '
                'tab "Playlist Spotify" per iniziare a taggare i BPM.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final tagged = tracks.where((t) => t.isTagged).length;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('$tagged / ${tracks.length} brani taggati con BPM'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: tracks.length,
                itemBuilder: (context, i) {
                  final track = tracks[i];
                  return TrackTile(
                    track: track,
                    onTap: () => _openTagDialog(context, ref, track),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openTagDialog(BuildContext context, WidgetRef ref, Track track) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TapTempoDialog(track: track),
    );
    if (result == null) return;
    await ref.read(libraryControllerProvider.notifier).tagBpm(
          track.spotifyId,
          result['bpm'] as int,
          preferredPhase: result['preferredPhase'],
        );
  }
}

class _SearchFab extends ConsumerWidget {
  const _SearchFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      icon: const Icon(Icons.search),
      label: const Text('Cerca brano'),
      onPressed: () => showSearch(
        context: context,
        delegate: _TrackSearchDelegate(ref),
      ),
    );
  }
}

class _TrackSearchDelegate extends SearchDelegate<void> {
  final WidgetRef ref;
  _TrackSearchDelegate(this.ref);

  @override
  List<Widget> buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(child: Text('Digita per cercare un brano su Spotify'));
    }
    return FutureBuilder<List<Track>>(
      future: ref.read(libraryControllerProvider.notifier).searchSpotify(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return const Center(child: Text('Nessun risultato'));
        }
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, i) {
            final track = results[i];
            return TrackTile(
              track: track,
              trailing: IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () async {
                  await ref.read(libraryControllerProvider.notifier).addToLibrary(track);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"${track.title}" aggiunto alla libreria')),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
