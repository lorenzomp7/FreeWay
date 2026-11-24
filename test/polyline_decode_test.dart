// Gira anche nel browser, come in CI:
//   flutter test --platform chrome test/polyline_decode_test.dart
// Sul web gli operatori sui bit lavorano a 32 bit senza segno: un decoder
// che passa sulla VM di Dart può dare punti sbagliati nell'app pubblicata.
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/services/routing_service.dart';
import 'package:latlong2/latlong.dart';

/// Codifica di prova, solo aritmetica (stesso risultato su VM e web).
String encode(List<LatLng> points, int precision) {
  final factor = precision == 5 ? 1e5 : 1e6;
  final out = StringBuffer();
  void write(int value) {
    var v = value < 0 ? -2 * value - 1 : 2 * value;
    while (v >= 32) {
      out.writeCharCode(32 + v % 32 + 63);
      v ~/= 32;
    }
    out.writeCharCode(v + 63);
  }

  var lat = 0;
  var lng = 0;
  for (final p in points) {
    final pLat = (p.latitude * factor).round();
    final pLng = (p.longitude * factor).round();
    write(pLat - lat);
    write(pLng - lng);
    lat = pLat;
    lng = pLng;
  }
  return out.toString();
}

void main() {
  test('esempio ufficiale di Google (precisione 5)', () {
    final points = RoutingService.decodePolyline(
      '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
      5,
    );
    expect(points, hasLength(3));
    expect(points[0].latitude, closeTo(38.5, 1e-9));
    expect(points[0].longitude, closeTo(-120.2, 1e-9));
    expect(points[1].latitude, closeTo(40.7, 1e-9));
    expect(points[1].longitude, closeTo(-120.95, 1e-9));
    expect(points[2].latitude, closeTo(43.252, 1e-9));
    expect(points[2].longitude, closeTo(-126.453, 1e-9));
  });

  test('percorso di prova con differenze negative (precisione 6)', () {
    // Tragitto di prova a Brescia: latitudine che scende, longitudine che
    // sale e scende, come in un percorso a piedi di Valhalla.
    const route = [
      LatLng(45.539782, 10.220075),
      LatLng(45.539501, 10.219880),
      LatLng(45.539120, 10.219991),
      LatLng(45.538734, 10.219402),
      LatLng(45.538100, 10.220012),
    ];
    final points = RoutingService.decodePolyline(encode(route, 6), 6);
    expect(points, hasLength(route.length));
    for (var i = 0; i < route.length; i++) {
      expect(points[i].latitude, closeTo(route[i].latitude, 1e-6));
      expect(points[i].longitude, closeTo(route[i].longitude, 1e-6));
    }
  });

  test('emisfero sud e ovest: coordinate negative e salti grandi', () {
    const route = [
      LatLng(-33.868820, 151.209296),
      LatLng(-34.603722, -58.381592),
      LatLng(64.146582, -21.942635),
      LatLng(0, 0),
    ];
    final points = RoutingService.decodePolyline(encode(route, 6), 6);
    expect(points, hasLength(route.length));
    for (var i = 0; i < route.length; i++) {
      expect(points[i].latitude, closeTo(route[i].latitude, 1e-6));
      expect(points[i].longitude, closeTo(route[i].longitude, 1e-6));
    }
  });

  test('una polilinea tronca o con caratteri non validi è scartata', () {
    expect(RoutingService.decodePolyline('_', 6), isEmpty);
    expect(RoutingService.decodePolyline('_p~iF ', 5), isEmpty);
  });
}
