import 'package:flutter_test/flutter_test.dart';
import 'package:junior_to_senior/src/domain/models.dart';
import 'package:junior_to_senior/src/domain/speech_script.dart';
import 'package:junior_to_senior/src/domain/voice_settings.dart';

const _question = Question(
  id: 'q1',
  technologyId: 'flutter',
  level: SeniorityLevel.mid,
  topic: 'Widgets',
  prompt: '¿Qué hace `setState`?',
  answer: 'Marca el **Element** como sucio.',
  rubric: AnswerRubric(
    junior: 'Redibuja.',
    mid: 'Marca sucio y programa un frame.',
    senior: 'Y solo reconstruye ese subárbol.',
  ),
  followUps: [],
  tags: [],
);

void main() {
  group('speechText', () {
    test('quita la sintaxis Markdown y conserva el texto', () {
      expect(
        speechText('Usa **const** y `setState`, ver [docs](https://x.dev).'),
        'Usa const y setState, ver docs.',
      );
    });

    test('cambia los bloques de código por un aviso hablado', () {
      final text = speechText('Así:\n```dart\nfinal a = 1;\n```\nY listo');
      expect(text, contains('En la app hay un ejemplo de código.'));
      expect(text, isNot(contains('final a')));
    });

    test('cada línea de lista acaba como frase', () {
      expect(speechText('- Uno\n- Dos\n1. Tres'), 'Uno. Dos. Tres.');
    });

    test('las flechas se convierten en pausas, no en «flecha»', () {
      expect(speechText('UI → Bloc -> Repo'), 'UI, Bloc, Repo.');
    });

    test('no confunde guiones bajos de identificadores con cursiva', () {
      expect(speechText('snake_case_name'), 'snake_case_name.');
    });

    test('las tablas se leen sin barras ni separadores', () {
      expect(speechText('| A | B |\n|---|---|\n| 1 | 2 |'), 'A, B. 1, 2.');
    });
  });

  group('chunkForSpeech', () {
    test('un texto corto queda entero', () {
      expect(chunkForSpeech('Hola.'), ['Hola.']);
    });

    test('corta en fin de frase sin pasarse del máximo', () {
      final text = List.filled(50, 'Una frase de prueba.').join(' ');
      final chunks = chunkForSpeech(text, maxLength: 100);
      expect(chunks.every((c) => c.length <= 100), isTrue);
      expect(chunks.every((c) => c.endsWith('.')), isTrue);
      expect(chunks.join(' '), text);
    });

    test('una frase enorme se corta por espacios', () {
      final text = List.filled(60, 'palabra').join(' ');
      final chunks = chunkForSpeech(text, maxLength: 50);
      expect(chunks.every((c) => c.length <= 50), isTrue);
      expect(chunks.join(' '), text);
    });
  });

  group('scriptFor', () {
    test('pregunta, pausa para pensar, respuesta y rúbrica', () {
      final script = scriptFor(
        _question,
        position: 2,
        total: 5,
        settings: const VoiceSettings(thinkPause: Duration(seconds: 5)),
      );
      expect(script, [
        const Say('Pregunta 2 de 5. Nivel Mid. Widgets.'),
        const Say('¿Qué hace setState?'),
        const Say('Piensa tu respuesta.'),
        const Silence(Duration(seconds: 5)),
        const Say('Respuesta.'),
        const Say('Marca el Element como sucio.'),
        const Say('Cómo suena a nivel Senior.'),
        const Say('Y solo reconstruye ese subárbol.'),
      ]);
    });

    test('sin pausa ni rúbrica si se desactivan', () {
      final script = scriptFor(
        _question,
        position: 1,
        total: 1,
        settings: const VoiceSettings(
          thinkPause: Duration.zero,
          rubricLevel: null,
        ),
      );
      expect(script.whereType<Silence>(), isEmpty);
      expect(script.last, const Say('Marca el Element como sucio.'));
    });
  });

  group('VoiceSettings', () {
    test('sin elección, prefiere el español latinoamericano disponible', () {
      expect(
        const VoiceSettings().resolveLanguage(['es-ES', 'es-US']),
        'es-US',
      );
    });

    test('respeta la variante elegida si el teléfono la tiene', () {
      expect(
        const VoiceSettings(
          language: 'es-ES',
        ).resolveLanguage(['es-ES', 'es-US']),
        'es-ES',
      );
    });

    test('nunca cae al idioma del sistema: sin voces, fuerza «es»', () {
      expect(const VoiceSettings().resolveLanguage(['en-US']), 'es');
    });

    test('normaliza los formatos de locale de cada motor', () {
      expect(normalizeLocale('es_es'), 'es-ES');
      expect(normalizeLocale('es-419'), 'es-419');
      expect(const VoiceSettings().resolveLanguage(['es_MX']), 'es-MX');
    });

    test('sobrevive a guardar y leer', () {
      const original = VoiceSettings(
        language: 'es-MX',
        voiceName: 'x',
        rate: 0.4,
        thinkPause: Duration(seconds: 12),
        rubricLevel: SeniorityLevel.junior,
      );
      final restored = VoiceSettings.fromJson(original.toJson());
      expect(restored.toJson(), original.toJson());
    });

    test('la rúbrica desactivada se guarda como desactivada', () {
      final restored = VoiceSettings.fromJson(
        const VoiceSettings(rubricLevel: null).toJson(),
      );
      expect(restored.rubricLevel, isNull);
    });
  });
}
