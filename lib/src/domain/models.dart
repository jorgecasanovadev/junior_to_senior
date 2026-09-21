/// Immutable domain model for the curated content shipped in `assets/content/`.
///
/// The JSON is authored by hand (and reviewed through pull requests), so the
/// parsers here are deliberately strict: a malformed field should fail loudly
/// during development rather than silently produce an empty screen.
library;

enum SeniorityLevel {
  junior('Junior'),
  mid('Mid'),
  senior('Senior');

  const SeniorityLevel(this.label);

  final String label;

  static SeniorityLevel parse(String raw) => SeniorityLevel.values.firstWhere(
    (level) => level.name == raw,
    orElse: () => throw FormatException('Unknown seniority level: $raw'),
  );
}

enum Difficulty {
  easy('Fácil'),
  medium('Media'),
  hard('Difícil');

  const Difficulty(this.label);

  final String label;

  static Difficulty parse(String raw) => Difficulty.values.firstWhere(
    (difficulty) => difficulty.name == raw,
    orElse: () => throw FormatException('Unknown difficulty: $raw'),
  );
}

enum ResourceKind {
  docs('Documentación'),
  article('Artículo'),
  video('Vídeo'),
  book('Libro'),
  course('Curso'),
  repo('Repositorio');

  const ResourceKind(this.label);

  final String label;

  static ResourceKind parse(String raw) => ResourceKind.values.firstWhere(
    (kind) => kind.name == raw,
    orElse: () => ResourceKind.article,
  );
}

/// Lightweight descriptor listed in `index.json`, enough to render the search
/// results without loading the (much larger) per-technology payload.
class TechnologySummary {
  const TechnologySummary({
    required this.id,
    required this.name,
    required this.tagline,
    required this.category,
    required this.keywords,
    required this.seedColor,
    required this.questionCount,
    required this.exerciseCount,
    required this.file,
  });

  factory TechnologySummary.fromJson(Map<String, dynamic> json) {
    return TechnologySummary(
      id: json['id'] as String,
      name: json['name'] as String,
      tagline: json['tagline'] as String,
      category: json['category'] as String,
      keywords: (json['keywords'] as List<dynamic>).cast<String>(),
      seedColor: int.parse(json['seedColor'] as String),
      questionCount: json['questionCount'] as int,
      exerciseCount: json['exerciseCount'] as int,
      file: json['file'] as String,
    );
  }

  final String id;
  final String name;
  final String tagline;
  final String category;

  /// Alternate spellings people actually type ("js", "reactjs", "dotnet").
  final List<String> keywords;
  final int seedColor;
  final int questionCount;
  final int exerciseCount;

  /// File name inside `assets/content/`, relative to the index.
  final String file;

  /// Score for the search box. Higher is better, 0 means "no match".
  int matchScore(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return 1;
    final haystack = name.toLowerCase();
    if (haystack == needle) return 100;
    if (keywords.any((keyword) => keyword.toLowerCase() == needle)) return 90;
    if (haystack.startsWith(needle)) return 80;
    if (keywords.any((keyword) => keyword.toLowerCase().startsWith(needle))) {
      return 70;
    }
    if (haystack.contains(needle)) return 50;
    if (category.toLowerCase().contains(needle)) return 30;
    if (tagline.toLowerCase().contains(needle)) return 20;
    return 0;
  }
}

/// What a convincing answer sounds like at each seniority level. This is the
/// feature that turns a question bank into a calibration tool.
class AnswerRubric {
  const AnswerRubric({
    required this.junior,
    required this.mid,
    required this.senior,
  });

  factory AnswerRubric.fromJson(Map<String, dynamic> json) {
    return AnswerRubric(
      junior: json['junior'] as String,
      mid: json['mid'] as String,
      senior: json['senior'] as String,
    );
  }

  final String junior;
  final String mid;
  final String senior;

  String forLevel(SeniorityLevel level) => switch (level) {
    SeniorityLevel.junior => junior,
    SeniorityLevel.mid => mid,
    SeniorityLevel.senior => senior,
  };
}

class Question {
  const Question({
    required this.id,
    required this.technologyId,
    required this.level,
    required this.topic,
    required this.prompt,
    required this.answer,
    required this.rubric,
    required this.followUps,
    required this.tags,
  });

  factory Question.fromJson(Map<String, dynamic> json, String technologyId) {
    return Question(
      id: json['id'] as String,
      technologyId: technologyId,
      level: SeniorityLevel.parse(json['level'] as String),
      topic: json['topic'] as String,
      prompt: json['prompt'] as String,
      answer: json['answer'] as String,
      rubric: AnswerRubric.fromJson(json['rubric'] as Map<String, dynamic>),
      followUps: (json['followUps'] as List<dynamic>? ?? const [])
          .cast<String>(),
      tags: (json['tags'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }

  final String id;
  final String technologyId;
  final SeniorityLevel level;
  final String topic;
  final String prompt;
  final String answer;
  final AnswerRubric rubric;

  /// Questions the interviewer will probably chain after this one.
  final List<String> followUps;
  final List<String> tags;
}

class Exercise {
  const Exercise({
    required this.id,
    required this.technologyId,
    required this.title,
    required this.difficulty,
    required this.topic,
    required this.statement,
    required this.hints,
    required this.approach,
    required this.solutionSketch,
    required this.complexity,
    required this.pitfalls,
  });

  factory Exercise.fromJson(Map<String, dynamic> json, String technologyId) {
    return Exercise(
      id: json['id'] as String,
      technologyId: technologyId,
      title: json['title'] as String,
      difficulty: Difficulty.parse(json['difficulty'] as String),
      topic: json['topic'] as String,
      statement: json['statement'] as String,
      hints: (json['hints'] as List<dynamic>? ?? const []).cast<String>(),
      approach: json['approach'] as String,
      solutionSketch: json['solutionSketch'] as String,
      complexity: json['complexity'] as String? ?? '',
      pitfalls: (json['pitfalls'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }

  final String id;
  final String technologyId;
  final String title;
  final Difficulty difficulty;
  final String topic;
  final String statement;

  /// Progressive nudges, revealed one at a time so the user can stay stuck
  /// productively instead of jumping straight to the answer.
  final List<String> hints;

  /// The reasoning: *why* this approach, not just the code.
  final String approach;
  final String solutionSketch;
  final String complexity;
  final List<String> pitfalls;
}

class LearningResource {
  const LearningResource({
    required this.title,
    required this.url,
    required this.kind,
  });

  factory LearningResource.fromJson(Map<String, dynamic> json) {
    return LearningResource(
      title: json['title'] as String,
      url: json['url'] as String,
      kind: ResourceKind.parse(json['kind'] as String),
    );
  }

  final String title;
  final String url;
  final ResourceKind kind;
}

class Milestone {
  const Milestone({
    required this.id,
    required this.title,
    required this.detail,
  });

  factory Milestone.fromJson(Map<String, dynamic> json) {
    return Milestone(
      id: json['id'] as String,
      title: json['title'] as String,
      detail: json['detail'] as String,
    );
  }

  final String id;
  final String title;
  final String detail;
}

class RoadmapStage {
  const RoadmapStage({
    required this.id,
    required this.level,
    required this.title,
    required this.goal,
    required this.estimatedWeeks,
    required this.skills,
    required this.milestones,
    required this.resources,
    required this.readinessSignals,
  });

  factory RoadmapStage.fromJson(Map<String, dynamic> json) {
    return RoadmapStage(
      id: json['id'] as String,
      level: SeniorityLevel.parse(json['level'] as String),
      title: json['title'] as String,
      goal: json['goal'] as String,
      estimatedWeeks: json['estimatedWeeks'] as int,
      skills: (json['skills'] as List<dynamic>).cast<String>(),
      milestones: (json['milestones'] as List<dynamic>)
          .map((raw) => Milestone.fromJson(raw as Map<String, dynamic>))
          .toList(growable: false),
      resources: (json['resources'] as List<dynamic>? ?? const [])
          .map((raw) => LearningResource.fromJson(raw as Map<String, dynamic>))
          .toList(growable: false),
      readinessSignals: (json['readinessSignals'] as List<dynamic>? ?? const [])
          .cast<String>(),
    );
  }

  final String id;
  final SeniorityLevel level;
  final String title;
  final String goal;
  final int estimatedWeeks;
  final List<String> skills;
  final List<Milestone> milestones;
  final List<LearningResource> resources;

  /// Observable evidence that you have actually cleared this stage, as opposed
  /// to having merely read about it.
  final List<String> readinessSignals;
}

/// The full payload for one technology, loaded on demand.
class TechnologyContent {
  const TechnologyContent({
    required this.id,
    required this.name,
    required this.questions,
    required this.exercises,
    required this.roadmap,
  });

  factory TechnologyContent.fromJson(Map<String, dynamic> json) {
    final id = json['technologyId'] as String;
    return TechnologyContent(
      id: id,
      name: json['name'] as String,
      questions: (json['questions'] as List<dynamic>)
          .map((raw) => Question.fromJson(raw as Map<String, dynamic>, id))
          .toList(growable: false),
      exercises: (json['exercises'] as List<dynamic>)
          .map((raw) => Exercise.fromJson(raw as Map<String, dynamic>, id))
          .toList(growable: false),
      roadmap:
          ((json['roadmap'] as Map<String, dynamic>)['stages'] as List<dynamic>)
              .map((raw) => RoadmapStage.fromJson(raw as Map<String, dynamic>))
              .toList(growable: false),
    );
  }

  final String id;
  final String name;
  final List<Question> questions;
  final List<Exercise> exercises;
  final List<RoadmapStage> roadmap;

  Question questionById(String id) =>
      questions.firstWhere((question) => question.id == id);

  Iterable<String> get topics =>
      questions.map((question) => question.topic).toSet();
}
