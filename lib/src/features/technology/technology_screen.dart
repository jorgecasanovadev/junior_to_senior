import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers.dart';
import '../listen/listen_screen.dart';
import '../widgets/common.dart';
import 'exercises_tab.dart';
import 'questions_tab.dart';
import 'roadmap_tab.dart';

/// Shell for one technology. Re-seeds the theme with the technology's brand
/// colour so the whole section feels like "the React part" of the app.
class TechnologyScreen extends ConsumerWidget {
  const TechnologyScreen({required this.technologyId, super.key});

  final String technologyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(technologySummaryProvider(technologyId));
    final content = ref.watch(technologyContentProvider(technologyId));

    return switch ((summary, content)) {
      (AsyncError(:final error), _) ||
      (_, AsyncError(:final error)) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          error,
          onRetry: () =>
              ref.invalidate(technologyContentProvider(technologyId)),
        ),
      ),
      (AsyncData(value: final tech), AsyncData()) => Theme(
        data: buildTheme(
          seed: Color(tech.seedColor),
          brightness: Theme.of(context).brightness,
        ),
        child: _Loaded(technologyId: technologyId, name: tech.name),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({required this.technologyId, required this.name});

  final String technologyId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mastery = ref.watch(masteryProvider(technologyId)).value;
    final plan = ref.watch(sessionPlanProvider(technologyId)).value;
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              title: Text(name),
              actions: [
                IconButton(
                  tooltip: 'Escuchar preguntas de $name',
                  icon: const Icon(Icons.headphones),
                  onPressed: () {
                    final content = ref
                        .read(technologyContentProvider(technologyId))
                        .value;
                    if (content == null) return;
                    context.push(
                      '/listen',
                      extra: ListenRequest(
                        title: name,
                        questions: content.questions,
                      ),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Reiniciar progreso de $name',
                  icon: const Icon(Icons.restart_alt),
                  onPressed: () => _confirmReset(context, ref),
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Preguntas'),
                  Tab(text: 'Ejercicios'),
                  Tab(text: 'Ruta'),
                ],
              ),
            ),
            if (mastery != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Wrap, not Row: four labels like "en aprendizaje"
                      // do not fit side by side on a narrow phone.
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          StatPill(
                            label: 'vistas',
                            value: '${mastery.seen}/${mastery.total}',
                          ),
                          StatPill(
                            label: 'consolidadas',
                            value: '${mastery.mature}',
                            color: theme.colorScheme.levelColor(0),
                          ),
                          StatPill(
                            label: 'en aprendizaje',
                            value: '${mastery.learning}',
                            color: theme.colorScheme.levelColor(1),
                          ),
                          StatPill(
                            label: 'por repasar',
                            value: '${mastery.dueNow}',
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: mastery.total == 0
                              ? 0
                              : mastery.mature / mastery.total,
                          minHeight: 6,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          body: TabBarView(
            children: [
              QuestionsTab(technologyId: technologyId),
              ExercisesTab(technologyId: technologyId),
              RoadmapTab(technologyId: technologyId),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/t/$technologyId/practice'),
          icon: const Icon(Icons.play_arrow),
          label: Text(
            plan == null || plan.isEmpty
                ? 'Practicar'
                : 'Practicar · ${plan.questions.length}',
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Reiniciar $name?'),
        content: const Text(
          'Se borrará el historial de repasos de esta tecnología. '
          'Los ejercicios y la ruta de estudio se mantienen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(progressRepositoryProvider).resetTechnology(technologyId);
    }
  }
}
