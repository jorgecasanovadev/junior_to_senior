# Cómo contribuir

La forma más útil de contribuir es **añadir contenido**. El código de la app está razonablemente completo; lo que la hace valiosa es el banco de preguntas, y eso escala con la gente.

Al enviar un pull request aceptas que tu aportación se publique bajo las licencias del proyecto: Apache 2.0 para el código y CC BY-SA 4.0 para el contenido de `assets/content/`.

---

## Añadir una tecnología

Dos pasos. **No hace falta escribir Dart.**

### 1. Añade la entrada al índice

En `assets/content/index.json`:

```json
{
  "id": "react",
  "name": "React",
  "tagline": "Frase corta que diga de qué va y qué cubre.",
  "category": "Frontend",
  "keywords": ["react", "reactjs", "jsx", "hooks"],
  "seedColor": "0xFF61DAFB",
  "questionCount": 50,
  "exerciseCount": 10,
  "file": "react.json"
}
```

`keywords` son las formas alternativas que la gente escribe de verdad en el buscador. `seedColor` genera toda la paleta Material 3 de esa sección.

Los contadores deben coincidir con el contenido real: hay un test que lo comprueba.

### 2. Crea el fichero de contenido

`assets/content/react.json`, con tres secciones. Lo más rápido es copiar `flutter.json` y sustituir.

```jsonc
{
  "schemaVersion": 1,
  "technologyId": "react",
  "name": "React",
  "questions": [ /* ... */ ],
  "exercises": [ /* ... */ ],
  "roadmap": { "stages": [ /* ... */ ] }
}
```

---

## Esquema

### Pregunta

```jsonc
{
  "id": "react-q001",              // <tecnologia>-q<NNN>, único
  "level": "junior",               // junior | mid | senior
  "topic": "Hooks",                // agrupa los filtros: pocos y consistentes
  "tags": ["hooks", "estado"],
  "prompt": "¿Por qué no se pueden llamar hooks dentro de un if?",
  "answer": "Markdown. Admite código, listas y citas.",
  "rubric": {
    "junior": "Qué respondería alguien que acaba de empezar.",
    "mid":    "Qué añade alguien con experiencia.",
    "senior": "Qué demuestra criterio: compromisos, coste, contexto."
  },
  "followUps": ["La repregunta que vendría después"]
}
```

### Ejercicio

```jsonc
{
  "id": "react-e001",
  "title": "Título corto y concreto",
  "difficulty": "medium",          // easy | medium | hard
  "topic": "Rendimiento",
  "statement": "Markdown. Qué hay que construir y con qué requisitos.",
  "hints": ["Pista 1", "Pista 2"], // graduales: se revelan de una en una
  "approach": "El razonamiento: POR QUÉ esta solución y no otra.",
  "solutionSketch": "```jsx\n// código\n```",
  "complexity": "O(n) tiempo / O(1) memoria",
  "pitfalls": ["Dónde falla casi todo el mundo"]
}
```

### Etapa de la ruta

```jsonc
{
  "id": "react-s1",
  "level": "junior",
  "title": "Etapa 1 · Fundamentos",
  "estimatedWeeks": 10,
  "goal": "Qué sabes hacer al terminar esta etapa.",
  "skills": ["JSX", "Estado", "Props"],
  "milestones": [
    { "id": "react-m101", "title": "Hito concreto", "detail": "Cómo se hace y por qué importa." }
  ],
  "resources": [
    { "title": "React docs", "url": "https://react.dev", "kind": "docs" }
  ],
  "readinessSignals": ["Señal observable de que has superado la etapa"]
}
```

`kind`: `docs` · `article` · `video` · `book` · `course` · `repo`. Las URL deben ser `https`.

---

## Criterios de calidad del contenido

Esto es lo que diferencia este proyecto de una lista de preguntas más:

**Las respuestas explican el porqué, no solo el qué.** "Usa `const`" no vale. "Usa `const` porque el widget se canoniza y Flutter puede saltarse el subárbol al detectar la misma instancia" sí.

**La rúbrica marca tres niveles de verdad distintos.** No es la misma respuesta con más palabras. El junior describe, el mid explica el mecanismo, el senior habla de compromisos, coste y cuándo la respuesta habitual no aplica.

**Los ejercicios enseñan a pensar.** La sección `approach` es la más importante: debe explicar por qué esa solución y qué alternativas se descartaron. El código es lo de menos.

**Las etapas de la ruta tienen señales observables.** "Entiendes los hooks" no es verificable. "Explicas por qué un `useEffect` sin array de dependencias entra en bucle" sí.

**Ni humo ni dogma.** Si algo es discutible, dilo. Si una práctica tiene coste, nómbralo. Una respuesta que presenta una opinión como hecho es peor que no tenerla, porque el candidato la repetirá en una entrevista donde le pregunten por los inconvenientes.

**Nada copiado.** Escribe con tus palabras. El contenido se publica bajo CC BY-SA 4.0 y no podemos aceptar material con otra licencia.

---

## Antes de abrir el PR

```bash
flutter test      # valida el esquema, los ids únicos, los contadores y los enlaces
flutter analyze
dart format .
```

La suite de `test/content_test.dart` comprueba automáticamente que cada tecnología del índice tenga su fichero, que los contadores cuadren, que no haya ids duplicados ni campos vacíos, que la ruta cubra los tres niveles en orden y que los recursos sean `https`. Si pasa, el formato está bien; lo que sigue siendo cosa humana es la calidad de lo que dice.

---

## Contribuir al código

Bienvenido también. Las convenciones:

- La capa `domain/` **no importa Flutter**. Si tu cambio necesita hacerlo, probablemente va en otra capa.
- Toda lógica nueva en `domain/` viene con tests.
- `flutter analyze` sin avisos.
- Un PR, un tema.
