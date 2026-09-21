/// Everything the user has produced, persisted locally through drift.
///
/// The repository speaks in domain types ([ReviewSchedule], [ExerciseStatus])
/// so no UI code ever touches a generated drift row.
library;

import 'package:drift/drift.dart';

import '../domain/srs.dart';
import 'database.dart';

/// A question paired with its scheduling state, as needed to build a session.
typedef ScheduledQuestion = ({String questionId, ReviewSchedule schedule});

class ProgressRepository {
  ProgressRepository(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------- reviews

  Future<Map<String, ReviewSchedule>> schedulesFor(String technologyId) async {
    final rows = await (_db.select(
      _db.questionReviews,
    )..where((row) => row.technologyId.equals(technologyId))).get();
    return {for (final row in rows) row.questionId: _toSchedule(row)};
  }

  Stream<Map<String, ReviewSchedule>> watchSchedules(String technologyId) {
    return (_db.select(
      _db.questionReviews,
    )..where((row) => row.technologyId.equals(technologyId))).watch().map(
      (rows) => {for (final row in rows) row.questionId: _toSchedule(row)},
    );
  }

  /// Persists one review and bumps today's activity counters in a single
  /// transaction, so the stats can never drift from the schedule.
  Future<ReviewSchedule> recordReview({
    required String questionId,
    required String technologyId,
    required ReviewGrade grade,
    required DateTime now,
    int secondsSpent = 0,
  }) async {
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.questionReviews,
      )..where((row) => row.questionId.equals(questionId))).getSingleOrNull();

      final current = existing == null
          ? const ReviewSchedule()
          : _toSchedule(existing);
      final next = current.review(grade, now: now);

      await _db
          .into(_db.questionReviews)
          .insertOnConflictUpdate(
            QuestionReviewsCompanion.insert(
              questionId: questionId,
              technologyId: technologyId,
              easiness: Value(next.easiness),
              repetitions: Value(next.repetitions),
              intervalDays: Value(next.intervalDays),
              dueAt: Value(next.dueAt),
              lastReviewedAt: Value(now),
              lapses: Value(next.lapses),
              totalReviews: Value(next.totalReviews),
              bookmarked: Value(existing?.bookmarked ?? false),
            ),
          );

      await _bumpActivity(
        now: now,
        passed: grade.isPass ? 1 : 0,
        secondsSpent: secondsSpent,
      );

      return next;
    });
  }

  Future<void> setBookmark({
    required String questionId,
    required String technologyId,
    required bool bookmarked,
  }) async {
    await _db
        .into(_db.questionReviews)
        .insertOnConflictUpdate(
          QuestionReviewsCompanion.insert(
            questionId: questionId,
            technologyId: technologyId,
            bookmarked: Value(bookmarked),
          ),
        );
  }

  /// Wipes scheduling for one technology. Exposed in the UI as "empezar de
  /// cero", which people ask for more often than you would expect.
  Future<void> resetTechnology(String technologyId) async {
    await (_db.delete(
      _db.questionReviews,
    )..where((row) => row.technologyId.equals(technologyId))).go();
  }

  // -------------------------------------------------------------- exercises

  Stream<Map<String, ExerciseStatus>> watchExerciseStatuses(
    String technologyId,
  ) {
    return (_db.select(_db.exerciseProgressRows)
          ..where((row) => row.technologyId.equals(technologyId)))
        .watch()
        .map((rows) => {for (final row in rows) row.exerciseId: row.status});
  }

  Future<void> setExerciseStatus({
    required String exerciseId,
    required String technologyId,
    required ExerciseStatus status,
    required DateTime now,
  }) async {
    await _db
        .into(_db.exerciseProgressRows)
        .insertOnConflictUpdate(
          ExerciseProgressRowsCompanion.insert(
            exerciseId: exerciseId,
            technologyId: technologyId,
            status: Value(status),
            updatedAt: now,
          ),
        );
  }

  // -------------------------------------------------------------- milestones

  Stream<Set<String>> watchCompletedMilestones(String technologyId) {
    return (_db.select(_db.milestoneChecks)
          ..where((row) => row.technologyId.equals(technologyId)))
        .watch()
        .map((rows) => rows.map((row) => row.milestoneId).toSet());
  }

  Future<void> toggleMilestone({
    required String milestoneId,
    required String technologyId,
    required String stageId,
    required bool completed,
    required DateTime now,
  }) async {
    if (completed) {
      await _db
          .into(_db.milestoneChecks)
          .insertOnConflictUpdate(
            MilestoneChecksCompanion.insert(
              milestoneId: milestoneId,
              technologyId: technologyId,
              stageId: stageId,
              completedAt: now,
            ),
          );
    } else {
      await (_db.delete(
        _db.milestoneChecks,
      )..where((row) => row.milestoneId.equals(milestoneId))).go();
    }
  }

  // ------------------------------------------------------------------ stats

  Stream<List<DailyActivityData>> watchActivity({int lastDays = 120}) {
    final from = _startOfDay(DateTime.now()).subtract(Duration(days: lastDays));
    return (_db.select(_db.dailyActivity)
          ..where((row) => row.day.isBiggerOrEqualValue(from))
          ..orderBy([(row) => OrderingTerm.asc(row.day)]))
        .watch();
  }

  Future<void> _bumpActivity({
    required DateTime now,
    required int passed,
    required int secondsSpent,
  }) async {
    final day = _startOfDay(now);
    await _db.customStatement(
      'INSERT INTO daily_activity (day, reviewed, passed, seconds_spent) '
      'VALUES (?, 1, ?, ?) '
      'ON CONFLICT(day) DO UPDATE SET '
      'reviewed = reviewed + 1, '
      'passed = passed + excluded.passed, '
      'seconds_spent = seconds_spent + excluded.seconds_spent',
      [day.millisecondsSinceEpoch ~/ 1000, passed, secondsSpent],
    );
  }

  static ReviewSchedule _toSchedule(QuestionReview row) {
    return ReviewSchedule(
      easiness: row.easiness,
      repetitions: row.repetitions,
      intervalDays: row.intervalDays,
      dueAt: row.dueAt,
      lapses: row.lapses,
      totalReviews: row.totalReviews,
    );
  }

  static DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
