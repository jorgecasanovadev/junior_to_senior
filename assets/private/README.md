# Contenido privado

Esta carpeta está vacía a propósito: un `flutter build` normal genera la app
pública, sin guías personales.

Las guías personales (por ejemplo, la de una entrevista concreta) van en
`/private` en la raíz del repo, que está en `.gitignore`. Para compilar o
ejecutar con ellas:

```bash
tool/personal.sh run
tool/personal.sh build apk --release
```

El script las copia aquí solo mientras dura el comando y las borra al terminar.

Mismo formato que `assets/content/`: un `index.json` con la lista y un fichero
por guía. Si no hay `index.json`, la app funciona igual, solo sin guías
privadas. Las guías privadas salen las primeras en la portada.
