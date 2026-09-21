/// Spaced repetition scheduling (SM-2).
///
/// SM-2 is the algorithm behind SuperMemo and, in spirit, Anki. It is simple,
/// well understood, and it only needs three numbers per card, which keeps the
/// local database tiny and makes the whole feature work offline.
///
/// Reference: P. A. Wozniak, "Optimization of learning" (1990).
library;

import 'dart:math' as math;

/// How well the user judged their own answer. Classic SM-2 uses a 0-5 quality
/// scale; we expose three honest buttons and map them onto it, because asking
/// someone to grade themselves on six levels produces noise, not signal.
enum ReviewGrade {
  /// "No la supe." Quality 1 -> the card lapses and comes back today.
  again('No la supe', 1),

  /// "A medias." Quality 3 -> the lowest passing grade; interval grows slowly.
  partial('A medias', 3),

  /// "La clavé." Quality 5 -> full credit, easiness factor increases.
  solid('La clavé', 5);

  const ReviewGrade(this.label, this.quality);

  final String label;
  final int quality;

  bool get isPass => quality >= 3;
}

/// The scheduling state of a single question. Defaults describe a card that
/// has never been reviewed.
class ReviewSchedule {
  const ReviewSchedule({
    this.easiness = defaultEasiness,
    this.repetitions = 0,
    this.intervalDays = 0,
    this.dueAt,
    this.lapses = 0,
    this.totalReviews = 0,
  });

  /// SM-2 starts every card at 2.5 and never lets it drop below 1.3.
  static const double defaultEasiness = 2.5;
  static const double minimumEasiness = 1.3;

  final double easiness;

  /// Consecutive successful reviews. Reset to 0 on a lapse.
  final int repetitions;
  final int intervalDays;
  final DateTime? dueAt;
  final int lapses;
  final int totalReviews;

  bool get isNew => totalReviews == 0;

  bool isDue(DateTime now) => dueAt == null || !dueAt!.isAfter(now);

  /// Applies one review and returns the next state.
  ///
  /// [now] is injected so the scheduler stays pure and testable.
  ReviewSchedule review(ReviewGrade grade, {required DateTime now}) {
    final quality = grade.quality;

    // Easiness moves on every review, pass or fail, using the SM-2 curve.
    final adjusted =
        easiness + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    final nextEasiness = math.max(minimumEasiness, adjusted);

    if (!grade.isPass) {
      // A lapse resets the streak. The card is shown again in the same
      // session rather than tomorrow: the user explicitly said they did not
      // know it, so there is nothing to consolidate by waiting.
      return ReviewSchedule(
        easiness: nextEasiness,
        repetitions: 0,
        intervalDays: 0,
        dueAt: now,
        lapses: lapses + 1,
        totalReviews: totalReviews + 1,
      );
    }

    final nextRepetitions = repetitions + 1;
    final nextInterval = switch (nextRepetitions) {
      1 => 1,
      2 => 6,
      _ => math.max(1, (intervalDays * nextEasiness).round()),
    };

    return ReviewSchedule(
      easiness: nextEasiness,
      repetitions: nextRepetitions,
      intervalDays: nextInterval,
      dueAt: _startOfDay(now).add(Duration(days: nextInterval)),
      lapses: lapses,
      totalReviews: totalReviews + 1,
    );
  }

  /// Due dates are day-granular: a card scheduled for tomorrow should be
  /// available first thing tomorrow, not 24 hours after the last review.
  static DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  ReviewSchedule copyWith({
    double? easiness,
    int? repetitions,
    int? intervalDays,
    DateTime? dueAt,
    int? lapses,
    int? totalReviews,
  }) {
    return ReviewSchedule(
      easiness: easiness ?? this.easiness,
      repetitions: repetitions ?? this.repetitions,
      intervalDays: intervalDays ?? this.intervalDays,
      dueAt: dueAt ?? this.dueAt,
      lapses: lapses ?? this.lapses,
      totalReviews: totalReviews ?? this.totalReviews,
    );
  }
}
