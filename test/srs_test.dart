import 'package:flutter_test/flutter_test.dart';
import 'package:junior_to_senior/src/domain/srs.dart';

void main() {
  final now = DateTime(2026, 9, 20, 10, 30);

  group('SM-2 scheduling', () {
    test('a brand new card is due immediately', () {
      const schedule = ReviewSchedule();
      expect(schedule.isNew, isTrue);
      expect(schedule.isDue(now), isTrue);
    });

    test('first two passes use the fixed 1 and 6 day intervals', () {
      final first = const ReviewSchedule().review(ReviewGrade.solid, now: now);
      expect(first.repetitions, 1);
      expect(first.intervalDays, 1);
      expect(first.dueAt, DateTime(2026, 9, 21));

      final second = first.review(ReviewGrade.solid, now: now);
      expect(second.repetitions, 2);
      expect(second.intervalDays, 6);
      expect(second.dueAt, DateTime(2026, 9, 26));
    });

    test('from the third pass the interval is multiplied by easiness', () {
      var schedule = const ReviewSchedule();
      schedule = schedule.review(ReviewGrade.solid, now: now); // 1 day
      schedule = schedule.review(ReviewGrade.solid, now: now); // 6 days
      final easinessBefore = schedule.easiness;
      schedule = schedule.review(ReviewGrade.solid, now: now);

      expect(schedule.intervalDays, (6 * (easinessBefore + 0.1)).round());
      expect(schedule.repetitions, 3);
    });

    test('easiness rises on a solid answer and falls on a partial one', () {
      final solid = const ReviewSchedule().review(ReviewGrade.solid, now: now);
      expect(solid.easiness, greaterThan(ReviewSchedule.defaultEasiness));

      final partial = const ReviewSchedule().review(
        ReviewGrade.partial,
        now: now,
      );
      expect(partial.easiness, lessThan(ReviewSchedule.defaultEasiness));
    });

    test('a lapse resets the streak and requeues the card in this session', () {
      var schedule = const ReviewSchedule();
      schedule = schedule.review(ReviewGrade.solid, now: now);
      schedule = schedule.review(ReviewGrade.solid, now: now);
      expect(schedule.repetitions, 2);

      schedule = schedule.review(ReviewGrade.again, now: now);
      expect(schedule.repetitions, 0);
      expect(schedule.intervalDays, 0);
      expect(schedule.lapses, 1);
      expect(schedule.isDue(now), isTrue);
    });

    test('easiness never drops below the SM-2 floor of 1.3', () {
      var schedule = const ReviewSchedule();
      for (var i = 0; i < 30; i++) {
        schedule = schedule.review(ReviewGrade.again, now: now);
      }
      expect(schedule.easiness, ReviewSchedule.minimumEasiness);
    });

    test('totalReviews counts every answer, including lapses', () {
      var schedule = const ReviewSchedule();
      schedule = schedule.review(ReviewGrade.solid, now: now);
      schedule = schedule.review(ReviewGrade.again, now: now);
      schedule = schedule.review(ReviewGrade.partial, now: now);
      expect(schedule.totalReviews, 3);
    });
  });
}
