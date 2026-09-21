/// Guards the content bank. Every technology listed in the index must parse
/// into the domain model, so a malformed contribution fails in CI instead of
/// on a user's phone.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:junior_to_senior/src/domain/models.dart';

void main() {
  final indexFile = File('assets/content/index.json');

  test('el índice existe y es JSON válido', () {
    expect(indexFile.existsSync(), isTrue);
  });

  final index =
      jsonDecode(indexFile.readAsStringSync()) as Map<String, dynamic>;
  final summaries = (index['technologies'] as List<dynamic>)
      .map((raw) => TechnologySummary.fromJson(raw as Map<String, dynamic>))
      .toList();

  test('los ids de tecnología son únicos', () {
    final ids = summaries.map((summary) => summary.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  for (final summary in summaries) {
    group(summary.name, () {
      late TechnologyContent content;

      setUpAll(() {
        final file = File('assets/content/${summary.file}');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'falta ${summary.file}, referenciado en el índice',
        );
        content = TechnologyContent.fromJson(
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        );
      });

      test('el id del fichero coincide con el del índice', () {
        expect(content.id, summary.id);
      });

      test('los contadores del índice coinciden con el contenido', () {
        expect(content.questions.length, summary.questionCount);
        expect(content.exercises.length, summary.exerciseCount);
      });

      test('los ids son únicos dentro de la tecnología', () {
        final questionIds = content.questions.map((q) => q.id).toList();
        expect(questionIds.toSet().length, questionIds.length);

        final exerciseIds = content.exercises.map((e) => e.id).toList();
        expect(exerciseIds.toSet().length, exerciseIds.length);

        final milestoneIds = [
          for (final stage in content.roadmap)
            for (final milestone in stage.milestones) milestone.id,
        ];
        expect(milestoneIds.toSet().length, milestoneIds.length);
      });

      test('ninguna pregunta tiene campos vacíos', () {
        for (final question in content.questions) {
          expect(question.prompt.trim(), isNotEmpty, reason: question.id);
          expect(question.answer.trim(), isNotEmpty, reason: question.id);
          expect(question.topic.trim(), isNotEmpty, reason: question.id);
          for (final level in SeniorityLevel.values) {
            expect(
              question.rubric.forLevel(level).trim(),
              isNotEmpty,
              reason: '${question.id} / ${level.name}',
            );
          }
        }
      });

      test('ningún ejercicio se queda sin razonamiento', () {
        for (final exercise in content.exercises) {
          expect(exercise.statement.trim(), isNotEmpty, reason: exercise.id);
          expect(exercise.approach.trim(), isNotEmpty, reason: exercise.id);
          expect(
            exercise.solutionSketch.trim(),
            isNotEmpty,
            reason: exercise.id,
          );
        }
      });

      test('la ruta cubre los tres niveles en orden', () {
        expect(content.roadmap, isNotEmpty);
        final levels = content.roadmap.map((stage) => stage.level).toList();
        expect(
          levels.toSet(),
          SeniorityLevel.values.toSet(),
          reason: 'la ruta debe llegar de junior a senior',
        );
        for (var i = 1; i < levels.length; i++) {
          expect(
            levels[i].index,
            greaterThanOrEqualTo(levels[i - 1].index),
            reason: 'las etapas deben ir en orden de seniority',
          );
        }
        for (final stage in content.roadmap) {
          expect(stage.milestones, isNotEmpty, reason: stage.id);
          expect(stage.estimatedWeeks, greaterThan(0), reason: stage.id);
        }
      });

      test('los recursos apuntan a URLs https', () {
        for (final stage in content.roadmap) {
          for (final resource in stage.resources) {
            expect(
              resource.url,
              startsWith('https://'),
              reason: '${stage.id}: ${resource.title}',
            );
          }
        }
      });
    });
  }
}
