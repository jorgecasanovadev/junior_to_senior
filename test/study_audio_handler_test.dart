import 'package:flutter_test/flutter_test.dart';
import 'package:junior_to_senior/src/audio/study_audio_handler.dart';
import 'package:junior_to_senior/src/domain/models.dart';
import 'package:junior_to_senior/src/domain/voice_settings.dart';

import 'support/fake_speech_engine.dart';

Question _q(String id) => Question(
  id: id,
  technologyId: 'flutter',
  level: SeniorityLevel.junior,
  topic: 'Tema',
  prompt: 'Pregunta $id',
  answer: 'Respuesta $id',
  rubric: const AnswerRubric(junior: 'j', mid: 'm', senior: 's'),
  followUps: const [],
  tags: const [],
);

/// Lets the playback loop run its pending microtasks.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  // No pause and no rubric keeps each question to a predictable script.
  const settings = VoiceSettings(thinkPause: Duration.zero, rubricLevel: null);

  late FakeSpeechEngine engine;
  late StudyAudioHandler handler;

  setUp(() {
    engine = FakeSpeechEngine();
    handler = StudyAudioHandler(engine, () => settings);
  });

  test('lee las preguntas en orden y termina en la primera', () async {
    await handler.load(title: 'Flutter', questions: [_q('a'), _q('b')]);
    await handler.play();
    for (var i = 0; i < 20; i++) {
      await _settle();
    }

    expect(engine.spoken, [
      'Pregunta 1 de 2. Nivel Junior. Tema.',
      'Pregunta a.',
      'Respuesta.',
      'Respuesta a.',
      'Pregunta 2 de 2. Nivel Junior. Tema.',
      'Pregunta b.',
      'Respuesta.',
      'Respuesta b.',
    ]);
    expect(handler.playbackState.value.playing, isFalse);
    expect(handler.index, 0);
  });

  test('fuerza los ajustes de voz antes de cada pregunta', () async {
    await handler.load(title: 'Flutter', questions: [_q('a'), _q('b')]);
    await handler.play();
    for (var i = 0; i < 20; i++) {
      await _settle();
    }
    expect(engine.configured, hasLength(2));
  });

  test('pausar corta la frase en curso y no sigue hablando', () async {
    engine.hold = true;
    await handler.load(title: 'Flutter', questions: [_q('a'), _q('b')]);
    await handler.play();
    await _settle();
    expect(engine.spoken, hasLength(1));

    await handler.pause();
    for (var i = 0; i < 10; i++) {
      await _settle();
    }
    expect(engine.spoken, hasLength(1));
    expect(handler.playbackState.value.playing, isFalse);
  });

  test(
    'saltar a la siguiente mientras suena empieza por esa pregunta',
    () async {
      engine.hold = true;
      await handler.load(title: 'Flutter', questions: [_q('a'), _q('b')]);
      await handler.play();
      await _settle();

      await handler.skipToNext();
      await _settle();
      expect(engine.spoken.last, 'Pregunta 2 de 2. Nivel Junior. Tema.');
      expect(handler.mediaItem.value?.id, 'b');
    },
  );

  test('no salta fuera de la lista', () async {
    await handler.load(title: 'Flutter', questions: [_q('a')]);
    await handler.skipToPrevious();
    await handler.skipToNext();
    expect(handler.index, 0);
  });
}
