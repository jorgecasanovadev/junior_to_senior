import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import '../widgets/common.dart';

/// Technical exercises. The point is not to grade code — we have no runner —
/// but to teach the *reasoning*: statement, graduated hints, the approach and
/// why it works, then a solution sketch.
class ExercisesTab extends ConsumerWidget {
  const ExercisesTab({required this.technologyId, super.key});

  final String technologyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(technologyContentProvider(technologyId));
    final statuses =
        ref.watch(exerciseStatusesProvider(technologyId)).value ?? const {};

    return content.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(error),
      data: (value) {
        if (value.exercises.isEmpty) {
          return const EmptyState(
            icon: Icons.construction,
            title: 'Todavía no hay ejercicios para esta tecnología',
            message: 'Se aceptan aportaciones en assets/content/.',
          );
        }
        final solved = value.exercises
            .where((exercise) => statuses[exercise.id] == ExerciseStatus.solved)
            .length;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: value.exercises.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '$solved de ${value.exercises.length} resueltos',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            final exercise = value.exercises[index - 1];
            return _ExerciseCard(
              exercise: exercise,
              status: statuses[exercise.id] ?? ExerciseStatus.notStarted,
            );
          },
        );
      },
    );
  }
}

class _ExerciseCard extends ConsumerStatefulWidget {
  const _ExerciseCard({required this.exercise, required this.status});

  final Exercise exercise;
  final ExerciseStatus status;

  @override
  ConsumerState<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends ConsumerState<_ExerciseCard> {
  /// How many hints the user has asked for. Revealing them one at a time is
  /// the difference between being helped and being spoiled.
  int _hintsShown = 0;
  bool _showSolution = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercise = widget.exercise;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: _StatusButton(
          status: widget.status,
          onChanged: (status) => ref
              .read(progressRepositoryProvider)
              .setExerciseStatus(
                exerciseId: exercise.id,
                technologyId: exercise.technologyId,
                status: status,
                now: DateTime.now(),
              ),
        ),
        title: Text(
          exercise.title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              DifficultyChip(exercise.difficulty),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  exercise.topic,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ContentMarkdown(exercise.statement),
          ),
          if (exercise.hints.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionLabel('Pistas ($_hintsShown/${exercise.hints.length})'),
            for (var i = 0; i < _hintsShown; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${i + 1}. ${exercise.hints[i]}'),
                ),
              ),
            if (_hintsShown < exercise.hints.length)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _hintsShown++),
                  icon: const Icon(Icons.lightbulb_outline, size: 18),
                  label: Text(
                    _hintsShown == 0 ? 'Dame una pista' : 'Otra pista',
                  ),
                ),
              ),
          ],
          const SizedBox(height: 12),
          if (!_showSolution)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showSolution = true),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Ver la lógica de la solución'),
              ),
            )
          else ...[
            _SectionLabel('Cómo se piensa'),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: ContentMarkdown(exercise.approach),
            ),
            const SizedBox(height: 16),
            _SectionLabel('Esbozo de la solución'),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: ContentMarkdown(exercise.solutionSketch),
            ),
            if (exercise.complexity.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.speed,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      exercise.complexity,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (exercise.pitfalls.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionLabel('Dónde se falla normalmente'),
              const SizedBox(height: 6),
              for (final pitfall in exercise.pitfalls)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠  '),
                      Expanded(child: Text(pitfall)),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Three-state tick: not started → attempted → solved.
class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.status, required this.onChanged});

  final ExerciseStatus status;
  final ValueChanged<ExerciseStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, tooltip) = switch (status) {
      ExerciseStatus.notStarted => (
        Icons.circle_outlined,
        scheme.outline,
        'Sin empezar',
      ),
      ExerciseStatus.attempted => (
        Icons.timelapse,
        const Color(0xFFE65100),
        'Intentado',
      ),
      ExerciseStatus.solved => (
        Icons.check_circle,
        const Color(0xFF2E7D32),
        'Resuelto',
      ),
    };

    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: color),
      onPressed: () {
        final next = ExerciseStatus
            .values[(status.index + 1) % ExerciseStatus.values.length];
        onChanged(next);
      },
    );
  }
}
