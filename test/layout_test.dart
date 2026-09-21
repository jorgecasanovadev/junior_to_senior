/// Layout regression tests.
///
/// Flutter reports an overflow as a FlutterError, which fails the test
/// automatically. So simply rendering every tab at real phone sizes is enough
/// to catch "BOTTOM OVERFLOWED BY N PIXELS" before a user sees the stripes.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junior_to_senior/src/data/content_repository.dart';
import 'package:junior_to_senior/src/data/database.dart';
import 'package:junior_to_senior/src/features/technology/exercises_tab.dart';
import 'package:junior_to_senior/src/features/technology/questions_tab.dart';
import 'package:junior_to_senior/src/features/technology/roadmap_tab.dart';
import 'package:junior_to_senior/src/features/technology/technology_screen.dart';
import 'package:junior_to_senior/src/providers.dart';

class DiskAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(key).readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

/// Logical sizes of the phones the app has to survive, smallest first.
const _sizes = <String, Size>{
  'iPhone SE': Size(320, 568),
  'iPhone 16 Pro': Size(393, 852),
  'Pixel 7': Size(412, 915),
};

Future<void> pumpAt(WidgetTester tester, Size size, Widget child) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final content = ContentRepository(bundle: DiskAssetBundle());
  await tester.runAsync(() async {
    for (final technology in await content.technologies()) {
      await content.load(technology.id);
    }
  });

  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        contentRepositoryProvider.overrideWithValue(content),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 10));
  await db.close();
}

void main() {
  for (final entry in _sizes.entries) {
    group('En ${entry.key} (${entry.value.width.toInt()} px de ancho)', () {
      for (final technologyId in ['flutter', 'dart']) {
        testWidgets('la ruta de $technologyId no desborda', (tester) async {
          await pumpAt(
            tester,
            entry.value,
            RoadmapTab(technologyId: technologyId),
          );
        });

        testWidgets('las preguntas de $technologyId no desbordan', (
          tester,
        ) async {
          await pumpAt(
            tester,
            entry.value,
            QuestionsTab(technologyId: technologyId),
          );
        });

        testWidgets('los ejercicios de $technologyId no desbordan', (
          tester,
        ) async {
          await pumpAt(
            tester,
            entry.value,
            ExercisesTab(technologyId: technologyId),
          );
        });
      }

      testWidgets('la pantalla de tecnología completa no desborda', (
        tester,
      ) async {
        await pumpAt(
          tester,
          entry.value,
          const TechnologyScreen(technologyId: 'flutter'),
        );
      });
    });
  }
}
