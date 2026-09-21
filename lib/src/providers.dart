/// Riverpod wiring. Kept in one file on purpose: the dependency graph of this
/// app is small, and having it in a single place makes it readable.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/content_repository.dart';
import 'data/database.dart';
import 'data/progress_repository.dart';
import 'domain/models.dart';
import 'domain/session_planner.dart';
import 'domain/srs.dart';

// ------------------------------------------------------------ infrastructure

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => ContentRepository(),
);

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(ref.watch(appDatabaseProvider)),
);

/// Injected so tests and the "review as of" debug tooling can freeze time.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

// -------------------------------------------------------------------- search

class SearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
}

final searchQueryProvider = NotifierProvider<SearchQuery, String>(
  SearchQuery.new,
);

final searchResultsProvider = FutureProvider<List<TechnologySummary>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return ref.watch(contentRepositoryProvider).search(query);
});

final allTechnologiesProvider = FutureProvider<List<TechnologySummary>>(
  (ref) => ref.watch(contentRepositoryProvider).technologies(),
);

final technologySummaryProvider =
    FutureProvider.family<TechnologySummary, String>((ref, id) async {
      final all = await ref.watch(allTechnologiesProvider.future);
      return all.firstWhere((technology) => technology.id == id);
    });

// ------------------------------------------------------------------- content

final technologyContentProvider =
    FutureProvider.family<TechnologyContent, String>(
      (ref, id) => ref.watch(contentRepositoryProvider).load(id),
    );

// ------------------------------------------------------------------ progress

final schedulesProvider =
    StreamProvider.family<Map<String, ReviewSchedule>, String>(
      (ref, technologyId) =>
          ref.watch(progressRepositoryProvider).watchSchedules(technologyId),
    );

final exerciseStatusesProvider =
    StreamProvider.family<Map<String, ExerciseStatus>, String>(
      (ref, technologyId) => ref
          .watch(progressRepositoryProvider)
          .watchExerciseStatuses(technologyId),
    );

final completedMilestonesProvider = StreamProvider.family<Set<String>, String>(
  (ref, technologyId) => ref
      .watch(progressRepositoryProvider)
      .watchCompletedMilestones(technologyId),
);

final activityProvider = StreamProvider<List<DailyActivityData>>(
  (ref) => ref.watch(progressRepositoryProvider).watchActivity(),
);

// ------------------------------------------------------------------ practice

class SessionPolicyNotifier extends Notifier<SessionPolicy> {
  @override
  SessionPolicy build() => const SessionPolicy();

  void setMaxCards(int value) => state = state.copyWith(maxCards: value);

  void setMaxNewCards(int value) => state = state.copyWith(maxNewCards: value);

  void toggleLevel(SeniorityLevel level) {
    final next = {...state.levels};
    if (!next.remove(level)) next.add(level);
    // Never leave the user with an empty pool.
    if (next.isEmpty) return;
    state = state.copyWith(levels: next);
  }

  void setTopics(Set<String> topics) => state = state.copyWith(topics: topics);
}

final sessionPolicyProvider =
    NotifierProvider<SessionPolicyNotifier, SessionPolicy>(
      SessionPolicyNotifier.new,
    );

/// The set of cards a session would contain right now. Recomputes whenever
/// the schedules change, so the "por repasar" badge stays live.
///
/// Known limitation: `now` is captured when the provider is built and only
/// refreshes when a dependency changes. If the app stays open across
/// midnight, cards that came due overnight are not picked up until the next
/// review. Fixing it properly means invalidating this on app resume and on a
/// day boundary, which is the next thing to do here.
final sessionPlanProvider = Provider.family<AsyncValue<SessionPlan>, String>((
  ref,
  technologyId,
) {
  final content = ref.watch(technologyContentProvider(technologyId));
  final schedules = ref.watch(schedulesProvider(technologyId));
  final policy = ref.watch(sessionPolicyProvider);
  final now = ref.watch(clockProvider)();

  return content.whenData(
    (value) => const SessionPlanner().plan(
      pool: value.questions,
      schedules: schedules.value ?? const {},
      now: now,
      policy: policy,
    ),
  );
});

/// Aggregate mastery for one technology, shown on the technology header and
/// used by the stats screen.
typedef MasterySnapshot = ({
  int total,
  int seen,
  int learning,
  int mature,
  int dueNow,
});

final masteryProvider = Provider.family<AsyncValue<MasterySnapshot>, String>((
  ref,
  technologyId,
) {
  final content = ref.watch(technologyContentProvider(technologyId));
  final schedules = ref.watch(schedulesProvider(technologyId));
  final now = ref.watch(clockProvider)();

  return content.whenData((value) {
    final map = schedules.value ?? const <String, ReviewSchedule>{};
    var seen = 0;
    var learning = 0;
    var mature = 0;
    var dueNow = 0;
    for (final question in value.questions) {
      final schedule = map[question.id];
      if (schedule == null || schedule.isNew) continue;
      seen++;
      // "Mature" mirrors Anki's convention: an interval of three weeks or
      // more means the answer has survived several spaced recalls.
      if (schedule.intervalDays >= 21) {
        mature++;
      } else {
        learning++;
      }
      if (schedule.isDue(now)) dueNow++;
    }
    return (
      total: value.questions.length,
      seen: seen,
      learning: learning,
      mature: mature,
      dueNow: dueNow,
    );
  });
});
