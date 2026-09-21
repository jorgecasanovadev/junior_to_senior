import 'package:flutter/material.dart';

/// Licensing and provenance. A public project that mixes code and editorial
/// content needs to say, in the app itself, which licence covers what.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('junior → senior', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Preguntas de entrevista, ejercicios con su razonamiento, rutas '
            'de estudio y repaso espaciado. Todo el contenido viaja dentro de '
            'la app y tu progreso se guarda solo en este dispositivo: no hay '
            'cuenta, ni servidor, ni telemetría.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 28),
          _Section(
            title: 'Licencias',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LicenseRow(
                  what: 'Código fuente',
                  license: 'Apache License 2.0',
                  detail:
                      'Uso libre, incluido comercial. Incluye concesión '
                      'explícita de patentes y obliga a conservar la '
                      'atribución del archivo NOTICE.',
                ),
                SizedBox(height: 16),
                _LicenseRow(
                  what: 'Contenido educativo',
                  license: 'CC BY-SA 4.0',
                  detail:
                      'Las preguntas, respuestas, rúbricas, ejercicios y '
                      'rutas se pueden reutilizar citando la fuente, pero '
                      'las obras derivadas deben publicarse con la misma '
                      'licencia.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _Section(
            title: 'Cómo contribuir',
            child: Text(
              'Cada tecnología es un único fichero JSON en assets/content/. '
              'Añadir una pregunta, un ejercicio o una etapa de la ruta es '
              'editar ese fichero y abrir un pull request: no hace falta '
              'tocar código Dart.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: 28),
          _Section(
            title: 'Aviso',
            child: Text(
              'Las respuestas modelo reflejan el criterio de quien las '
              'escribió. Úsalas para calibrarte, no como verdad absoluta: en '
              'una entrevista real se valora más el razonamiento que la '
              'coincidencia literal.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'junior → senior',
                applicationLegalese: '© 2026 Jorge Casanova',
              ),
              child: const Text('Licencias de las dependencias'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _LicenseRow extends StatelessWidget {
  const _LicenseRow({
    required this.what,
    required this.license,
    required this.detail,
  });

  final String what;
  final String license;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                what,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                license,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
