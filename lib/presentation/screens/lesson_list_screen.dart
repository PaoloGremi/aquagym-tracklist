import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/lesson_builder_provider.dart';
import '../providers/lesson_list_provider.dart';
import 'lesson_builder_screen.dart';
import 'live_player_screen.dart';
import 'setlist_editor_screen.dart';

/// Elenco delle lezioni salvate: da qui l'istruttore riapre un template
/// per modificarlo o lo avvia direttamente in modalità Live.
class LessonListScreen extends ConsumerWidget {
  const LessonListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(lessonListControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Le mie lezioni')),
      body: lessons.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nessuna lezione salvata. Tocca + per crearne una nuova.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              itemCount: lessons.length,
              itemBuilder: (context, i) {
                final lesson = lessons[i];
                final filled = lesson.isFullyFilled;
                return ListTile(
                  leading: Icon(
                    filled ? Icons.check_circle : Icons.warning_amber,
                    color: filled ? Colors.green : Colors.orange,
                  ),
                  title: Text(lesson.name),
                  subtitle: Text(
                    '${lesson.totalTargetDuration.inMinutes} min · '
                    '${lesson.allTracksInOrder.length} brani',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'delete') {
                        await ref.read(lessonListControllerProvider.notifier).delete(lesson.id);
                      } else if (value == 'edit') {
                        if (context.mounted) {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SetlistEditorScreen(existingLessonId: lesson.id),
                          ));
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Modifica scaletta')),
                      PopupMenuItem(value: 'delete', child: Text('Elimina')),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LivePlayerScreen(lessonId: lesson.id),
                  )),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nuova lezione'),
        onPressed: () {
          ref.read(lessonBuilderControllerProvider.notifier).reset();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const LessonBuilderScreen(),
          ));
        },
      ),
    );
  }
}
