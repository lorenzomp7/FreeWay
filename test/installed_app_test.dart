import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/main.dart';
import 'package:freeway/theme/app_theme.dart';

/// App installata dal browser: schermo intero, barre senza il rosso del
/// marchio e icone FreeWay al posto di quelle di Flutter.
void main() {
  final manifest = jsonDecode(File('web/manifest.json').readAsStringSync())
      as Map<String, dynamic>;
  final html = File('web/index.html').readAsStringSync();

  test('le barre prendono lo sfondo dell\'app, non il rosso', () {
    expect(systemBarColor(Brightness.dark), AppColors.dark.background);
    expect(systemBarColor(Brightness.light), AppColors.light.background);
    expect(systemBarColor(Brightness.dark), isNot(AppPalette.primary));
    expect(systemBarColor(Brightness.light), isNot(AppPalette.primary));
  });

  test('l\'app installata si apre a schermo intero', () {
    expect(manifest['display'], 'fullscreen');
    // Dove lo schermo intero non c'è (iPhone) si ripiega su standalone.
    expect(manifest['display_override'], ['fullscreen', 'standalone']);
  });

  test('manifest e pagina non colorano più le barre di rosso', () {
    expect(manifest['theme_color'], isNot('#EC0414'));
    final themeColors = RegExp(r'<meta name="theme-color"[^>]*content="([^"]+)"')
        .allMatches(html)
        .map((m) => m.group(1)!.toUpperCase())
        .toList();
    expect(themeColors, isNotEmpty);
    expect(themeColors, isNot(contains('#EC0414')));
  });

  test('le icone esistono e hanno le misure dichiarate', () {
    for (final icon in (manifest['icons'] as List).cast<Map>()) {
      final file = File('web/${icon['src']}');
      expect(file.existsSync(), isTrue, reason: '${icon['src']} manca');
      final bytes = file.readAsBytesSync();
      // Larghezza e altezza stanno nell'intestazione IHDR del PNG.
      final data = ByteData.sublistView(bytes);
      final size = '${data.getUint32(16)}x${data.getUint32(20)}';
      expect(size, icon['sizes'], reason: '${icon['src']}');
    }
    expect(html, contains('href="icons/apple-touch-icon.png"'));
    expect(File('web/icons/apple-touch-icon.png').existsSync(), isTrue);
  });
}
