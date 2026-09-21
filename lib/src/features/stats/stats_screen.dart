import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database.dart';
import '../../providers.dart';
import '../widgets/common.dart';

/// Cross-technology progress: streak, a contribution-graph style heatmap and
/// per-technology mastery. Everything is derived from local data.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityProvider);
    final technologies = ref.watch(allTechnologiesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tu progreso')),
      body: activity.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(error),
        data: (days) {
          final totals = days.fold<int>(0, (sum, day) => sum + day.reviewed);
          final passed = days.fold<int>(0, (sum, day) => sum + day.passed);
          final minutes =
              days.fold<int>(0, (sum, day) => sum + day.secondsSpent) ~/ 60;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      StatPill(
                        label: 'racha',
                        value: '${_currentStreak(days)} días',
                        color: theme.colorScheme.primary,
                      ),
                      StatPill(label: 'repasos', value: '$totals'),
                      StatPill(
                        label: 'acierto',
                        value: totals == 0
                            ? '—'
                            : '${(passed / totals * 100).round()}%',
                      ),
                      StatPill(label: 'tiempo', value: '$minutes min'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Actividad', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              _Heatmap(days: days),
              const SizedBox(height: 28),
              Text('Por tecnología', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              ...switch (technologies) {
                AsyncData(value: final list) => [
                  for (final technology in list)
                    _TechnologyProgressRow(technologyId: technology.id),
                ],
                _ => const [Center(child: CircularProgressIndicator())],
              },
            ],
          );
        },
      ),
    );
  }

  /// Consecutive days with at least one review, counting back from today.
  /// Today not being studied yet does not break the streak.
  static int _currentStreak(List<DailyActivityData> days) {
    if (days.isEmpty) return 0;
    final studied = {
      for (final day in days)
        if (day.reviewed > 0)
          DateTime(day.day.year, day.day.month, day.day.day),
    };
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!studied.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (studied.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

/// A 17-week contribution graph. Cheap to render and instantly legible.
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.days});

  final List<DailyActivityData> days;

  static const _weeks = 17;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final byDay = {
      for (final day in days)
        DateTime(day.day.year, day.day.month, day.day.day): day.reviewed,
    };
    final maxReviews = byDay.values.fold<int>(0, (a, b) => a > b ? a : b);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Align the last column to the current week (Monday-first).
    final lastMonday = today.subtract(Duration(days: today.weekday - 1));
    final firstMonday = lastMonday.subtract(
      const Duration(days: 7 * (_weeks - 1)),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var week = 0; week < _weeks; week++)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Column(
                children: [
                  for (var weekday = 0; weekday < 7; weekday++)
                    Builder(
                      builder: (context) {
                        final date = firstMonday.add(
                          Duration(days: week * 7 + weekday),
                        );
                        final count = byDay[date] ?? 0;
                        final isFuture = date.isAfter(today);
                        final intensity = maxReviews == 0 || count == 0
                            ? 0.0
                            : 0.25 + 0.75 * (count / maxReviews);
                        return Tooltip(
                          message: isFuture
                              ? ''
                              : '${date.day}/${date.month}: $count repasos',
                          child: Container(
                            width: 14,
                            height: 14,
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: isFuture
                                  ? Colors.transparent
                                  : intensity == 0
                                  ? scheme.surfaceContainerHighest
                                  : scheme.primary.withValues(alpha: intensity),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TechnologyProgressRow extends ConsumerWidget {
  const _TechnologyProgressRow({required this.technologyId});

  final String technologyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(technologySummaryProvider(technologyId)).value;
    final mastery = ref.watch(masteryProvider(technologyId)).value;
    if (summary == null || mastery == null || mastery.seen == 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final accent = Color(summary.seedColor);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.push('/t/$technologyId'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${mastery.mature}/${mastery.total} consolidadas',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: mastery.total == 0
                      ? 0
                      : mastery.mature / mastery.total,
                  minHeight: 6,
                  color: accent,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
