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
import 'package:junior_to_senior/src/features/interview/interview_screen.dart';
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

/// Height of the first line of a Text, to compare against a marker's centre.
double _alturaDeLinea(WidgetTester tester, String textoParcial) {
  final widget = tester.widget<Text>(find.textContaining(textoParcial).first);
  final estilo = widget.style;
  return (estilo?.fontSize ?? 14) * (estilo?.height ?? 1.35);
}

Future<void> pumpAt(
  WidgetTester tester,
  Size size,
  Widget child, {

  /// Runs while the tree is still mounted, for tests that inspect geometry.
  Future<void> Function(WidgetTester tester)? inspect,
}) async {
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

  if (inspect != null) await inspect(tester);

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 10));
  await db.close();
}

void main() {
  group('Timeline de la ruta', () {
    testWidgets('los marcadores se numeran 1, 2, 3, 4 por etapa', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const Size(393, 852),
        const RoadmapTab(technologyId: 'flutter'),
        inspect: (tester) async {
          // No el índice del nivel: varias etapas comparten nivel y los
          // marcadores llegaron a leerse 1, 1, 2, 3.
          //
          // Las tarjetas son altas, así que hay que recorrer la lista: con
          // el bug, buscar el 4 no encontraba nada y el test falla aquí.
          for (final numero in ['1', '2', '3', '4']) {
            await tester.scrollUntilVisible(
              find.text(numero),
              300,
              scrollable: find.byType(Scrollable).first,
            );
            expect(
              find.text(numero),
              findsOneWidget,
              reason: 'falta el marcador $numero en el timeline',
            );
          }
        },
      );
    });

    testWidgets('solo se abre la etapa en curso', (tester) async {
      await pumpAt(
        tester,
        const Size(393, 852),
        const RoadmapTab(technologyId: 'flutter'),
        inspect: (tester) async {
          // La lista solo construye lo visible, y la tarjeta abierta mide
          // ~2000 px, así que se comprueba cada etapa por su key.
          bool abierta(String stageId) => tester
              .widget<ExpansionTile>(find.byKey(PageStorageKey(stageId)))
              .initiallyExpanded;

          // Sin progreso, la etapa en curso es la primera.
          expect(abierta('flutter-s1'), isTrue);

          for (final stageId in ['flutter-s2', 'flutter-s3', 'flutter-s4']) {
            await tester.scrollUntilVisible(
              find.byKey(PageStorageKey(stageId)),
              300,
              scrollable: find.byType(Scrollable).first,
            );
            expect(
              abierta(stageId),
              isFalse,
              reason: '$stageId no debería abrirse sola',
            );
          }
        },
      );
    });

    testWidgets('el marcador se alinea con la primera línea del título', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const Size(393, 852),
        const RoadmapTab(technologyId: 'flutter'),
        inspect: (tester) async {
          final marcador = tester.getRect(find.text('1'));
          final titulo = tester.getRect(find.textContaining('Etapa 1').first);

          // El título puede ocupar dos líneas; comparamos con la primera.
          final centroMarcador = marcador.center.dy;
          final centroPrimeraLinea =
              titulo.top + _alturaDeLinea(tester, 'Etapa 1') / 2;

          expect(
            (centroMarcador - centroPrimeraLinea).abs(),
            lessThan(1.5),
            reason:
                'marcador en $centroMarcador, primera línea del título en '
                '$centroPrimeraLinea',
          );
        },
      );
    });
  });

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

      testWidgets('la guía de entrevista no desborda', (tester) async {
        await pumpAt(
          tester,
          entry.value,
          const InterviewScreen(
            initialPosting:
                'Desarrollador Móvil Senior – Flutter/Dart. BLoC, Clean '
                'Architecture, APIs REST, OWASP, CI/CD, biometría, push.',
          ),
        );
      });

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
