/// Reads the curated, read-only content bundled in `assets/content/`.
///
/// Everything is loaded from the app bundle, so search and browsing work with
/// no network at all. Per-technology payloads are cached after the first read
/// because they never change at runtime.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../domain/models.dart';

class ContentRepository {
  ContentRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const _contentDir = 'assets/content';

  /// Personal guides, git-ignored. Optional: a fresh clone has no index here.
  static const _privateDir = 'assets/private';

  final AssetBundle _bundle;

  List<TechnologySummary>? _index;
  final Map<String, TechnologyContent> _cache = {};

  /// Directory each technology's file lives in, by id.
  final Map<String, String> _dirs = {};

  /// Private guides first: whoever added one is studying it right now.
  Future<List<TechnologySummary>> technologies() async {
    final cached = _index;
    if (cached != null) return cached;

    final private = await _readIndex(_privateDir, optional: true);
    final public = await _readIndex(_contentDir, optional: false);
    return _index = List.unmodifiable([...private, ...public]);
  }

  bool isPrivate(String technologyId) => _dirs[technologyId] == _privateDir;

  Future<List<TechnologySummary>> _readIndex(
    String dir, {
    required bool optional,
  }) async {
    final String raw;
    try {
      raw = await _bundle.loadString('$dir/index.json');
    } on Object {
      // The error type depends on the bundle (FlutterError for the app's,
      // FileSystemException for the tests'), so the missing file is
      // recognised by context: only the private index may be absent.
      if (optional) return const [];
      rethrow;
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final loaded = (json['technologies'] as List<dynamic>)
        .map(
          (entry) => TechnologySummary.fromJson(entry as Map<String, dynamic>),
        )
        .toList(growable: false);
    for (final technology in loaded) {
      _dirs[technology.id] = dir;
    }
    return loaded;
  }

  /// Ranked search over name, keywords, category and tagline. An empty query
  /// returns everything, alphabetically.
  Future<List<TechnologySummary>> search(String query) async {
    final all = await technologies();
    final scored = <(TechnologySummary, int)>[];
    for (final technology in all) {
      final score = technology.matchScore(query);
      if (score > 0) scored.add((technology, score));
    }
    scored.sort((a, b) {
      final byPrivate =
          (isPrivate(a.$1.id) ? 0 : 1) - (isPrivate(b.$1.id) ? 0 : 1);
      if (byPrivate != 0) return byPrivate;
      final byScore = b.$2.compareTo(a.$2);
      return byScore != 0 ? byScore : a.$1.name.compareTo(b.$1.name);
    });
    return scored.map((entry) => entry.$1).toList(growable: false);
  }

  Future<TechnologyContent> load(String technologyId) async {
    final cached = _cache[technologyId];
    if (cached != null) return cached;

    final all = await technologies();
    final summary = all.firstWhere(
      (technology) => technology.id == technologyId,
      orElse: () => throw ArgumentError('Unknown technology: $technologyId'),
    );

    final raw = await _bundle.loadString(
      '${_dirs[technologyId]}/${summary.file}',
    );
    final content = TechnologyContent.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    return _cache[technologyId] = content;
  }
}
