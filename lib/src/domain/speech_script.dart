/// Turns a question into what the listening mode says, in order.
///
/// Pure Dart so the wording and the Markdown clean-up can be tested without a
/// speech engine. The shape follows active recall: ask, leave silence to
/// answer in your head, then give the answer.
library;

import 'models.dart';
import 'voice_settings.dart';

sealed class SpeechSegment {
  const SpeechSegment();
}

class Say extends SpeechSegment {
  const Say(this.text);

  final String text;

  @override
  bool operator ==(Object other) => other is Say && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'Say($text)';
}

class Silence extends SpeechSegment {
  const Silence(this.duration);

  final Duration duration;

  @override
  bool operator ==(Object other) =>
      other is Silence && other.duration == duration;

  @override
  int get hashCode => duration.hashCode;

  @override
  String toString() => 'Silence($duration)';
}

List<SpeechSegment> scriptFor(
  Question question, {
  required int position,
  required int total,
  required VoiceSettings settings,
}) {
  final rubricLevel = settings.rubricLevel;
  return [
    Say(
      'Pregunta $position de $total. '
      'Nivel ${question.level.label}. ${question.topic}.',
    ),
    Say(speechText(question.prompt)),
    if (settings.thinkPause > Duration.zero) ...[
      const Say('Piensa tu respuesta.'),
      Silence(settings.thinkPause),
    ],
    const Say('Respuesta.'),
    Say(speechText(question.answer)),
    if (rubricLevel != null) ...[
      Say('Cómo suena a nivel ${rubricLevel.label}.'),
      Say(speechText(question.rubric.forLevel(rubricLevel))),
    ],
  ];
}

final _fencedCode = RegExp(r'```[\s\S]*?```');
final _link = RegExp(r'\[([^\]]+)\]\([^)]*\)');
final _inlineCode = RegExp(r'`([^`]+)`');
final _strong = RegExp(r'(\*\*|__)(.+?)\1');
final _emphasis = RegExp(r'(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])');
final _listMarker = RegExp(r'^\s*(?:[-*+]|\d+[.)])\s+');
final _heading = RegExp(r'^\s*#{1,6}\s+');
final _quote = RegExp(r'^\s*>\s?');
final _tableRule = RegExp(r'^\s*\|?\s*:?-{2,}');
final _endsSentence = RegExp(r'[.!?:;…]$');

/// Markdown written for the screen, rewritten for the ear.
///
/// Code blocks are replaced by a spoken note: read symbol by symbol they are
/// noise, and the listener can open the app later. Every line becomes its own
/// sentence so the voice pauses where a reader's eye would.
String speechText(String markdown) {
  final withoutCode = markdown.replaceAll(
    _fencedCode,
    '\nEn la app hay un ejemplo de código.\n',
  );

  final sentences = <String>[];
  for (final rawLine in withoutCode.split('\n')) {
    if (_tableRule.hasMatch(rawLine)) continue;
    var line = rawLine
        .replaceFirst(_heading, '')
        .replaceFirst(_quote, '')
        .replaceFirst(_listMarker, '')
        .replaceAllMapped(_link, (m) => m[1]!)
        .replaceAllMapped(_inlineCode, (m) => m[1]!)
        .replaceAllMapped(_strong, (m) => m[2]!)
        .replaceAllMapped(_emphasis, (m) => m[1]!)
        .replaceAll(RegExp(r'\s*\|\s*'), ', ')
        // Arrows read as "flecha derecha"; a pause says the same thing.
        .replaceAll(RegExp(r'\s*(→|->|⇒|=>)\s*'), ', ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    line = line.replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '');
    if (line.isEmpty) continue;
    sentences.add(_endsSentence.hasMatch(line) ? line : '$line.');
  }
  return sentences.join(' ');
}

/// Splits [text] into pieces the platform engine accepts.
///
/// Android refuses utterances longer than about 4000 characters, so long
/// answers are cut at sentence boundaries, never mid-word.
List<String> chunkForSpeech(String text, {int maxLength = 3000}) {
  if (text.length <= maxLength) return [text];
  final chunks = <String>[];
  final buffer = StringBuffer();
  for (final sentence in text.split(RegExp(r'(?<=[.!?…])\s+'))) {
    if (buffer.isNotEmpty && buffer.length + sentence.length + 1 > maxLength) {
      chunks.add(buffer.toString());
      buffer.clear();
    }
    if (sentence.length > maxLength) {
      // A single runaway sentence: fall back to cutting at spaces.
      for (final word in sentence.split(' ')) {
        if (buffer.isNotEmpty && buffer.length + word.length + 1 > maxLength) {
          chunks.add(buffer.toString());
          buffer.clear();
        }
        buffer.write(buffer.isEmpty ? word : ' $word');
      }
      continue;
    }
    buffer.write(buffer.isEmpty ? sentence : ' $sentence');
  }
  if (buffer.isNotEmpty) chunks.add(buffer.toString());
  return chunks;
}
