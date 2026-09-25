import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/audio/speech_engine.dart';
import 'src/audio/study_audio_handler.dart';
import 'src/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Dates are rendered in Spanish throughout the stats screen.
  await initializeDateFormatting('es');
  final prefs = await SharedPreferences.getInstance();
  final engine = FlutterTtsEngine();

  // The handler outlives any screen and reads settings when each question
  // starts, so it gets a reader into the container instead of a snapshot.
  late final ProviderContainer container;
  StudyAudioHandler build() =>
      StudyAudioHandler(engine, () => container.read(voiceSettingsProvider));

  StudyAudioHandler handler;
  try {
    handler = await AudioService.init(
      builder: build,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.juniortosenior.study_audio',
        androidNotificationChannelName: 'Escuchar preguntas',
        // Keeping the service in the foreground while paused avoids
        // Android 12+ refusing to restart it from the lock screen.
        androidStopForegroundOnPause: false,
      ),
    );
  } on Object catch (error) {
    // Without the media session the app still works; listening just stops
    // when the app goes to the background.
    debugPrint('Background audio unavailable: $error');
    handler = build();
  }

  container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      speechEngineProvider.overrideWithValue(engine),
      audioHandlerProvider.overrideWithValue(handler),
    ],
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const JuniorToSeniorApp(),
    ),
  );
}
