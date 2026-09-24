/// Turns a job posting into a study guide drawn from the curated bank.
///
/// Deliberately deterministic and offline: the posting is matched against a
/// hand-written vocabulary, never sent anywhere. The honest output matters as
/// much as the matches, so topics the posting asks for but the bank does not
/// cover are reported as gaps instead of being silently dropped.
library;

import 'models.dart';

/// A cross-cutting subject a posting may ask for ("Clean Architecture",
/// "CI/CD"), independent of the language or framework.
class StackTopic {
  const StackTopic({
    required this.id,
    required this.label,
    required this.aliases,
    this.tags = const {},
  });

  final String id;
  final String label;

  /// How postings spell it. Matched on whole words, accent-insensitive.
  final List<String> aliases;

  /// Question tags or topics that cover it. Empty means the bank has nothing
  /// for it yet, so it can only ever show up as a gap.
  final Set<String> tags;
}

/// The vocabulary. Order matters: a question lands in the first section that
/// claims it, so the more specific topics go first.
const stackTopics = <StackTopic>[
  StackTopic(
    id: 'architecture',
    label: 'Arquitectura y patrones',
    aliases: [
      'clean architecture',
      'arquitectura',
      'architecture',
      'solid',
      'patrones de diseno',
      'design patterns',
      'ddd',
      'hexagonal',
      'mvvm',
      'mvc',
      'repository',
      'modular',
    ],
    tags: {'arquitectura', 'capas', 'modularizacion', 'patrones', 'diseno'},
  ),
  StackTopic(
    id: 'state',
    label: 'Gestión de estado',
    aliases: [
      'bloc',
      'cubit',
      'riverpod',
      'provider',
      'redux',
      'mobx',
      'getx',
      'gestion de estado',
      'state management',
    ],
    tags: {'estado', 'state', 'provider', 'riverpod', 'gestion de estado'},
  ),
  StackTopic(
    id: 'async',
    label: 'Asincronía y concurrencia',
    aliases: [
      'async',
      'asincronia',
      'streams',
      'futures',
      'promises',
      'promesas',
      'concurrencia',
      'isolates',
      'rxdart',
    ],
    tags: {
      'async',
      'async await',
      'futures',
      'future',
      'streams',
      'event loop',
      'isolates',
      'promesas',
      'asincronia',
      'concurrencia',
    },
  ),
  StackTopic(
    id: 'api',
    label: 'APIs e integración',
    aliases: [
      'api',
      'apis',
      'rest',
      'restful',
      'graphql',
      'http',
      'dio',
      'json',
      'microservicios',
      'websockets',
    ],
    tags: {'api', 'fetch', 'json', 'serializacion', 'contratos'},
  ),
  StackTopic(
    id: 'persistence',
    label: 'Persistencia y offline',
    aliases: [
      'sqlite',
      'offline',
      'offline first',
      'persistencia',
      'base de datos',
      'bases de datos',
      'hive',
      'drift',
      'isar',
      'realm',
      'cache',
    ],
    tags: {
      'persistencia',
      'offline',
      'base de datos',
      'sincronizacion',
      'almacenamiento',
    },
  ),
  StackTopic(
    id: 'testing',
    label: 'Testing y calidad',
    aliases: [
      'testing',
      'tests',
      'test',
      'tdd',
      'pruebas',
      'pruebas unitarias',
      'unit test',
      'unit testing',
      'integration test',
      'calidad',
      'code quality',
    ],
    tags: {'testing', 'widget test', 'calidad', 'lint'},
  ),
  StackTopic(
    id: 'security',
    label: 'Seguridad',
    aliases: [
      'owasp',
      'seguridad',
      'security',
      'cifrado',
      'encryption',
      'ssl pinning',
      'certificate pinning',
      'oauth',
      'jwt',
      'autenticacion',
    ],
    tags: {'seguridad', 'xss', 'auth', 'supply chain'},
  ),
  StackTopic(
    id: 'performance',
    label: 'Rendimiento',
    aliases: [
      'rendimiento',
      'performance',
      'optimizacion',
      'optimization',
      'profiling',
    ],
    tags: {
      'rendimiento',
      'optimizacion',
      'memoria',
      'jank',
      'rebuilds',
      'repaint',
      'perfilado',
    },
  ),
  StackTopic(
    id: 'cicd',
    label: 'CI/CD y despliegue',
    aliases: [
      'ci/cd',
      'ci',
      'cd',
      'pipeline',
      'pipelines',
      'github actions',
      'gitlab ci',
      'fastlane',
      'codemagic',
      'bitrise',
      'devops',
      'jenkins',
    ],
    tags: {'ci', 'devops', 'build y despliegue'},
  ),
  StackTopic(
    id: 'stores',
    label: 'Publicación en tiendas',
    aliases: [
      'app store',
      'google play',
      'play store',
      'huawei',
      'appgallery',
      'testflight',
      'publicacion',
    ],
    tags: {'release', 'build y despliegue'},
  ),
  StackTopic(
    id: 'native',
    label: 'Plataforma nativa',
    aliases: [
      'ios',
      'android',
      'nativo',
      'native',
      'kotlin',
      'swift',
      'platform channels',
      'method channel',
    ],
    tags: {'nativo', 'platform channels', 'plataforma', 'ffi'},
  ),
  StackTopic(
    id: 'navigation',
    label: 'Navegación',
    aliases: ['navegacion', 'navigation', 'deep links', 'deeplinks', 'router'],
    tags: {'navegacion', 'rutas', 'deep links'},
  ),
  StackTopic(
    id: 'accessibility',
    label: 'Accesibilidad',
    aliases: ['accesibilidad', 'accessibility', 'a11y', 'wcag'],
    tags: {'accesibilidad'},
  ),
  StackTopic(
    id: 'observability',
    label: 'Errores y observabilidad',
    aliases: [
      'crashlytics',
      'sentry',
      'monitoreo',
      'monitoring',
      'observabilidad',
      'logging',
    ],
    tags: {'observabilidad', 'errores', 'incidentes', 'depuracion'},
  ),
  StackTopic(
    id: 'leadership',
    label: 'Liderazgo técnico',
    aliases: [
      'liderazgo',
      'lider tecnico',
      'tech lead',
      'mentoria',
      'mentoring',
      'code review',
      'revision de codigo',
      'scrum',
      'agile',
    ],
    tags: {'liderazgo', 'mentoria', 'equipo', 'revision', 'decisiones'},
  ),
  StackTopic(
    id: 'biometrics',
    label: 'Biometría',
    aliases: [
      'biometria',
      'biometrico',
      'biometrics',
      'face id',
      'touch id',
      'huella',
      'local auth',
    ],
  ),
  StackTopic(
    id: 'push',
    label: 'Notificaciones push',
    aliases: [
      'push',
      'push notifications',
      'notificaciones push',
      'notificaciones',
      'fcm',
      'firebase messaging',
      'apns',
    ],
  ),
  StackTopic(
    id: 'fintech',
    label: 'Dominio financiero',
    aliases: [
      'fintech',
      'financiero',
      'bancario',
      'banca',
      'banking',
      'pagos',
      'payments',
      'pci',
    ],
  ),
];

/// One block of the guide, in the order it should be studied.
class InterviewSection {
  const InterviewSection({
    required this.title,
    required this.reason,
    required this.questions,
  });

  final String title;

  /// Why this block is here, in the user's terms ("la oferta menciona bloc").
  final String reason;
  final List<Question> questions;
}

class InterviewPlan {
  const InterviewPlan({
    required this.level,
    required this.technologies,
    required this.topics,
    required this.sections,
    required this.gaps,
  });

  final SeniorityLevel level;
  final List<TechnologySummary> technologies;
  final List<StackTopic> topics;
  final List<InterviewSection> sections;

  /// Asked for by the posting, absent from the bank.
  final List<StackTopic> gaps;

  int get questionCount =>
      sections.fold(0, (total, section) => total + section.questions.length);

  bool get isEmpty => technologies.isEmpty && topics.isEmpty;

  /// Same shape as a hand-written prep guide, so it can be pasted into notes.
  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Guía de entrevista (${level.label})')
      ..writeln();
    if (technologies.isNotEmpty) {
      buffer.writeln(
        '**Stack:** ${technologies.map((tech) => tech.name).join(', ')}',
      );
    }
    if (topics.isNotEmpty) {
      buffer.writeln(
        '**Temas:** ${topics.map((topic) => topic.label).join(', ')}',
      );
    }
    if (gaps.isNotEmpty) {
      buffer.writeln(
        '**Sin cubrir por el banco:** '
        '${gaps.map((topic) => topic.label).join(', ')}',
      );
    }
    for (final (index, section) in sections.indexed) {
      buffer
        ..writeln()
        ..writeln('## ${index + 1}. ${section.title}')
        ..writeln()
        ..writeln('_${section.reason}_');
      for (final question in section.questions) {
        buffer
          ..writeln()
          ..writeln('### ${question.prompt}')
          ..writeln()
          ..writeln(question.answer.trim())
          ..writeln()
          ..writeln(
            '> **Respuesta ${level.label}:** ${question.rubric.forLevel(level)}',
          );
        if (question.followUps.isNotEmpty) {
          buffer.writeln();
          for (final followUp in question.followUps) {
            buffer.writeln('- $followUp');
          }
        }
      }
    }
    return buffer.toString();
  }
}

class InterviewPlanner {
  const InterviewPlanner({
    this.maxPerTopic = 6,
    this.maxPerTechnology = 6,
    this.vocabulary = stackTopics,
  });

  final int maxPerTopic;

  /// Size of the "core of a technology" block that follows the topic blocks.
  final int maxPerTechnology;
  final List<StackTopic> vocabulary;

  /// Seniority the posting asks for, if it says so. Senior wins over junior
  /// because postings list the target level alongside the ones below it.
  SeniorityLevel? detectLevel(String posting) {
    final text = fold(posting);
    bool has(List<String> words) => words.any((word) => _contains(text, word));
    // Checked before senior: "semi senior" contains "senior".
    if (has(['semi senior', 'semisenior', 'ssr'])) return SeniorityLevel.mid;
    if (has(['senior', 'sr', 'lead', 'staff', 'principal'])) {
      return SeniorityLevel.senior;
    }
    if (has(['mid', 'mid level'])) return SeniorityLevel.mid;
    if (has(['junior', 'jr', 'trainee', 'practicante'])) {
      return SeniorityLevel.junior;
    }
    return null;
  }

  InterviewPlan plan({
    required String posting,
    required List<TechnologySummary> catalog,
    required List<TechnologyContent> contents,
    required SeniorityLevel level,
  }) {
    final text = fold(posting);

    final technologies = catalog
        .where(
          (tech) => [
            tech.name,
            ...tech.keywords,
          ].any((word) => _contains(text, fold(word))),
        )
        .toList(growable: false);
    final topics = vocabulary
        .where((topic) => topic.aliases.any((alias) => _contains(text, alias)))
        .toList(growable: false);

    // With no technology named, every technology is fair game; otherwise a
    // Flutter posting would get JavaScript answers about architecture.
    final ids = technologies.isEmpty
        ? contents.map((content) => content.id).toSet()
        : technologies.map((tech) => tech.id).toSet();
    final pool = [
      for (final content in contents)
        if (ids.contains(content.id)) ...content.questions,
    ]..sort((a, b) => _levelDistance(a, level) - _levelDistance(b, level));

    final used = <String>{};
    final sections = <InterviewSection>[];
    final gaps = <StackTopic>[];

    for (final topic in topics) {
      final covering = pool.where((question) => _covers(topic, question));
      if (covering.isEmpty) {
        gaps.add(topic);
        continue;
      }
      final picked = covering
          .where((question) => !used.contains(question.id))
          .take(maxPerTopic)
          .toList(growable: false);
      // Covered, but every matching question already sits in an earlier block.
      if (picked.isEmpty) continue;
      used.addAll(picked.map((question) => question.id));
      final mentioned = topic.aliases
          .where((alias) => _contains(text, alias))
          .take(3);
      sections.add(
        InterviewSection(
          title: topic.label,
          reason: 'La oferta menciona: ${mentioned.join(', ')}',
          questions: picked,
        ),
      );
    }

    for (final tech in technologies) {
      final picked = pool
          .where(
            (question) =>
                question.technologyId == tech.id && !used.contains(question.id),
          )
          .take(maxPerTechnology)
          .toList(growable: false);
      if (picked.isEmpty) continue;
      used.addAll(picked.map((question) => question.id));
      sections.add(
        InterviewSection(
          title: 'Núcleo de ${tech.name}',
          reason: 'Lo que se pregunta de ${tech.name} a nivel ${level.label}',
          questions: picked,
        ),
      );
    }

    return InterviewPlan(
      level: level,
      technologies: technologies,
      topics: topics,
      sections: sections,
      gaps: gaps,
    );
  }

  bool _covers(StackTopic topic, Question question) =>
      topic.tags.contains(fold(question.topic)) ||
      question.tags.any((tag) => topic.tags.contains(fold(tag)));

  /// Target level first, then the one below (the base a senior is expected
  /// to explain), then the rest.
  static int _levelDistance(Question question, SeniorityLevel target) {
    final diff = target.index - question.level.index;
    return diff >= 0 ? diff * 2 : -diff * 2 + 1;
  }

  /// Whole-word match, so "ci" does not fire inside "financiero".
  static bool _contains(String text, String word) =>
      RegExp('(?<![a-z0-9])${RegExp.escape(word)}(?![a-z0-9])').hasMatch(text);
}

/// Lowercase without accents: postings are written both ways.
String fold(String input) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñ';
  const to = 'aaaaeeeeiiiioooouuuun';
  final buffer = StringBuffer();
  for (final char in input.toLowerCase().split('')) {
    final index = from.indexOf(char);
    buffer.write(index < 0 ? char : to[index]);
  }
  return buffer.toString();
}
