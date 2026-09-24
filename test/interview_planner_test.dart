import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:junior_to_senior/src/domain/interview_planner.dart';
import 'package:junior_to_senior/src/domain/models.dart';

void main() {
  // Real content, read straight from disk: the planner is only as good as
  // the tags the bank actually uses, so a synthetic fixture would hide drift.
  final catalog =
      ((jsonDecode(File('assets/content/index.json').readAsStringSync())
                  as Map<String, dynamic>)['technologies']
              as List<dynamic>)
          .map((raw) => TechnologySummary.fromJson(raw as Map<String, dynamic>))
          .toList();
  final contents = [
    for (final tech in catalog)
      TechnologyContent.fromJson(
        jsonDecode(File('assets/content/${tech.file}').readAsStringSync())
            as Map<String, dynamic>,
      ),
  ];
  const planner = InterviewPlanner();

  InterviewPlan plan(String posting, [SeniorityLevel? level]) => planner.plan(
    posting: posting,
    catalog: catalog,
    contents: contents,
    level: level ?? SeniorityLevel.senior,
  );

  test('detecta tecnologías y temas de una oferta real', () {
    final result = plan(
      'Desarrollador Móvil Senior – Flutter/Dart. BLoC, Clean Architecture, '
      'APIs REST, OWASP, CI/CD, biometría y push notifications.',
    );
    expect(result.technologies.map((tech) => tech.id), contains('flutter'));
    expect(result.technologies.map((tech) => tech.id), contains('dart'));
    expect(
      result.topics.map((topic) => topic.id),
      containsAll(['architecture', 'state', 'api', 'security', 'cicd']),
    );
  });

  test('lo que el banco no cubre sale como hueco, no desaparece', () {
    final result = plan('Flutter con biometría y notificaciones push');
    expect(
      result.gaps.map((topic) => topic.id),
      containsAll(['biometrics', 'push']),
    );
  });

  test('solo usa preguntas de las tecnologías que pide la oferta', () {
    final result = plan('Flutter, arquitectura y testing');
    final techs = {
      for (final section in result.sections)
        for (final question in section.questions) question.technologyId,
    };
    expect(techs, isNot(contains('javascript')));
    expect(techs, isNot(contains('typescript')));
  });

  test('una pregunta no se repite entre bloques', () {
    final result = plan('Senior Flutter Dart arquitectura estado testing');
    final ids = [
      for (final section in result.sections)
        for (final question in section.questions) question.id,
    ];
    expect(ids.toSet().length, ids.length);
  });

  test('prioriza el nivel pedido dentro de cada bloque', () {
    final result = plan(
      'Flutter Dart arquitectura estado testing',
      SeniorityLevel.junior,
    );
    for (final section in result.sections) {
      final levels = section.questions.map((q) => q.level.index).toList();
      expect(levels, orderedEquals([...levels]..sort()), reason: section.title);
    }
  });

  test('las coincidencias son de palabra completa', () {
    // «ci» vive dentro de «financiero»; no debe disparar CI/CD.
    final result = plan('Proyecto financiero con Flutter');
    expect(result.topics.map((topic) => topic.id), isNot(contains('cicd')));
    expect(result.topics.map((topic) => topic.id), contains('fintech'));
  });

  test('ignora tildes y mayúsculas', () {
    expect(fold('Biometría ÓPTIMA'), 'biometria optima');
    final result = plan('GESTIÓN DE ESTADO en flutter');
    expect(result.topics.map((topic) => topic.id), contains('state'));
  });

  test('detecta el nivel de la oferta', () {
    expect(planner.detectLevel('Buscamos Sr. Flutter'), SeniorityLevel.senior);
    expect(planner.detectLevel('Semi Senior React'), SeniorityLevel.mid);
    expect(planner.detectLevel('Flutter Jr'), SeniorityLevel.junior);
    expect(planner.detectLevel('Flutter'), isNull);
  });

  test('sin nada reconocible el plan queda vacío', () {
    expect(plan('cocinero con experiencia').isEmpty, isTrue);
  });

  test('el markdown incluye bloques, preguntas y huecos', () {
    final markdown = plan('Flutter arquitectura biometría').toMarkdown();
    expect(markdown, contains('## 1. Arquitectura y patrones'));
    expect(markdown, contains('**Sin cubrir por el banco:** Biometría'));
    expect(markdown, contains('### '));
  });
}
