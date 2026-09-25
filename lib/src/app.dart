import 'package:flutter/material.dart';

import 'core/router.dart';
import 'core/theme.dart';

class JuniorToSeniorApp extends StatelessWidget {
  const JuniorToSeniorApp({super.key});

  /// Default seed; each technology screen overrides it with its own brand
  /// colour.
  static const _seed = Color(0xFF3B5BDB);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'JuniorToSenior',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: buildTheme(seed: _seed, brightness: Brightness.light),
      darkTheme: buildTheme(seed: _seed, brightness: Brightness.dark),
    );
  }
}
