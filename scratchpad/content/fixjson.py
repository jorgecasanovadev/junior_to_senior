"""Repara saltos de línea literales dentro de cadenas JSON y valida el esquema.

Escribir contenido largo a mano hace fácil teclear un salto real donde debía
ir \n. Esto lo detecta, une las dos líneas con el escape correcto y repite
hasta que el fichero parsea.
"""
import json
import sys
import pathlib


def reparar(path: pathlib.Path) -> list:
    texto = path.read_text()
    for _ in range(50):
        try:
            return json.loads(texto)
        except json.JSONDecodeError as e:
            if 'Invalid control character' not in e.msg:
                raise
            lineas = texto.split('\n')
            i = e.lineno - 1
            lineas[i] = lineas[i] + '\\n' + lineas[i + 1]
            del lineas[i + 1]
            texto = '\n'.join(lineas)
            path.write_text(texto)
            print(f'  reparado salto en la línea {e.lineno}')
    raise SystemExit('no se pudo reparar')


def main() -> None:
    for arg in sys.argv[1:]:
        path = pathlib.Path(arg)
        datos = reparar(path)
        if path.name.endswith('_ex.json'):
            campos = {'id', 'title', 'difficulty', 'topic', 'statement',
                      'hints', 'approach', 'solutionSketch', 'pitfalls'}
            for e in datos:
                faltan = campos - set(e)
                assert not faltan, f'{e["id"]}: faltan {faltan}'
            print(f'{path.name}: {len(datos)} ejercicios, esquema ok')
        else:
            for q in datos:
                assert set(q['rubric']) == {'junior', 'mid', 'senior'}, q['id']
                assert q['level'] in {'junior', 'mid', 'senior'}, q['id']
            print(f'{path.name}: {len(datos)} preguntas, esquema ok')


if __name__ == '__main__':
    main()
