/// Runtime state of a practice session.
///
/// The session owns a mutable working queue: a card graded "no la supe" is
/// pushed back to the end of the queue instead of disappearing, so you never
/// finish a session still owing yourself an answer.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../../domain/srs.dart';
import '../../providers.dart';

class PracticeState {
  const PracticeState({
    required this.queue,
    required this.startedAt,
    required this.cardShownAt,
    required this.plannedCount,
    this.revealed = false,
    this.answered = 0,
    this.passed = 0,
    this.lapsed = 0,
    this.finished = false,
    this.lastSchedule,
  });

  /// Remaining cards. The head is the card on screen.
  final List<Question> queue;
  final DateTime startedAt;
  final DateTime cardShownAt;

  /// How many distinct cards the plan contained, for the progress bar. Cards
  /// requeued after a lapse do not inflate it.
  final int plannedCount;
  final bool revealed;

  /// Total gradings, including repeats of a lapsed card.
  final int answered;
  final int passed;
  final int lapsed;
  final bool finished;

  /// Scheduling result of the card just graded, so the UI can say
  /// "la vuelves a ver en 6 días".
  final ReviewSchedule? lastSchedule;

  Question? get current => queue.isEmpty ? null : queue.first;

  int get remaining => queue.length;

  double get progress {
    if (plannedCount == 0) return 1;
    final done = (plannedCount - _distinctRemaining()).clamp(0, plannedCount);
    return done / plannedCount;
  }

  int _distinctRemaining() => queue.map((q) => q.id).toSet().length;

  double get accuracy => answered == 0 ? 0 : passed / answered;

  Duration elapsed(DateTime now) => now.difference(startedAt);

  PracticeState copyWith({
    List<Question>? queue,
    DateTime? cardShownAt,
    bool? revealed,
    int? answered,
    int? passed,
    int? lapsed,
    bool? finished,
    ReviewSchedule? lastSchedule,
  }) {
    return PracticeState(
      queue: queue ?? this.queue,
      startedAt: startedAt,
      cardShownAt: cardShownAt ?? this.cardShownAt,
      plannedCount: plannedCount,
      revealed: revealed ?? this.revealed,
      answered: answered ?? this.answered,
      passed: passed ?? this.passed,
      lapsed: lapsed ?? this.lapsed,
      finished: finished ?? this.finished,
      lastSchedule: lastSchedule ?? this.lastSchedule,
    );
  }
}

class PracticeController extends Notifier<PracticeState?> {
  PracticeController(this.technologyId);

  final String technologyId;

  @override
  PracticeState? build() => null;

  /// Builds the queue from the current plan. Returns false when there is
  /// nothing due and nothing new, which the screen renders as "al día".
  bool start() {
    final plan = ref.read(sessionPlanProvider(technologyId)).value;
    if (plan == null || plan.isEmpty) return false;

    final now = ref.read(clockProvider)();
    state = PracticeState(
      queue: List.of(plan.questions),
      startedAt: now,
      cardShownAt: now,
      plannedCount: plan.questions.length,
    );
    return true;
  }

  void reveal() {
    final current = state;
    if (current == null || current.revealed) return;
    state = current.copyWith(revealed: true);
  }

  Future<void> grade(ReviewGrade grade) async {
    final current = state;
    final question = current?.current;
    if (current == null || question == null) return;

    final now = ref.read(clockProvider)();
    final schedule = await ref
        .read(progressRepositoryProvider)
        .recordReview(
          questionId: question.id,
          technologyId: technologyId,
          grade: grade,
          now: now,
          secondsSpent: now.difference(current.cardShownAt).inSeconds,
        );

    final queue = List.of(current.queue)..removeAt(0);
    if (!grade.isPass) {
      // Requeue a few cards later: far enough that it is a genuine recall
      // attempt, close enough that it happens in this session.
      final insertAt = queue.length < 3 ? queue.length : 3;
      queue.insert(insertAt, question);
    }

    state = current.copyWith(
      queue: queue,
      revealed: false,
      cardShownAt: now,
      answered: current.answered + 1,
      passed: current.passed + (grade.isPass ? 1 : 0),
      lapsed: current.lapsed + (grade.isPass ? 0 : 1),
      finished: queue.isEmpty,
      lastSchedule: schedule,
    );
  }

  /// Ends the session early, keeping everything already graded.
  void finish() {
    final current = state;
    if (current == null) return;
    state = current.copyWith(queue: const [], finished: true);
  }

  void reset() => state = null;
}

final practiceControllerProvider =
    NotifierProvider.family<PracticeController, PracticeState?, String>(
      PracticeController.new,
    );
