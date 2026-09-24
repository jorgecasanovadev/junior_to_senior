import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/interview_planner.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import '../technology/questions_tab.dart';
import '../widgets/common.dart';

/// Paste a job posting, get a study guide cut from the bank for that stack.
class InterviewScreen extends ConsumerStatefulWidget {
  const InterviewScreen({this.initialPosting, super.key});

  /// Pre-fills and generates straight away. Used by the layout tests.
  final String? initialPosting;

  @override
  ConsumerState<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends ConsumerState<InterviewScreen> {
  static const _planner = InterviewPlanner();

  late final TextEditingController _controller;
  SeniorityLevel? _level;

  /// Once the user picks a level, a new posting no longer overrides it.
  bool _levelPicked = false;

  /// The posting the guide was built from. Separate from the field so the
  /// results do not reshuffle on every keystroke.
  String? _submitted;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPosting);
    _submitted = widget.initialPosting;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _generate() {
    FocusScope.of(context).unfocus();
    final text = _controller.text.trim();
    setState(() {
      _submitted = text.isEmpty ? null : text;
      if (!_levelPicked) _level = _planner.detectLevel(text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(allTechnologiesProvider);
    final contents = ref.watch(allContentProvider);
    final theme = Theme.of(context);
    final level = _level ?? SeniorityLevel.senior;

    final plan = switch ((catalog, contents, _submitted)) {
      (
        AsyncData(value: final techs),
        AsyncData(value: final all),
        final String text,
      ) =>
        _planner.plan(
          posting: text,
          catalog: techs,
          contents: all,
          level: level,
        ),
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preparar entrevista'),
        actions: [
          if (plan != null && !plan.isEmpty)
            IconButton(
              tooltip: 'Copiar como Markdown',
              icon: const Icon(Icons.copy_all_outlined),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: plan.toMarkdown()));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Guía copiada en Markdown')),
                );
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        children: [
          Text(
            'Pega la oferta o escribe el stack que piden. Se cruza con el '
            'banco de preguntas, sin conexión, y verás también lo que el '
            'banco todavía no cubre.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 4,
            maxLines: 10,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText:
                  'Ej.: Senior Flutter/Dart, BLoC, Clean Architecture, '
                  'APIs REST, OWASP, CI/CD, biometría, push…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final option in SeniorityLevel.values)
                ChoiceChip(
                  label: Text(option.label),
                  selected: level == option,
                  onSelected: (_) => setState(() {
                    _level = option;
                    _levelPicked = true;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Armar guía'),
          ),
          const SizedBox(height: 24),
          ..._results(context, catalog, contents, plan),
        ],
      ),
    );
  }

  List<Widget> _results(
    BuildContext context,
    AsyncValue<Object?> catalog,
    AsyncValue<Object?> contents,
    InterviewPlan? plan,
  ) {
    final theme = Theme.of(context);
    if (catalog case AsyncError(:final error)) return [ErrorView(error)];
    if (contents case AsyncError(:final error)) return [ErrorView(error)];
    if (_submitted == null) return const [];
    if (plan == null) {
      return const [Center(child: CircularProgressIndicator())];
    }
    if (plan.isEmpty) {
      return const [
        EmptyState(
          icon: Icons.search_off,
          title: 'No reconozco ese stack',
          message:
              'Prueba nombrando tecnologías (Flutter, TypeScript…) o temas '
              '(arquitectura, testing, seguridad, CI/CD…).',
        ),
      ];
    }

    return [
      Text('Detectado', style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final tech in plan.technologies)
            Chip(
              avatar: const Icon(Icons.code, size: 16),
              label: Text(tech.name),
              visualDensity: VisualDensity.compact,
            ),
          for (final topic in plan.topics)
            Chip(
              label: Text(topic.label),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
      if (plan.gaps.isNotEmpty) ...[
        const SizedBox(height: 16),
        _GapsCard(gaps: plan.gaps),
      ],
      const SizedBox(height: 16),
      Text(
        '${plan.questionCount} preguntas en ${plan.sections.length} bloques, '
        'priorizando nivel ${plan.level.label}',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      for (final (index, section) in plan.sections.indexed) ...[
        const SizedBox(height: 20),
        Text(
          '${index + 1}. ${section.title}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          section.reason,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final (position, question) in section.questions.indexed)
          QuestionCard(index: position + 1, question: question),
      ],
    ];
  }
}

class _GapsCard extends StatelessWidget {
  const _GapsCard({required this.gaps});

  final List<StackTopic> gaps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.tertiaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'La oferta lo pide y el banco aún no lo cubre',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              gaps.map((topic) => topic.label).join(' · '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Prepáralo por tu cuenta: aquí no hay preguntas revisadas '
              'todavía.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
