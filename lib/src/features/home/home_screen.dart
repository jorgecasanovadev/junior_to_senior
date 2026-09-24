import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models.dart';
import '../../providers.dart';
import '../widgets/common.dart';

/// Landing screen: search a technology, pick it, go.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'junior → senior',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Tu progreso',
                          onPressed: () => context.push('/stats'),
                          icon: const Icon(Icons.insights_outlined),
                        ),
                        IconButton(
                          tooltip: 'Acerca de',
                          onPressed: () => context.push('/about'),
                          icon: const Icon(Icons.info_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Elige una tecnología: preguntas de entrevista, '
                      'ejercicios con su lógica, ruta de estudio y práctica '
                      'espaciada. Todo funciona sin conexión.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _InterviewEntry(),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      autofocus: false,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) =>
                          ref.read(searchQueryProvider.notifier).update(value),
                      decoration: InputDecoration(
                        hintText: 'Buscar tecnología (flutter, react, sql…)',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _controller.clear();
                                  ref
                                      .read(searchQueryProvider.notifier)
                                      .update('');
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            switch (results) {
              AsyncError(:final error) => SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorView(
                  error,
                  onRetry: () => ref.invalidate(allTechnologiesProvider),
                ),
              ),
              AsyncData(value: final list) when list.isEmpty =>
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.search_off,
                    title: 'Sin resultados',
                    message:
                        '¿Falta una tecnología? El contenido vive en '
                        'assets/content/ y se acepta por pull request.',
                  ),
                ),
              AsyncData(value: final list) => SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _TechnologyCard(summary: list[index]),
                ),
              ),
              _ => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _TechnologyCard extends ConsumerWidget {
  const _TechnologyCard({required this.summary});

  final TechnologySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = Color(summary.seedColor);
    final mastery = ref.watch(masteryProvider(summary.id)).value;

    return Card(
      child: InkWell(
        onTap: () => context.push('/t/${summary.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  summary.name.characters.first.toUpperCase(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            summary.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          summary.category,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary.tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _MiniStat(
                          icon: Icons.help_outline,
                          text: '${summary.questionCount} preguntas',
                        ),
                        const SizedBox(width: 12),
                        _MiniStat(
                          icon: Icons.code,
                          text: '${summary.exerciseCount} ejercicios',
                        ),
                        if (mastery != null && mastery.dueNow > 0) ...[
                          const SizedBox(width: 12),
                          _MiniStat(
                            icon: Icons.bolt,
                            text: '${mastery.dueNow} por repasar',
                            color: accent,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entry to the posting-driven guide. A card rather than a header icon
/// because it is a primary use, not a setting.
class _InterviewEntry extends StatelessWidget {
  const _InterviewEntry();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/interview'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.work_outline,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preparar una entrevista',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pega la oferta y arma una guía con el stack que piden.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: resolved),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: resolved),
        ),
      ],
    );
  }
}
