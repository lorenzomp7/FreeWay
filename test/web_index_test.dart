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

  test('l\'anteprima del link punta a un\'immagine 1280x640 pubblicata', () {
    String? meta(String property) => RegExp(
          '<meta property="$property" content="([^"]+)">',
        ).firstMatch(html)?.group(1);
    const site = 'https://lorenzomp7.github.io/FreeWay/';
    final image = meta('og:image');
    // Le anteprime di WhatsApp e LinkedIn leggono solo indirizzi assoluti.
    expect(image, startsWith(site));
    expect(meta('og:url'), site);
    expect(meta('og:title'), isNotEmpty);
    expect(html, contains('<meta name="twitter:card" '
        'content="summary_large_image">'));

    // L'immagine è in web/, così flutter build la copia nel sito.
    final file = File('web/${image!.substring(site.length)}');
    expect(file.existsSync(), isTrue, reason: '${file.path} mancante');
    final png = file.readAsBytesSync();
    // Intestazione PNG: larghezza e altezza nel blocco IHDR (big endian).
    int readInt(int offset) =>
        png.sublist(offset, offset + 4).fold(0, (v, b) => (v << 8) | b);
    expect(png.sublist(1, 4), utf8.encode('PNG'));
    expect([readInt(16), readInt(20)], [1280, 640]);
    expect(meta('og:image:width'), '1280');
    expect(meta('og:image:height'), '640');
  });
}
