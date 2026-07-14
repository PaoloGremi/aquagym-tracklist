import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/phase_type.dart';
import '../../core/theme/app_theme.dart';
import '../providers/lesson_builder_provider.dart';
import '../providers/lesson_list_provider.dart';
import 'setlist_editor_screen.dart';

/// Form per impostare durata totale, durata per fase e range BPM per fase.
/// "Genera scaletta automatica" delega al GenerateSetlistUseCase (via
/// LessonBuilderController) e poi apre l'editor con il risultato.
class LessonBuilderScreen extends ConsumerStatefulWidget {
  const LessonBuilderScreen({super.key});

  @override
  ConsumerState<LessonBuilderScreen> createState() => _LessonBuilderScreenState();
}

class _LessonBuilderScreenState extends ConsumerState<LessonBuilderScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(lessonBuilderControllerProvider);
    _nameController = TextEditingController(text: state.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lessonBuilderControllerProvider);
    final controller = ref.read(lessonBuilderControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Costruisci lezione')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nome lezione'),
            onChanged: controller.setName,
          ),
          const SizedBox(height: 24),
          Text('Durata totale: ${state.totalDuration.inMinutes} min',
              style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: state.totalDuration.inMinutes.clamp(15, 90).toDouble(),
            min: 15,
            max: 90,
            divisions: 75,
            label: '${state.totalDuration.inMinutes} min',
            onChanged: (v) => controller.setTotalDuration(Duration(minutes: v.round())),
          ),
          const SizedBox(height: 16),
          for (final phase in PhaseType.values)
            _PhaseCard(phase: phase, state: state, controller: controller),
          const SizedBox(height: 24),
          if (state.warnings.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attenzione',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    for (final w in state.warnings)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          w,
                          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: state.isGenerating
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(state.isGenerating ? 'Genero...' : 'Genera scaletta automatica'),
            onPressed: state.isGenerating
                ? null
                : () async {
                    await controller.generate();
                    if (!context.mounted) return;
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SetlistEditorScreen(),
                    ));
                  },
          ),
        ],
      ),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  final PhaseType phase;
  final LessonBuilderState state;
  final LessonBuilderController controller;

  const _PhaseCard({required this.phase, required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    final duration = state.durations[phase]!;
    final range = state.bpmRanges[phase]!;
    final color = AppTheme.colorForPhase(phase.name);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 6, backgroundColor: color),
                const SizedBox(width: 8),
                Text(phase.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${duration.inMinutes} min'),
              ],
            ),
            Slider(
              value: duration.inMinutes.clamp(1, 60).toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              activeColor: color,
              label: '${duration.inMinutes} min',
              onChanged: (v) => controller.setPhaseDuration(phase, Duration(minutes: v.round())),
            ),
            Text('Range BPM: ${range.$1} - ${range.$2}'),
            RangeSlider(
              values: RangeValues(range.$1.toDouble(), range.$2.toDouble()),
              min: 60,
              max: 180,
              divisions: 120,
              activeColor: color,
              labels: RangeLabels('${range.$1}', '${range.$2}'),
              onChanged: (v) =>
                  controller.setPhaseBpmRange(phase, v.start.round(), v.end.round()),
            ),
          ],
        ),
      ),
    );
  }
}
