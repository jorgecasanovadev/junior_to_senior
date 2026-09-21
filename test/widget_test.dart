/// Smoke tests of the main flows, wired against an in-memory database so
/// nothing touches the real device storage.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junior_to_senior/src/data/content_repository.dart';
import 'package:junior_to_senior/src/data/database.dart';
import 'package:junior_to_senior/src/domain/models.dart';
import 'package:junior_to_senior/src/data/progress_repository.dart';
import 'package:junior_to_senior/src/domain/session_planner.dart';
import 'package:junior_to_senior/src/domain/srs.dart';
import 'package:junior_to_senior/src/features/home/home_screen.dart';
import 'package:junior_to_senior/src/providers.dart';

/// Serves the real content files from disk.
///
/// Widget tests use this instead of [rootBundle] so they exercise the same
/// JSON that ships with the app without depending on how the test runner
/// assembles the asset bundle.
class DiskAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(key).readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

/// Mounts [child] with an in-memory database, runs [body], then tears the
/// tree down.
///
/// The teardown is part of the body on purpose. Disposing the ProviderScope
/// cancels drift's query streams, and drift schedules a zero-duration timer
/// to close them; if that timer is still pending when the test ends, the
/// framework fails with "Pending timers". Unmounting here and advancing the
/// clock lets it fire while we still control the ordering.
Future<void> withApp(
  WidgetTester tester,
  Widget child,
  Future<void> Function() body,
) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());

  // Warm the repository before mounting, for two reasons.
  //
  // First, the body of a widget test runs inside FakeAsync, where real file
  // I/O never completes: awaiting it there hangs until pumpAndSettle gives
  // up ten minutes later. tester.runAsync steps outside that zone.
  //
  // Second, with the content already cached the first frame has data, so no
  // indeterminate CircularProgressIndicator is on screen -- pumpAndSettle
  // never settles while one is animating.
  final content = ContentRepository(bundle: DiskAssetBundle());
  await tester.runAsync(() async {
    for (final technology in await content.technologies()) {
      await content.load(technology.id);
    }
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        contentRepositoryProvider.overrideWithValue(content),
      ],
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();

  await body();

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 10));
  await db.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Búsqueda de tecnologías', () {
    testWidgets('lista todas las tecnologías al abrir', (tester) async {
      await withApp(tester, const HomeScreen(), () async {
        expect(find.text('Flutter'), findsOneWidget);
        expect(find.text('Dart'), findsOneWidget);
      });
    });

    testWidgets('filtra por nombre y por palabra clave', (tester) async {
      await withApp(tester, const HomeScreen(), () async {
        await tester.enterText(find.byType(TextField), 'dartlang');
        await tester.pumpAndSettle();

        // "dartlang" es una keyword de Dart, no aparece en su nombre.
        expect(find.text('Dart'), findsOneWidget);
        expect(find.text('Flutter'), findsNothing);
      });
    });

    testWidgets('muestra un mensaje cuando no hay resultados', (tester) async {
      await withApp(tester, const HomeScreen(), () async {
        await tester.enterText(find.byType(TextField), 'cobol');
        await tester.pumpAndSettle();

        expect(find.text('Sin resultados'), findsOneWidget);
      });
    });
  });

  group('Persistencia del progreso', () {
    test('un repaso se guarda y se recupera con su programación', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = ProgressRepository(db);

      final now = DateTime(2026, 9, 21, 9);
      await repository.recordReview(
        questionId: 'flutter-q001',
        technologyId: 'flutter',
        grade: ReviewGrade.solid,
        now: now,
      );

      final schedules = await repository.schedulesFor('flutter');
      expect(schedules, hasLength(1));
      expect(schedules['flutter-q001']!.repetitions, 1);
      expect(schedules['flutter-q001']!.intervalDays, 1);
      expect(schedules['flutter-q001']!.dueAt, DateTime(2026, 9, 22));
    });

    test('la actividad diaria se acumula en la misma fila', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = ProgressRepository(db);

      final now = DateTime(2026, 9, 21, 9);
      for (final id in ['q1', 'q2', 'q3']) {
        await repository.recordReview(
          questionId: id,
          technologyId: 'flutter',
          grade: id == 'q3' ? ReviewGrade.again : ReviewGrade.solid,
          now: now,
          secondsSpent: 10,
        );
      }

      final activity = await repository.watchActivity().first;
      expect(activity, hasLength(1));
      expect(activity.single.reviewed, 3);
      expect(activity.single.passed, 2);
      expect(activity.single.secondsSpent, 30);
    });

    test('reiniciar una tecnología no toca a las demás', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = ProgressRepository(db);

      final now = DateTime(2026, 9, 21);
      await repository.recordReview(
        questionId: 'f1',
        technologyId: 'flutter',
        grade: ReviewGrade.solid,
        now: now,
      );
      await repository.recordReview(
        questionId: 'd1',
        technologyId: 'dart',
        grade: ReviewGrade.solid,
        now: now,
      );

      await repository.resetTechnology('flutter');

      expect(await repository.schedulesFor('flutter'), isEmpty);
      expect(await repository.schedulesFor('dart'), hasLength(1));
    });
  });

  group('Planificación de la sesión', () {
    final pool = [
      for (var i = 0; i < 10; i++)
        Question(
          id: 'q$i',
          technologyId: 't',
          level: SeniorityLevel.values[i % 3],
          topic: 'Tema ${i % 2}',
          prompt: 'Pregunta $i',
          answer: 'Respuesta',
          rubric: const AnswerRubric(junior: 'a', mid: 'b', senior: 'c'),
          followUps: const [],
          tags: const [],
        ),
    ];

    test('respeta el tope de preguntas nuevas', () {
      final plan = const SessionPlanner().plan(
        pool: pool,
        schedules: const {},
        now: DateTime(2026, 9, 21),
        policy: const SessionPolicy(maxCards: 20, maxNewCards: 3),
      );

      expect(plan.questions, hasLength(3));
      expect(plan.newCount, 3);
      expect(plan.dueCount, 0);
    });

    test('los repasos vencidos van antes que las preguntas nuevas', () {
      final now = DateTime(2026, 9, 21);
      final schedules = {
        'q7': ReviewSchedule(
          repetitions: 2,
          intervalDays: 6,
          totalReviews: 2,
          dueAt: now.subtract(const Duration(days: 3)),
        ),
      };

      final plan = const SessionPlanner().plan(
        pool: pool,
        schedules: schedules,
        now: now,
        policy: const SessionPolicy(maxCards: 5, maxNewCards: 2),
      );

      expect(plan.questions.first.id, 'q7');
      expect(plan.dueCount, 1);
      expect(plan.newCount, 2);
    });

    test('filtra por nivel', () {
      final plan = const SessionPlanner().plan(
        pool: pool,
        schedules: const {},
        now: DateTime(2026, 9, 21),
        policy: const SessionPolicy(
          maxCards: 20,
          maxNewCards: 20,
          levels: {SeniorityLevel.senior},
        ),
      );

      expect(plan.questions, isNotEmpty);
      expect(
        plan.questions.every((q) => q.level == SeniorityLevel.senior),
        isTrue,
      );
    });
  });
}
