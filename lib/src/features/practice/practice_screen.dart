import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../domain/srs.dart';
import '../../providers.dart';
import '../widgets/common.dart';
import 'practice_controller.dart';

/// Mock interview: one question at a time, a timer, self-assessment, and
/// SM-2 deciding when you see it again.
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({required this.technologyId, super.key});

  final String technologyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(technologySummaryProvider(technologyId)).value;
    final session = ref.watch(practiceControllerProvider(technologyId));

    final body = switch (session) {
      null => _SetupView(technologyId: technologyId),
      final state when state.finished => _SummaryView(
        technologyId: technologyId,
        state: state,
      ),
      final state => _CardView(technologyId: technologyId, state: state),
    };

    return Theme(
      data: buildTheme(
        seed: Color(summary?.seedColor ?? 0xFF0553B1),
        brightness: Theme.of(context).brightness,
      ),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(summary?.name ?? 'Práctica'),
            actions: [
              if (session != null && !session.finished)
                TextButton(
                  onPressed: () => ref
                      .read(practiceControllerProvider(technologyId).notifier)
                      .finish(),
                  child: const Text('Terminar'),
                ),
            ],
            bottom: session == null || session.finished
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(4),
                    child: LinearProgressIndicator(
                      value: session.progress,
                      minHeight: 4,
                    ),
                  ),
          ),
          body: SafeArea(child: body),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- setup

class _SetupView extends ConsumerWidget {
  const _SetupView({required this.technologyId});

  final String technologyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final policy = ref.watch(sessionPolicyProvider);
    final planAsync = ref.watch(sessionPlanProvider(technologyId));
    final plan = planAsync.value;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Sesión de práctica', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Se te muestran las preguntas de una en una. Respóndelas en voz '
          'alta, como en una entrevista real, y luego evalúate. Tu honestidad '
          'es lo que calibra cuándo vuelven a aparecer.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        if (plan != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 16,
                runSpacing: 12,
                children: [
                  StatPill(label: 'repasos', value: '${plan.dueCount}'),
                  StatPill(label: 'nuevas', value: '${plan.newCount}'),
                  StatPill(
                    label: 'pendientes hoy',
                    value: '${plan.totalDueAvailable}',
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        Text('Niveles', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final level in SeniorityLevel.values)
              FilterChip(
                label: Text(level.label),
                selected: policy.levels.contains(level),
                onSelected: (_) =>
                    ref.read(sessionPolicyProvider.notifier).toggleLevel(level),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _SliderRow(
          label: 'Tarjetas por sesión',
          value: policy.maxCards,
          min: 5,
          max: 50,
          onChanged: (value) =>
              ref.read(sessionPolicyProvider.notifier).setMaxCards(value),
        ),
        _SliderRow(
          label: 'Preguntas nuevas como máximo',
          value: policy.maxNewCards,
          min: 0,
          max: 20,
          onChanged: (value) =>
              ref.read(sessionPolicyProvider.notifier).setMaxNewCards(value),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: plan == null || plan.isEmpty
              ? null
              : () => ref
                    .read(practiceControllerProvider(technologyId).notifier)
                    .start(),
          icon: const Icon(Icons.play_arrow),
          label: Text(
            plan == null
                ? 'Cargando…'
                : plan.isEmpty
                ? 'Nada pendiente, vuelve mañana'
                : 'Empezar · ${plan.questions.length} preguntas',
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        if (plan != null && plan.isEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Estás al día con lo programado. Puedes subir el límite de '
            'preguntas nuevas para adelantar trabajo.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text(
              '$value',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        Slider(
          value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          onChanged: (raw) => onChanged(raw.round()),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- card

class _CardView extends ConsumerStatefulWidget {
  const _CardView({required this.technologyId, required this.state});

  final String technologyId;
  final PracticeState state;

  @override
  ConsumerState<_CardView> createState() => _CardViewState();
}

class _CardViewState extends ConsumerState<_CardView> {
  Timer? _ticker;
  Duration _onThisCard = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _onThisCard = DateTime.now().difference(widget.state.cardShownAt);
      });
    });
  }

  @override
  void didUpdateWidget(covariant _CardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.cardShownAt != widget.state.cardShownAt) {
      _onThisCard = Duration.zero;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final question = state.current!;
    final controller = ref.read(
      practiceControllerProvider(widget.technologyId).notifier,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              LevelChip(question.level, dense: true),
              const SizedBox(width: 8),
              Text(
                question.topic,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.timer_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                _mmss(_onThisCard),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'quedan ${state.remaining}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            children: [
              Text(
                question.prompt,
                style: theme.textTheme.headlineSmall?.copyWith(
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!state.revealed) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.record_voice_over_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Respóndela en voz alta antes de mirar. El esfuerzo '
                          'de recuperar es lo que fija el recuerdo.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                ContentMarkdown(question.answer),
                const SizedBox(height: 20),
                Text(
                  'Tu respuesta debería sonar a…',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                for (final level in SeniorityLevel.values)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: theme.colorScheme.surfaceContainerHighest,
                      border: Border(
                        left: BorderSide(
                          color: theme.colorScheme.levelColor(level.index),
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LevelChip(level, dense: true),
                        const SizedBox(height: 6),
                        Text(question.rubric.forLevel(level)),
                      ],
                    ),
                  ),
                if (question.followUps.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Prepárate para la repregunta',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  for (final followUp in question.followUps)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('→  $followUp'),
                    ),
                ],
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: state.revealed
                ? Row(
                    children: [
                      for (final grade in ReviewGrade.values)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _GradeButton(
                              grade: grade,
                              onPressed: () => controller.grade(grade),
                            ),
                          ),
                        ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: controller.reveal,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Mostrar respuesta'),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  static String _mmss(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({required this.grade, required this.onPressed});

  final ReviewGrade grade;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = switch (grade) {
      ReviewGrade.again => const Color(0xFFC62828),
      ReviewGrade.partial => const Color(0xFFE65100),
      ReviewGrade.solid => const Color(0xFF2E7D32),
    };
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.14),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(
        grade.label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

// ----------------------------------------------------------------- summary

class _SummaryView extends ConsumerWidget {
  const _SummaryView({required this.technologyId, required this.state});

  final String technologyId;
  final PracticeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final elapsed = state.elapsed(DateTime.now());
    final plan = ref.watch(sessionPlanProvider(technologyId)).value;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Icon(
          Icons.check_circle_outline,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Sesión completada',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 32),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 12,
              children: [
                StatPill(label: 'respondidas', value: '${state.answered}'),
                StatPill(
                  label: 'acierto',
                  value: '${(state.accuracy * 100).round()}%',
                ),
                StatPill(label: 'falladas', value: '${state.lapsed}'),
                StatPill(label: 'tiempo', value: '${elapsed.inMinutes} min'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (plan != null)
          Text(
            plan.totalDueAvailable == 0
                ? 'No te queda nada programado para hoy.'
                : 'Te quedan ${plan.totalDueAvailable} preguntas pendientes '
                      'para hoy.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (state.lastSchedule != null) ...[
          const SizedBox(height: 8),
          Text(
            'La última pregunta vuelve '
            '${formatNextReview(state.lastSchedule!.dueAt)}.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () {
            final controller = ref.read(
              practiceControllerProvider(technologyId).notifier,
            );
            controller.reset();
            controller.start();
          },
          child: const Text('Otra sesión'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            ref.read(practiceControllerProvider(technologyId).notifier).reset();
            Navigator.of(context).pop();
          },
          child: const Text('Volver'),
        ),
      ],
    );
  }
}
