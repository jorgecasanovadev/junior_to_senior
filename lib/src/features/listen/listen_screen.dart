import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models.dart';
import '../../providers.dart';
import '../widgets/common.dart';

/// What to listen to. Passed as the route's `extra` because the list can come
/// from a technology or from an interview guide.
class ListenRequest {
  const ListenRequest({required this.title, required this.questions});

  final String title;
  final List<Question> questions;
}

/// Hands-free study: questions, a silence to answer, then the answer. Keeps
/// playing with the screen off through the media session.
class ListenScreen extends ConsumerStatefulWidget {
  const ListenScreen({required this.request, super.key});

  final ListenRequest request;

  @override
  ConsumerState<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends ConsumerState<ListenScreen> {
  final Set<SeniorityLevel> _levels = {...SeniorityLevel.values};
  bool _shuffle = false;

  List<Question> get _selection {
    final picked = widget.request.questions
        .where((question) => _levels.contains(question.level))
        .toList();
    if (_shuffle) picked.shuffle();
    return picked;
  }

  Future<void> _start() async {
    final questions = _selection;
    if (questions.isEmpty) return;
    final handler = ref.read(audioHandlerProvider);
    await handler.load(title: widget.request.title, questions: questions);
    await handler.play();
  }

  @override
  Widget build(BuildContext context) {
    final handler = ref.watch(audioHandlerProvider);
    final theme = Theme.of(context);
    final available = widget.request.questions
        .where((question) => _levels.contains(question.level))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escuchar'),
        actions: [
          IconButton(
            tooltip: 'Ajustes de voz',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: StreamBuilder<PlaybackState>(
        stream: handler.playbackState,
        builder: (context, snapshot) {
          final state = snapshot.data ?? handler.playbackState.value;
          final active =
              state.processingState != AudioProcessingState.idle &&
              handler.questions.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
            children: [
              Text(
                widget.request.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Oirás la pregunta, tendrás unos segundos para responder en '
                'voz alta o mentalmente, y después la respuesta. Sigue '
                'sonando con el teléfono bloqueado.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final level in SeniorityLevel.values)
                    FilterChip(
                      label: Text(level.label),
                      selected: _levels.contains(level),
                      onSelected: (selected) => setState(() {
                        // Never leave the selection empty.
                        if (!selected && _levels.length == 1) return;
                        selected ? _levels.add(level) : _levels.remove(level);
                      }),
                    ),
                  FilterChip(
                    avatar: const Icon(Icons.shuffle, size: 16),
                    label: const Text('Aleatorio'),
                    selected: _shuffle,
                    onSelected: (value) => setState(() => _shuffle = value),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: available == 0 ? null : _start,
                icon: const Icon(Icons.headphones),
                label: Text(
                  active
                      ? 'Empezar de nuevo ($available)'
                      : 'Escuchar $available preguntas',
                ),
              ),
              if (active) ...[
                const SizedBox(height: 24),
                _NowPlaying(state: state),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _NowPlaying extends ConsumerWidget {
  const _NowPlaying({required this.state});

  final PlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);
    final theme = Theme.of(context);
    final questions = handler.questions;
    final current = state.queueIndex ?? handler.index;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pregunta ${current + 1} de ${questions.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                if (current < questions.length) ...[
                  LevelChip(questions[current].level, dense: true),
                  const SizedBox(height: 8),
                  Text(
                    questions[current].prompt,
                    style: theme.textTheme.titleMedium?.copyWith(height: 1.35),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Anterior',
                      iconSize: 32,
                      onPressed: current > 0 ? handler.skipToPrevious : null,
                      icon: const Icon(Icons.skip_previous),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filled(
                      tooltip: state.playing ? 'Pausar' : 'Reanudar',
                      iconSize: 40,
                      onPressed: state.playing ? handler.pause : handler.play,
                      icon: Icon(
                        state.playing ? Icons.pause : Icons.play_arrow,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Siguiente',
                      iconSize: 32,
                      onPressed: current < questions.length - 1
                          ? handler.skipToNext
                          : null,
                      icon: const Icon(Icons.skip_next),
                    ),
                  ],
                ),
                if (!state.playing)
                  Text(
                    'Al reanudar, la pregunta vuelve a empezar.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Lista', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        for (final (index, question) in questions.indexed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            selected: index == current,
            leading: Text(
              '${index + 1}',
              style: theme.textTheme.labelLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            title: Text(
              question.prompt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => handler.skipToQueueItem(index),
          ),
      ],
    );
  }
}
