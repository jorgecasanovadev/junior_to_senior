import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import '../widgets/common.dart';

/// The study roadmap, rendered as a vertical timeline of stages. Milestones
/// are checkable and persisted, which is what turns a static article into a
/// plan the user is actually walking.
class RoadmapTab extends ConsumerWidget {
  const RoadmapTab({required this.technologyId, super.key});

  final String technologyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(technologyContentProvider(technologyId));
    final completed =
        ref.watch(completedMilestonesProvider(technologyId)).value ??
        const <String>{};

    return content.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(error),
      data: (value) {
        if (value.roadmap.isEmpty) {
          return const EmptyState(
            icon: Icons.map_outlined,
            title: 'Ruta de estudio pendiente',
          );
        }
        // Only the stage the user is actually on opens by default. Opening
        // every incomplete stage means four cards of ~2000px and no overview;
        // opening none gives no hint that there is anything inside.
        final currentStage = value.roadmap.indexWhere(
          (stage) => stage.milestones.any((m) => !completed.contains(m.id)),
        );

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: value.roadmap.length,
          itemBuilder: (context, index) => _StageCard(
            stage: value.roadmap[index],
            number: index + 1,
            startsExpanded: index == currentStage,
            technologyId: technologyId,
            completed: completed,
            isLast: index == value.roadmap.length - 1,
          ),
        );
      },
    );
  }
}

class _StageCard extends ConsumerWidget {
  const _StageCard({
    required this.stage,
    required this.number,
    required this.startsExpanded,
    required this.technologyId,
    required this.completed,
    required this.isLast,
  });

  /// Diameter of the timeline marker.
  static const double dotSize = 28;

  /// Pushes the marker down so its centre lines up with the first line of the
  /// card title instead of with the card's top border. Asserted in
  /// test/layout_test.dart so a change in the tile's padding gets caught.
  static const double dotTopOffset = 12;

  final RoadmapStage stage;

  /// Position in the roadmap, 1-based. Deliberately not derived from the
  /// seniority level: several stages share a level, which made the markers
  /// read 1, 1, 2, 3 instead of 1, 2, 3, 4.
  final int number;

  /// Whether this is the stage the user is currently working through.
  final bool startsExpanded;
  final String technologyId;
  final Set<String> completed;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.levelColor(stage.level.index);
    final done = stage.milestones.where((m) => completed.contains(m.id)).length;
    final progress = stage.milestones.isEmpty
        ? 0.0
        : done / stage.milestones.length;

    // The timeline rail is a Positioned line inside a Stack rather than an
    // Expanded inside an IntrinsicHeight.
    //
    // IntrinsicHeight asks the row for its intrinsic height, but an expanded
    // ExpansionTile lays out taller than it reports, so the tile ended up in
    // a box too short for it and painted the overflow stripes. A Stack sizes
    // itself to the Row and lets the line stretch to the card's real height,
    // which also skips the extra (and expensive) intrinsic layout pass.
    return Stack(
      children: [
        if (!isLast)
          Positioned(
            // 13 plus half of the 2px line centres it under the dot.
            left: 13,
            top: dotTopOffset + dotSize,
            bottom: 0,
            child: Container(width: 2, color: theme.colorScheme.outlineVariant),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: dotTopOffset),
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: progress == 1 ? accent : accent.withValues(alpha: 0.15),
                border: Border.all(color: accent, width: 2),
              ),
              alignment: Alignment.center,
              child: progress == 1
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '$number',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                child: Card(
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    // PageStorageKey so that opening or closing a card
                    // survives the ListView recycling it while scrolling.
                    key: PageStorageKey(stage.id),
                    initiallyExpanded: startsExpanded,
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    title: Text(
                      stage.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              LevelChip(stage.level, dense: true),
                              const SizedBox(width: 8),
                              // Expanded, not Spacer: on a 320px screen
                              // the duration label must be able to shrink.
                              Expanded(
                                child: Text(
                                  formatWeeks(stage.estimatedWeeks),
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$done/${stage.milestones.length}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 4,
                              color: accent,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                            ),
                          ),
                        ],
                      ),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          stage.goal,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final skill in stage.skills)
                              Chip(
                                label: Text(skill),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final milestone in stage.milestones)
                        CheckboxListTile(
                          value: completed.contains(milestone.id),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            milestone.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(milestone.detail),
                          onChanged: (checked) => ref
                              .read(progressRepositoryProvider)
                              .toggleMilestone(
                                milestoneId: milestone.id,
                                technologyId: technologyId,
                                stageId: stage.id,
                                completed: checked ?? false,
                                now: DateTime.now(),
                              ),
                        ),
                      if (stage.readinessSignals.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sabes que has superado esta etapa cuando…',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: accent,
                                ),
                              ),
                              const SizedBox(height: 6),
                              for (final signal in stage.readinessSignals)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('✓  '),
                                      Expanded(child: Text(signal)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (stage.resources.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Recursos',
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        for (final resource in stage.resources)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(_iconFor(resource.kind), size: 18),
                            title: Text(resource.title),
                            subtitle: Text(resource.kind.label),
                            trailing: const Icon(Icons.open_in_new, size: 16),
                            onTap: () => _openResource(context, resource.url),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static IconData _iconFor(ResourceKind kind) => switch (kind) {
    ResourceKind.docs => Icons.menu_book_outlined,
    ResourceKind.article => Icons.article_outlined,
    ResourceKind.video => Icons.play_circle_outline,
    ResourceKind.book => Icons.book_outlined,
    ResourceKind.course => Icons.school_outlined,
    ResourceKind.repo => Icons.code,
  };

  /// Resources are external links. The app itself never needs the network,
  /// but opening a reference in the browser obviously does.
  Future<void> _openResource(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No se pudo abrir el enlace: $url'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
