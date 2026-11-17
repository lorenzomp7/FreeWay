import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Versione dell'SDK Firebase JS usata dal plugin firebase_core_web, letta dal
/// suo sorgente (è in un file interno che non si può importare).
String pluginFirebaseSdkVersion() {
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final package = (config['packages'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((p) => p['name'] == 'firebase_core_web');
  var rootUri = package['rootUri'] as String;
  if (!rootUri.endsWith('/')) rootUri = '$rootUri/';
  final root = Uri.parse('.dart_tool/').resolve(rootUri);
  final source = File.fromUri(
    root.resolve('lib/src/firebase_sdk_version.dart'),
  ).readAsStringSync();
  return RegExp(r"supportedFirebaseJsSdkVersion = '([0-9.]+)'")
      .firstMatch(source)!
      .group(1)!;
}

void main() {
  final html = File('web/index.html').readAsStringSync();

  test('i modulepreload di web/index.html usano la versione SDK del plugin', () {
    final expected = pluginFirebaseSdkVersion();
    final versions = RegExp(r'gstatic\.com/firebasejs/([0-9.]+)/')
        .allMatches(html)
        .map((m) => m.group(1))
        .toSet();
    expect(versions, {expected},
        reason: 'Aggiorna i <link rel="modulepreload"> in web/index.html '
            'alla versione $expected');
  });

  test('la schermata di avvio HTML viene rimossa al primo frame', () {
    expect(html, contains('id="splash"'));
    expect(html, contains("'flutter-first-frame'"));
  });
}
