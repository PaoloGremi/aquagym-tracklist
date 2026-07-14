import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/phase_type.dart';
import '../../domain/models/track.dart';
import '../providers/core_providers.dart';
import '../providers/lesson_builder_provider.dart';
import '../providers/lesson_list_provider.dart';
import '../widgets/track_tile.dart';

/// Editor manuale della scaletta: riordino drag&drop (ReorderableListView
/// nativo, nessuna dipendenza extra), rimozione/aggiunta brano per fase,
/// salvataggio come template riutilizzabile.
///
/// Se [existingLessonId] è valorizzato, carica quella lezione salvata per
/// modificarla (mantiene lo stesso id). Altrimenti mostra il risultato
/// appena prodotto da LessonBuilderScreen -> "Genera scaletta automatica".
class SetlistEditorScreen extends ConsumerStatefulWidget {
  final String? existingLessonId;

  const SetlistEditorScreen({super.key, this.existingLessonId});

  @override
  ConsumerState<SetlistEditorScreen> createState() => _SetlistEditorScreenState();
}

class _SetlistEditorScreenState extends ConsumerState<SetlistEditorScreen> {
  @override
  void initState() {
    super.initState();
    final id = widget.existingLessonId;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final plan = ref.read(lessonRepositoryProvider).getLesson(id);
        if (plan != null) {
          ref.read(lessonBuilderControllerProvider.notifier).loadExisting(plan);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lessonBuilderControllerProvider);
    final controller = ref.read(lessonBuilderControllerProvider.notifier);
    final plan = state.generatedPlan;

    return Scaffold(
      appBar: AppBar(title: Text(state.name)),
      body: plan == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final phase in plan.phases)
                  _PhaseSetlistSection(phaseType: phase.type),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.save),
        label: const Text('Salva lezione'),
        onPressed: plan == null
            ? null
            : () async {
                await controller.save();
                ref.read(lessonListControllerProvider.notifier).refresh();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
      ),
    );
  }
}

class _PhaseSetlistSection extends ConsumerWidget {
  final PhaseType phaseType;

  const _PhaseSetlistSection({required this.phaseType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lessonBuilderControllerProvider);
    final controller = ref.read(lessonBuilderControllerProvider.notifier);
    final phase = state.generatedPlan!.phaseOf(phaseType);
    final color = AppTheme.colorForPhase(phaseType.name);
    final filled = phase.isFilled();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 6, backgroundColor: color),
                const SizedBox(width: 8),
                Text(phaseType.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Icon(filled ? Icons.check_circle : Icons.warning_amber,
                    color: filled ? Colors.green : Colors.orange, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${_fmt(phase.actualDuration)} / ${_fmt(phase.targetDuration)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            if (phase.tracks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Nessun brano in questa fase.'),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: phase.tracks.length,
                onReorder: (oldIndex, newIndex) =>
                    controller.reorderTrackInPhase(phaseType, oldIndex, newIndex),
                itemBuilder: (context, i) {
                  final track = phase.tracks[i];
                  return TrackTile(
                    key: ValueKey(track.spotifyId),
                    track: track,
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => controller.removeTrack(phaseType, track.spotifyId),
                    ),
                  );
                },
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi brano'),
                onPressed: () => _openAddTrackSheet(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Future<void> _openAddTrackSheet(BuildContext context, WidgetRef ref) async {
    final library = ref.read(trackRepositoryProvider).taggedLibrary;
    final state = ref.read(lessonBuilderControllerProvider);
    final phase = state.generatedPlan!.phaseOf(phaseType);
    final alreadyInPhase = phase.tracks.map((t) => t.spotifyId).toSet();
    final controller = ref.read(lessonBuilderControllerProvider.notifier);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          expand: false,
          builder: (_, scrollController) {
            final candidates = library.where((t) => !alreadyInPhase.contains(t.spotifyId)).toList()
              ..sort((a, b) {
                final aIn = a.matchesBpmRange(phase.bpmMin, phase.bpmMax) ? 0 : 1;
                final bIn = b.matchesBpmRange(phase.bpmMin, phase.bpmMax) ? 0 : 1;
                return aIn.compareTo(bIn);
              });
            if (candidates.isEmpty) {
              return const Center(child: Text('Nessun altro brano taggato disponibile.'));
            }
            return ListView.builder(
              controller: scrollController,
              itemCount: candidates.length,
              itemBuilder: (context, i) {
                final Track track = candidates[i];
                final inRange = track.matchesBpmRange(phase.bpmMin, phase.bpmMax);
                return TrackTile(
                  track: track,
                  trailing: inRange
                      ? const Icon(Icons.check, color: Colors.green)
                      : const Icon(Icons.info_outline, color: Colors.orange),
                  onTap: () {
                    controller.addTrack(phaseType, track);
                    Navigator.of(sheetContext).pop();
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
