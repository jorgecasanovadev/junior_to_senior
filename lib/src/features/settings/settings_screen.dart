import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../audio/speech_engine.dart';
import '../../domain/models.dart';
import '../../domain/voice_settings.dart';
import '../../providers.dart';

/// General settings. Today that is the study voice; the language is forced to
/// Spanish here so a phone set to English still reads the bank correctly.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _sample =
      'Pregunta de prueba. ¿Por qué un widget const puede ahorrar trabajo en '
      'cada reconstrucción?';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(voiceSettingsProvider);
    final voices = ref.watch(spanishVoicesProvider);
    final theme = Theme.of(context);
    void update(VoiceSettings next) =>
        ref.read(voiceSettingsProvider.notifier).update(next);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        children: [
          Text('Voz de estudio', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Se usa siempre español, aunque el teléfono esté en otro idioma.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          switch (voices) {
            AsyncData(value: final list) => _VoicePickers(
              voices: list,
              settings: settings,
              onChanged: update,
            ),
            AsyncError() => const _Notice(
              'No se pudo consultar las voces del teléfono. Se usará la voz '
              'en español por defecto del sistema.',
            ),
            _ => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          },
          const SizedBox(height: 20),
          _SliderRow(
            label: 'Velocidad',
            valueLabel: _rateLabel(settings.rate),
            child: Slider(
              value: settings.rate,
              min: VoiceSettings.minRate,
              max: VoiceSettings.maxRate,
              divisions: 8,
              onChanged: (value) => update(settings.copyWith(rate: value)),
            ),
          ),
          _SliderRow(
            label: 'Pausa para pensar',
            valueLabel: settings.thinkPause == Duration.zero
                ? 'Sin pausa'
                : '${settings.thinkPause.inSeconds} s',
            child: Slider(
              value: settings.thinkPause.inSeconds.toDouble(),
              max: VoiceSettings.maxThinkPause.inSeconds.toDouble(),
              divisions: VoiceSettings.maxThinkPause.inSeconds,
              onChanged: (value) => update(
                settings.copyWith(thinkPause: Duration(seconds: value.round())),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Después de la respuesta, leer cómo suena a nivel…',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('No leer'),
                selected: settings.rubricLevel == null,
                onSelected: (_) => update(settings.copyWith(clearRubric: true)),
              ),
              for (final level in SeniorityLevel.values)
                ChoiceChip(
                  label: Text(level.label),
                  selected: settings.rubricLevel == level,
                  onSelected: (_) =>
                      update(settings.copyWith(rubricLevel: level)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              final engine = ref.read(speechEngineProvider);
              await engine.stop();
              await engine.configure(ref.read(voiceSettingsProvider));
              await engine.speak(_sample);
            },
            icon: const Icon(Icons.record_voice_over_outlined),
            label: const Text('Probar voz'),
          ),
          const Divider(height: 40),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('Acerca de'),
            subtitle: const Text('Licencias y origen del contenido'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/about'),
          ),
        ],
      ),
    );
  }

  static String _rateLabel(double rate) {
    if (rate < 0.45) return 'Lenta';
    if (rate > 0.55) return 'Rápida';
    return 'Normal';
  }
}

class _VoicePickers extends StatelessWidget {
  const _VoicePickers({
    required this.voices,
    required this.settings,
    required this.onChanged,
  });

  final List<VoiceOption> voices;
  final VoiceSettings settings;
  final ValueChanged<VoiceSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    if (voices.isEmpty) {
      return const _Notice(
        'Tu teléfono no tiene voces en español instaladas. En Android: '
        'Ajustes › Sistema › Idiomas › Salida de texto a voz, e instala '
        'el español. En iPhone: Ajustes › Accesibilidad › Contenido leído › '
        'Voces.',
      );
    }

    final locales = voices.map((voice) => voice.locale).toSet().toList()
      ..sort();
    final language = settings.resolveLanguage(locales);
    final inLanguage = voices.where((voice) => voice.locale == language);
    final voiceName = inLanguage.any((v) => v.name == settings.voiceName)
        ? settings.voiceName
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: language,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Variante de español'),
          items: [
            for (final locale in locales)
              DropdownMenuItem(
                value: locale,
                child: Text(spanishLocaleLabel(locale)),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            onChanged(settings.copyWith(language: value, clearVoice: true));
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          // Keyed by language so the field resets when the variant changes.
          key: ValueKey(language),
          initialValue: voiceName,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Voz'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Predeterminada del sistema'),
            ),
            for (final voice in inLanguage)
              DropdownMenuItem<String?>(
                value: voice.name,
                child: Text(
                  voice.needsNetwork
                      ? '${voice.name} (requiere conexión)'
                      : voice.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => value == null
              ? onChanged(settings.copyWith(clearVoice: true))
              : onChanged(settings.copyWith(voiceName: value)),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.child,
  });

  final String label;
  final String valueLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text(
              valueLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        child,
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }
}
