/// Persists small user preferences.
///
/// shared_preferences rather than the drift database: these are a handful of
/// scalars read once at start-up, not data that needs queries or streams.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/voice_settings.dart';

class SettingsRepository {
  SettingsRepository(this._prefs);

  static const _voiceKey = 'voice_settings';

  final SharedPreferences _prefs;

  VoiceSettings voice() {
    final raw = _prefs.getString(_voiceKey);
    if (raw == null) return const VoiceSettings();
    try {
      return VoiceSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      // A value written by an older build should not lock the user out of
      // the listening mode; start again from the defaults.
      return const VoiceSettings();
    }
  }

  Future<void> saveVoice(VoiceSettings settings) =>
      _prefs.setString(_voiceKey, jsonEncode(settings.toJson()));
}
