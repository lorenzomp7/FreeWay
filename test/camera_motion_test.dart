import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/services/camera_motion.dart';
import 'package:latlong2/latlong.dart';

void main() {
  // Luoghi di prova: due piazze vicine a Brescia e un punto lontano.
  const loggia = LatLng(45.5396, 10.2187);
  const vittoria = LatLng(45.5381, 10.2200);
  const roma = LatLng(41.9028, 12.4964);

  void expectStep(CameraStep actual, CameraStep expected) {
    expect(actual.center.latitude, closeTo(expected.center.latitude, 1e-9));
    expect(actual.center.longitude, closeTo(expected.center.longitude, 1e-9));
    expect(actual.zoom, closeTo(expected.zoom, 1e-9));
  }

  group('interpolateCamera', () {
    const from = CameraStep(loggia, 13);
    const to = CameraStep(vittoria, 17);

    test('agli estremi restituisce partenza e arrivo', () {
      expectStep(interpolateCamera(from, to, 0), from);
      expectStep(interpolateCamera(from, to, 1), to);
      // Le curve con rimbalzo possono uscire da 0..1.
      expectStep(interpolateCamera(from, to, -0.2), from);
      expectStep(interpolateCamera(from, to, 1.3), to);
    });

    test('a metà lo zoom è a metà e il centro è tra i due punti', () {
      final mid = interpolateCamera(from, to, 0.5);
      expect(mid.zoom, closeTo(15, 1e-9));
      expect(mid.center.longitude, closeTo((10.2187 + 10.2200) / 2, 1e-9));
      expect(mid.center.latitude, lessThan(loggia.latitude));
      expect(mid.center.latitude, greaterThan(vittoria.latitude));
    });

    test('sull\'equatore il centro si muove in linea retta', () {
      const a = CameraStep(LatLng(0, 10), 5);
      const b = CameraStep(LatLng(0, 20), 5);
      final quarter = interpolateCamera(a, b, 0.25);
      expect(quarter.center.latitude, closeTo(0, 1e-9));
      expect(quarter.center.longitude, closeTo(12.5, 1e-9));
    });

    test('attraverso l\'antimeridiano passa dalla strada più corta', () {
      const a = CameraStep(LatLng(0, 179), 5);
      const b = CameraStep(LatLng(0, -179), 5);
      final mid = interpolateCamera(a, b, 0.5);
      expect(mid.center.longitude.abs(), closeTo(180, 1e-6));
    });
  });

  group('shouldAnimateCamera', () {
    test('anima uno spostamento vicino', () {
      expect(
        shouldAnimateCamera(
          const CameraStep(loggia, 16),
          const CameraStep(vittoria, 17),
          390,
          844,
        ),
        isTrue,
      );
    });

    test('anima un cambio di zoom sul posto (pulsanti + e -)', () {
      expect(
        shouldAnimateCamera(
          const CameraStep(loggia, 15),
          const CameraStep(loggia, 16),
          390,
          844,
        ),
        isTrue,
      );
    });

    test('salta direttamente verso una meta lontana', () {
      expect(
        shouldAnimateCamera(
          const CameraStep(loggia, 17),
          const CameraStep(roma, 17),
          1280,
          800,
        ),
        isFalse,
      );
    });

    test('non anima se la mappa è già lì o se lo schermo non ha misure', () {
      const here = CameraStep(loggia, 17);
      expect(shouldAnimateCamera(here, here, 390, 844), isFalse);
      expect(
        shouldAnimateCamera(here, const CameraStep(vittoria, 17), 0, 0),
        isFalse,
      );
    });
  });
}
