# junior → senior

Una app Flutter para prepararse entrevistas técnicas y, sobre todo, para **saber qué te falta** para el siguiente nivel.

Buscas una tecnología y obtienes cuatro cosas:

1. **50 preguntas de entrevista**, con respuesta razonada y las repreguntas que suelen venir después.
2. **Ejercicios técnicos** con pistas graduales, el razonamiento de la solución y los errores donde casi todo el mundo cae.
3. **Una ruta de estudio** por etapas hasta seniority, con hitos marcables y señales observables de que has superado cada etapa.
4. **Práctica con repaso espaciado**: un simulador de entrevista que usa SM-2 para decidir cuándo te vuelve a preguntar cada cosa.

Además, cada pregunta incluye una **rúbrica por nivel**: cómo suena la respuesta de un junior, de un mid y de un senior. Casi siempre es la misma pregunta; lo que cambia es la profundidad. Esa comparación es la parte más útil de la app.

**Todo funciona sin conexión.** El contenido viaja dentro del binario y tu progreso se guarda solo en tu dispositivo: no hay cuenta, ni servidor, ni telemetría.

---

## Estado

| | |
|---|---|
| Tecnologías con contenido | Flutter, Dart |
| Preguntas | 100 (50 por tecnología) |
| Ejercicios | 20 |
| Etapas de ruta | 8, con 50 hitos |
| Plataformas | Android · iOS · Web |

Añadir una tecnología nueva es escribir un fichero JSON. No hace falta tocar código Dart. Ver [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Arranque rápido

```bash
flutter pub get
dart run build_runner build        # genera el código de la base de datos
flutter run                        # o: flutter run -d chrome
```

Requiere Flutter 3.44 o superior (Dart 3.12).

```bash
flutter test          # toda la suite, incluida la validación del contenido
flutter analyze
```

---

## Cómo está construido

```
lib/src/
  domain/          Dart puro, sin imports de Flutter. Testeable sin widgets.
    models.dart          Entidades del contenido y sus parsers
    srs.dart             Algoritmo SM-2 de repaso espaciado
    session_planner.dart Qué preguntas entran en una sesión
  data/
    content_repository.dart   Lee los assets, cachea y busca
    database.dart             Esquema drift (progreso local)
    progress_repository.dart  Traduce entre drift y el dominio
  features/        UI por funcionalidad
  core/            Tema, rutas, formateo
  providers.dart   El grafo de dependencias completo, en un solo sitio
```

**Decisiones que conviene conocer:**

- **El dominio no importa Flutter.** Eso hace que el SM-2 y el planificador de sesiones se prueben en milisegundos, sin montar widgets.
- **El contenido es un asset, no una API.** Es lo que hace la app offline por construcción, y lo que permite revisar cada pregunta en un pull request como se revisa el código.
- **Drift para la persistencia.** Consultas tipadas en compilación y `Stream` sobre las consultas, así que la UI se actualiza sola cuando cambia el progreso, sin invalidaciones manuales.
- **Riverpod 3** sin generación de código: el grafo es pequeño y se lee entero en `providers.dart`.

### Repaso espaciado

Se usa **SM-2** (Wozniak, 1990), el algoritmo detrás de SuperMemo y, en esencia, de Anki. Necesita tres números por tarjeta, lo que mantiene la base de datos diminuta y el cálculo trivial.

Tres botones de autoevaluación, mapeados a la escala de calidad 0-5 del algoritmo:

| Botón | Calidad | Efecto |
|---|---|---|
| No la supe | 1 | Reinicia la racha y la tarjeta vuelve en esta misma sesión |
| A medias | 3 | Aprueba por lo justo; el intervalo crece poco y el factor de facilidad baja |
| La clavé | 5 | Intervalo × factor de facilidad, que además sube |

Los dos primeros aciertos usan intervalos fijos de 1 y 6 días; a partir del tercero, el intervalo se multiplica por el factor de facilidad, acotado por abajo en 1,3. Implementación y tests en [`lib/src/domain/srs.dart`](lib/src/domain/srs.dart) y [`test/srs_test.dart`](test/srs_test.dart).

---

## Licencias

Este repositorio está licenciado en dos partes, porque el código y el contenido educativo tienen necesidades distintas:

| Qué | Licencia | Implica |
|---|---|---|
| **Código fuente** (todo menos `assets/content/`) | [Apache 2.0](LICENSE) | Uso libre, incluido comercial. Concesión explícita de patentes. Hay que conservar la atribución del [NOTICE](NOTICE). |
| **Contenido educativo** (`assets/content/`) | [CC BY-SA 4.0](LICENSE-CONTENT) | Reutilizable citando la fuente, pero las obras derivadas deben publicarse con la misma licencia. |

La separación es deliberada: las licencias de software no protegen bien el contenido editorial, y `BY-SA` garantiza que las mejoras al banco de preguntas vuelvan a la comunidad en lugar de acabar encerradas en un producto cerrado.

---

## Aviso

Las respuestas modelo reflejan el criterio de quien las escribió y pueden quedarse desactualizadas. Úsalas para calibrarte, no como verdad absoluta: en una entrevista real se valora el razonamiento mucho más que la coincidencia literal con una respuesta memorizada.
