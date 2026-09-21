/// Local, offline-first persistence for everything the user produces:
/// review scheduling, exercise status and roadmap progress.
///
/// Nothing here is ever uploaded. The curated content lives in bundled assets
/// and is read-only, so the database only stores the delta the user creates.
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

part 'database.g.dart';

/// Spaced repetition state, one row per question the user has actually seen.
/// Questions with no row are "new" and are introduced gradually.
class QuestionReviews extends Table {
  TextColumn get questionId => text()();
  TextColumn get technologyId => text()();
  RealColumn get easiness => real().withDefault(const Constant(2.5))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get lastReviewedAt => dateTime().nullable()();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  IntColumn get totalReviews => integer().withDefault(const Constant(0))();
  BoolColumn get bookmarked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {questionId};
}

enum ExerciseStatus { notStarted, attempted, solved }

class ExerciseProgressRows extends Table {
  TextColumn get exerciseId => text()();
  TextColumn get technologyId => text()();
  IntColumn get status =>
      intEnum<ExerciseStatus>().withDefault(const Constant(0))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {exerciseId};
}

/// One row per roadmap milestone the user has ticked off.
class MilestoneChecks extends Table {
  TextColumn get milestoneId => text()();
  TextColumn get technologyId => text()();
  TextColumn get stageId => text()();
  DateTimeColumn get completedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {milestoneId};
}

/// Aggregated per-day activity, used by the stats screen and the streak
/// counter. Stored as a date-keyed row so the table stays small forever.
class DailyActivity extends Table {
  DateTimeColumn get day => dateTime()();
  IntColumn get reviewed => integer().withDefault(const Constant(0))();
  IntColumn get passed => integer().withDefault(const Constant(0))();
  IntColumn get secondsSpent => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {day};
}

@DriftDatabase(
  tables: [
    QuestionReviews,
    ExerciseProgressRows,
    MilestoneChecks,
    DailyActivity,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Visible for testing: lets tests inject an in-memory executor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'junior_to_senior',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
        onResult: (result) {
          if (kDebugMode && result.missingFeatures.isNotEmpty) {
            debugPrint(
              'drift/web: degraded storage, missing ${result.missingFeatures}',
            );
          }
        },
      ),
    );
  }
}
