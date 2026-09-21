import 'package:intl/intl.dart';

/// Human-friendly "when will I see this again" copy for the practice screen.
String formatNextReview(DateTime? dueAt, {DateTime? now}) {
  if (dueAt == null) return 'hoy';
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final target = DateTime(dueAt.year, dueAt.month, dueAt.day);
  final days = target.difference(today).inDays;

  return switch (days) {
    <= 0 => 'hoy',
    1 => 'mañana',
    < 7 => 'en $days días',
    < 30 => 'en ${(days / 7).round()} sem.',
    < 365 => 'en ${(days / 30).round()} meses',
    _ => 'en ${(days / 365).toStringAsFixed(1)} años',
  };
}

String formatDay(DateTime day) => DateFormat('d MMM', 'es').format(day);

String formatWeeks(int weeks) {
  if (weeks < 4) return '$weeks semanas';
  final months = (weeks / 4.345).round();
  return months == 1 ? '~1 mes' : '~$months meses';
}
