/// The one place that talks to the platform text-to-speech engine.
///
/// Behind an interface so the player and the settings screen can be tested
/// with a fake: the real engine is a platform channel that does not exist in
/// the test runner.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

import '../domain/voice_settings.dart';

class VoiceOption {
  const VoiceOption({required this.name, required this.locale});

  final String name;

  /// Normalized, e.g. `es-ES`.
  final String locale;

  /// Android's network voices stop working without a connection, which
  /// matters for an app whose selling point is working offline.
  bool get needsNetwork => name.toLowerCase().contains('network');
}

abstract class SpeechEngine {
  /// Spanish voices installed on the device.
  Future<List<VoiceOption>> spanishVoices();

  /// Forces language, voice and rate. Called before every question so a
  /// change in settings applies without restarting the session.
  Future<void> configure(VoiceSettings settings);

  /// Completes when the utterance has finished (or was stopped).
  Future<void> speak(String text);

  Future<void> stop();
}

class FlutterTtsEngine implements SpeechEngine {
  final FlutterTts _tts = FlutterTts();
  Future<void>? _setup;
  List<VoiceOption>? _voices;

  Future<void> _ensureSetup() => _setup ??= () async {
    // Without this, speak() returns immediately and every sentence of the
    // session would be queued over the previous one.
    await _tts.awaitSpeakCompletion(true);
    if (!kIsWeb && Platform.isIOS) {
      // Playback category is what keeps iOS speaking with the screen locked
      // and the silent switch on.
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        IosTextToSpeechAudioMode.spokenAudio,
      );
    }
  }();

  @override
  Future<List<VoiceOption>> spanishVoices() async {
    final cached = _voices;
    if (cached != null) return cached;
    await _ensureSetup();
    final raw = await _tts.getVoices as List<dynamic>? ?? const [];
    final voices = <VoiceOption>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final name = entry['name']?.toString();
      final locale = entry['locale']?.toString();
      if (name == null || locale == null) continue;
      final normalized = normalizeLocale(locale);
      if (!normalized.startsWith('es')) continue;
      voices.add(VoiceOption(name: name, locale: normalized));
    }
    // Offline voices first: they are the ones that work everywhere.
    voices.sort((a, b) {
      final byNetwork = (a.needsNetwork ? 1 : 0) - (b.needsNetwork ? 1 : 0);
      return byNetwork != 0 ? byNetwork : a.name.compareTo(b.name);
    });
    return _voices = voices;
  }

  @override
  Future<void> configure(VoiceSettings settings) async {
    await _ensureSetup();
    final voices = await spanishVoices();
    final language = settings.resolveLanguage(voices.map((v) => v.locale));
    await _tts.setLanguage(language);
    final voice = voices
        .where((v) => v.name == settings.voiceName && v.locale == language)
        .firstOrNull;
    if (voice != null) {
      await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
    }
    await _tts.setSpeechRate(settings.rate);
  }

  @override
  Future<void> speak(String text) async {
    await _ensureSetup();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}
