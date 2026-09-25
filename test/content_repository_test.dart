import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junior_to_senior/src/data/content_repository.dart';

/// Serves an in-memory set of files; anything else is "not found".
class _MapBundle extends CachingAssetBundle {
  _MapBundle(this.files);

  final Map<String, Object> files;

  @override
  Future<ByteData> load(String key) async {
    final file = files[key];
    if (file == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(
      Uint8List.fromList(utf8.encode(jsonEncode(file))),
    );
  }
}

Map<String, Object> _index(String id, String name) => {
  'technologies': [
    {
      'id': id,
      'name': name,
      'tagline': '',
      'category': '',
      'keywords': <String>[],
      'seedColor': '0xFF000000',
      'questionCount': 0,
      'exerciseCount': 0,
      'file': '$id.json',
    },
  ],
};

Map<String, Object> _content(String id) => {
  'technologyId': id,
  'name': id,
  'questions': <Object>[],
  'exercises': <Object>[],
  'roadmap': {'stages': <Object>[]},
};

void main() {
  test('sin índice privado, solo el contenido público', () async {
    final repository = ContentRepository(
      bundle: _MapBundle({'assets/content/index.json': _index('dart', 'Dart')}),
    );
    final ids = (await repository.technologies()).map((t) => t.id);
    expect(ids, ['dart']);
  });

  test('las guías privadas van primero y cargan de su carpeta', () async {
    final repository = ContentRepository(
      bundle: _MapBundle({
        'assets/content/index.json': _index('dart', 'Dart'),
        'assets/private/index.json': _index('mia', 'Zeta privada'),
        'assets/private/mia.json': _content('mia'),
      }),
    );
    expect((await repository.search('')).map((t) => t.id), ['mia', 'dart']);
    expect(repository.isPrivate('mia'), isTrue);
    expect((await repository.load('mia')).id, 'mia');
  });

  test('si falta el índice público, falla en voz alta', () async {
    final repository = ContentRepository(bundle: _MapBundle({}));
    expect(repository.technologies(), throwsA(anything));
  });
}
