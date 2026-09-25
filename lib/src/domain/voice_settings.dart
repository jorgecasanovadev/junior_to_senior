/// User preferences for the listening mode.
///
/// The language is stored explicitly instead of following the system locale:
/// the whole bank is in Spanish, and a phone set to English would otherwise
/// read it with an English voice.
library;

import 'models.dart';

class VoiceSettings {
  const VoiceSettings({
    this.language,
    this.voiceName,
    this.rate = 0.5,
    this.thinkPause = const Duration(seconds: 8),
    this.rubricLevel = SeniorityLevel.senior,
  });

  factory VoiceSettings.fromJson(Map<String, dynamic> json) {
    final rubric = json['rubricLevel'] as String?;
    return VoiceSettings(
      language: json['language'] as String?,
      voiceName: json['voiceName'] as String?,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.5,
      thinkPause: Duration(seconds: json['thinkPauseSeconds'] as int? ?? 8),
      rubricLevel: rubric == null ? null : SeniorityLevel.parse(rubric),
    );
  }

  /// BCP-47 tag such as `es-ES`. Null means "pick the best Spanish voice the
  /// device has"; see [preferredSpanishLocales].
  final String? language;

  /// Engine-specific voice id. Null uses the engine's default for [language].
  final String? voiceName;

  /// Engine rate: 0.5 is normal speed on both Android and iOS.
  final double rate;

  /// Silence after the question, to answer before hearing the answer.
  final Duration thinkPause;

  /// Which level's model answer to read after the answer. Null skips it.
  final SeniorityLevel? rubricLevel;

  static const minRate = 0.3;
  static const maxRate = 0.7;
  static const maxThinkPause = Duration(seconds: 20);

  /// Tried in order when no language was chosen. Latin American Spanish first
  /// because it is the variant most of the audience speaks.
  static const preferredSpanishLocales = ['es-419', 'es-US', 'es-MX', 'es-ES'];

  VoiceSettings copyWith({
    String? language,
    String? voiceName,
    bool clearVoice = false,
    double? rate,
    Duration? thinkPause,
    SeniorityLevel? rubricLevel,
    bool clearRubric = false,
  }) {
    return VoiceSettings(
      language: language ?? this.language,
      voiceName: clearVoice ? null : voiceName ?? this.voiceName,
      rate: rate ?? this.rate,
      thinkPause: thinkPause ?? this.thinkPause,
      rubricLevel: clearRubric ? null : rubricLevel ?? this.rubricLevel,
    );
  }

  Map<String, dynamic> toJson() => {
    'language': language,
    'voiceName': voiceName,
    'rate': rate,
    'thinkPauseSeconds': thinkPause.inSeconds,
    'rubricLevel': rubricLevel?.name,
  };

  /// The language to force on the engine, given the Spanish locales the device
  /// actually has. Falls back to plain `es` so the engine still picks Spanish
  /// over the system language when nothing better is known.
  String resolveLanguage(Iterable<String> available) {
    final normalized = available.map(normalizeLocale).toSet();
    final chosen = language;
    if (chosen != null && normalized.contains(chosen)) return chosen;
    for (final candidate in preferredSpanishLocales) {
      if (normalized.contains(candidate)) return candidate;
    }
    final anySpanish = normalized.where((l) => l.startsWith('es')).toList()
      ..sort();
    return anySpanish.isNotEmpty ? anySpanish.first : (chosen ?? 'es');
  }
}

/// Engines disagree on separators and case (`es_ES`, `es-es`); compare them
/// as `es-ES`.
String normalizeLocale(String raw) {
  final parts = raw.replaceAll('_', '-').split('-');
  if (parts.length == 1) return parts.first.toLowerCase();
  final region = parts[1];
  // Numeric regions such as 419 stay as they are.
  return '${parts.first.toLowerCase()}-'
      '${region.length == 2 ? region.toUpperCase() : region}';
}

/// Human name for a Spanish locale, for the settings screen.
String spanishLocaleLabel(String locale) => switch (normalizeLocale(locale)) {
  'es-ES' => 'Español (España)',
  'es-MX' => 'Español (México)',
  'es-US' => 'Español (EE. UU.)',
  'es-419' => 'Español (Latinoamérica)',
  'es-AR' => 'Español (Argentina)',
  'es-CO' => 'Español (Colombia)',
  'es-CL' => 'Español (Chile)',
  'es-PE' => 'Español (Perú)',
  final other => 'Español ($other)',
};
