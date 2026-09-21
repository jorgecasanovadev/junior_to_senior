import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../domain/srs.dart';
import '../../providers.dart';
import '../widgets/common.dart';

/// The question bank. Filterable by level and topic, with the per-level
/// rubric hidden behind a toggle so the list stays scannable.
class QuestionsTab extends ConsumerStatefulWidget {
  const QuestionsTab({required this.technologyId, super.key});

  final String technologyId;

  @override
  ConsumerState<QuestionsTab> createState() => _QuestionsTabState();
}

class _QuestionsTabState extends ConsumerState<QuestionsTab> {
  SeniorityLevel? _level;
  String? _topic;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(technologyContentProvider(widget.technologyId));
    final schedules =
        ref.watch(schedulesProvider(widget.technologyId)).value ?? const {};

    return content.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(error),
      data: (value) {
        final topics = value.topics.toList()..sort();
        final filtered = value.questions
            .where((question) {
              if (_level != null && question.level != _level) return false;
              if (_topic != null && question.topic != _topic) return false;
              if (_query.isNotEmpty) {
                final needle = _query.toLowerCase();
                return question.prompt.toLowerCase().contains(needle) ||
                    question.tags.any(
                      (tag) => tag.toLowerCase().contains(needle),
                    );
              }
              return true;
            })
            .toList(growable: false);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Filtrar preguntas…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Todos'),
                    selected: _level == null,
                    onSelected: (_) => setState(() => _level = null),
                  ),
                  for (final level in SeniorityLevel.values) ...[
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(level.label),
                      selected: _level == level,
                      onSelected: (_) => setState(() => _level = level),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Todos los temas'),
                    selected: _topic == null,
                    onSelected: (_) => setState(() => _topic = null),
                  ),
                  for (final topic in topics) ...[
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(topic),
                      selected: _topic == topic,
                      onSelected: (_) => setState(
                        () => _topic = _topic == topic ? null : topic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${filtered.length} de ${value.questions.length} preguntas',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: EmptyState(
                  icon: Icons.filter_alt_off,
                  title: 'Ningún resultado con estos filtros',
                ),
              )
            else
              for (final (index, question) in filtered.indexed)
                QuestionCard(
                  index: index + 1,
                  question: question,
                  schedule: schedules[question.id],
                ),
          ],
        );
      },
    );
  }
}

class QuestionCard extends StatefulWidget {
  const QuestionCard({
    required this.index,
    required this.question,
    this.schedule,
    super.key,
  });

  final int index;
  final Question question;
  final ReviewSchedule? schedule;

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  bool _showRubric = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = widget.question;
    final schedule = widget.schedule;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          '${widget.index}. ${question.prompt}',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              LevelChip(question.level, dense: true),
              Text(
                question.topic,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (schedule != null && !schedule.isNew)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      formatNextReview(schedule.dueAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ContentMarkdown(question.answer),
          ),
          const SizedBox(height: 16),
          _RubricSection(
            rubric: question.rubric,
            expanded: _showRubric,
            onToggle: () => setState(() => _showRubric = !_showRubric),
          ),
          if (question.followUps.isNotEmpty) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Repreguntas probables',
                style: theme.textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 6),
            for (final followUp in question.followUps)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('→  '),
                    Expanded(
                      child: Text(
                        followUp,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// The differentiator: the same question answered at three levels, so the
/// user can hear the gap between where they are and where they want to be.
class _RubricSection extends StatelessWidget {
  const _RubricSection({
    required this.rubric,
    required this.expanded,
    required this.onToggle,
  });

  final AnswerRubric rubric;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '¿Cómo suena esta respuesta en cada nivel?',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          for (final level in SeniorityLevel.values)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
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
                  Text(
                    rubric.forLevel(level),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
