import 'dart:async';

import 'package:junior_to_senior/src/audio/speech_engine.dart';
import 'package:junior_to_senior/src/domain/voice_settings.dart';

/// Records what would have been spoken. Each utterance completes on the next
/// microtask unless [hold] is set, in which case it waits for [release] or
/// [stop], like a real engine mid-sentence.
class FakeSpeechEngine implements SpeechEngine {
  FakeSpeechEngine({
    this.voices = const [
      VoiceOption(name: 'es-es-x-eea-local', locale: 'es-ES'),
      VoiceOption(name: 'es-us-x-esd-local', locale: 'es-US'),
      VoiceOption(name: 'es-us-x-esd-network', locale: 'es-US'),
    ],
  });

  final List<VoiceOption> voices;
  final List<String> spoken = [];
  final List<VoiceSettings> configured = [];
  int stops = 0;
  bool hold = false;
  Completer<void>? _pending;

  @override
  Future<List<VoiceOption>> spanishVoices() async => voices;

  @override
  Future<void> configure(VoiceSettings settings) async =>
      configured.add(settings);

  @override
  Future<void> speak(String text) {
    spoken.add(text);
    if (!hold) return Future.value();
    return (_pending = Completer<void>()).future;
  }

  void release() => _pending?.complete();

  @override
  Future<void> stop() async {
    stops++;
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }
}
