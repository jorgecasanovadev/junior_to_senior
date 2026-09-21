/// Decides *which* questions a practice session contains.
///
/// Separated from the SM-2 maths and from the UI so the policy ("how many new
/// cards per day", "do overdue cards come first") is a pure function that can
/// be tuned and tested in isolation.
library;

import 'models.dart';
import 'srs.dart';

/// Tuning knobs for a session. The defaults are deliberately modest: the
/// failure mode of a study app is an overwhelming first session.
class SessionPolicy {
  const SessionPolicy({
    this.maxCards = 20,
    this.maxNewCards = 5,
    this.levels = const {
      SeniorityLevel.junior,
      SeniorityLevel.mid,
      SeniorityLevel.senior,
    },
    this.topics = const {},
  });

  final int maxCards;

  /// Cap on never-seen questions, so a session is mostly consolidation.
  final int maxNewCards;

  /// Which seniority levels to draw from.
  final Set<SeniorityLevel> levels;

  /// Empty means "every topic".
  final Set<String> topics;

  SessionPolicy copyWith({
    int? maxCards,
    int? maxNewCards,
    Set<SeniorityLevel>? levels,
    Set<String>? topics,
  }) {
    return SessionPolicy(
      maxCards: maxCards ?? this.maxCards,
      maxNewCards: maxNewCards ?? this.maxNewCards,
      levels: levels ?? this.levels,
      topics: topics ?? this.topics,
    );
  }
}

class SessionPlan {
  const SessionPlan({
    required this.questions,
    required this.dueCount,
    required this.newCount,
    required this.totalDueAvailable,
  });

  final List<Question> questions;

  /// How many of [questions] are reviews of already-seen material.
  final int dueCount;
  final int newCount;

  /// Everything that *could* have been reviewed today, ignoring [maxCards].
  /// Used to tell the user "te quedan 43 por repasar".
  final int totalDueAvailable;

  bool get isEmpty => questions.isEmpty;
}

class SessionPlanner {
  const SessionPlanner();

  SessionPlan plan({
    required List<Question> pool,
    required Map<String, ReviewSchedule> schedules,
    required DateTime now,
    SessionPolicy policy = const SessionPolicy(),
  }) {
    final eligible = pool
        .where((question) {
          if (!policy.levels.contains(question.level)) return false;
          if (policy.topics.isNotEmpty &&
              !policy.topics.contains(question.topic)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    final due = <Question>[];
    final fresh = <Question>[];
    for (final question in eligible) {
      final schedule = schedules[question.id];
      if (schedule == null || schedule.isNew) {
        fresh.add(question);
      } else if (schedule.isDue(now)) {
        due.add(question);
      }
    }

    // Most overdue first: those are the ones closest to being forgotten.
    due.sort((a, b) {
      final aDue = schedules[a.id]!.dueAt ?? now;
      final bDue = schedules[b.id]!.dueAt ?? now;
      return aDue.compareTo(bDue);
    });

    // New cards are introduced easiest-first so the ramp matches the roadmap.
    fresh.sort((a, b) {
      final byLevel = a.level.index.compareTo(b.level.index);
      return byLevel != 0 ? byLevel : a.id.compareTo(b.id);
    });

    final selectedDue = due.take(policy.maxCards).toList();
    final roomLeft = policy.maxCards - selectedDue.length;
    final selectedNew = fresh
        .take(roomLeft.clamp(0, policy.maxNewCards))
        .toList();

    return SessionPlan(
      questions: [...selectedDue, ...selectedNew],
      dueCount: selectedDue.length,
      newCount: selectedNew.length,
      totalDueAvailable: due.length,
    );
  }
}
