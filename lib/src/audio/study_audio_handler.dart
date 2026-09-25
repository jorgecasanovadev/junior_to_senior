/// Plays a list of questions as spoken audio, in the background too.
///
/// audio_service turns this into a media session: lock-screen and
/// notification controls, headset buttons, and on Android a foreground
/// service that keeps the process alive with the screen off.
library;

import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../domain/models.dart';
import '../domain/speech_script.dart';
import '../domain/voice_settings.dart';
import 'speech_engine.dart';

class StudyAudioHandler extends BaseAudioHandler {
  StudyAudioHandler(this._engine, this._settings);

  final SpeechEngine _engine;

  /// Read when each question starts, so a settings change applies from the
  /// next question without restarting the session.
  final VoiceSettings Function() _settings;

  List<Question> _questions = const [];
  int _index = 0;

  /// Bumped by every pause, skip or stop. A playback loop only keeps going
  /// while the generation it started with is still current, which is how a
  /// loop stuck awaiting the engine gets cancelled without shared flags.
  int _generation = 0;

  List<Question> get questions => _questions;
  int get index => _index;

  Future<void> load({
    required String title,
    required List<Question> questions,
    int startAt = 0,
  }) async {
    await stop();
    _questions = List.unmodifiable(questions);
    _index = startAt.clamp(0, questions.isEmpty ? 0 : questions.length - 1);
    queue.add([
      for (final question in questions)
        MediaItem(
          id: question.id,
          title: question.prompt,
          album: title,
          artist: '${question.level.label} · ${question.topic}',
        ),
    ]);
    _publishCurrent();
    _publishState(playing: false, processing: AudioProcessingState.ready);
  }

  @override
  Future<void> play() async {
    if (_questions.isEmpty) return;
    final generation = ++_generation;
    _publishState(playing: true, processing: AudioProcessingState.ready);
    unawaited(_run(generation));
  }

  @override
  Future<void> pause() async {
    _generation++;
    await _engine.stop();
    _publishState(playing: false, processing: AudioProcessingState.ready);
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _engine.stop();
    _publishState(playing: false, processing: AudioProcessingState.idle);
    await super.stop();
  }

  @override
  Future<void> skipToNext() => _jumpTo(_index + 1);

  @override
  Future<void> skipToPrevious() => _jumpTo(_index - 1);

  @override
  Future<void> skipToQueueItem(int index) => _jumpTo(index);

  Future<void> _jumpTo(int target) async {
    if (target < 0 || target >= _questions.length) return;
    final wasPlaying = playbackState.value.playing;
    _generation++;
    await _engine.stop();
    _index = target;
    _publishCurrent();
    if (wasPlaying) {
      await play();
    } else {
      _publishState(playing: false, processing: AudioProcessingState.ready);
    }
  }

  Future<void> _run(int generation) async {
    bool cancelled() => generation != _generation;

    while (!cancelled() && _index < _questions.length) {
      _publishCurrent();
      final settings = _settings();
      await _engine.configure(settings);
      final segments = scriptFor(
        _questions[_index],
        position: _index + 1,
        total: _questions.length,
        settings: settings,
      );
      for (final segment in segments) {
        if (cancelled()) return;
        switch (segment) {
          case Say(:final text):
            for (final chunk in chunkForSpeech(text)) {
              if (cancelled()) return;
              await _engine.speak(chunk);
            }
          case Silence(:final duration):
            await Future<void>.delayed(duration);
        }
      }
      if (cancelled()) return;
      _index++;
    }
    if (cancelled()) return;
    // Finished: park on the first question, ready to go again.
    _index = 0;
    _publishCurrent();
    _publishState(playing: false, processing: AudioProcessingState.completed);
  }

  void _publishCurrent() {
    final items = queue.value;
    if (_index < items.length) mediaItem.add(items[_index]);
  }

  void _publishState({
    required bool playing,
    required AudioProcessingState processing,
  }) {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {MediaAction.skipToQueueItem},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processing,
        playing: playing,
        queueIndex: _index,
      ),
    );
  }
}
