import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/services/two_finger_tap.dart';

void main() {
  Duration ms(int value) => Duration(milliseconds: value);

  test('due dita appoggiate e sollevate insieme: punto medio', () {
    final tap = TwoFingerTapDetector();
    tap.down(1, const Offset(100, 200), ms(0));
    tap.down(2, const Offset(200, 300), ms(20));
    expect(tap.up(1, ms(120)), isNull);
    expect(tap.up(2, ms(140)), const Offset(150, 250));
  });

  test('un dito solo non conta', () {
    final tap = TwoFingerTapDetector();
    tap.down(1, const Offset(10, 10), ms(0));
    expect(tap.up(1, ms(80)), isNull);
  });

  test('se le dita si spostano è un pizzico, non un tocco', () {
    final tap = TwoFingerTapDetector();
    tap.down(1, const Offset(100, 200), ms(0));
    tap.down(2, const Offset(200, 300), ms(10));
    tap.move(2, const Offset(260, 360));
    tap.up(1, ms(100));
    expect(tap.up(2, ms(110)), isNull);
  });

  test('troppo lento: le dita restano appoggiate', () {
    final tap = TwoFingerTapDetector();
    tap.down(1, const Offset(100, 200), ms(0));
    tap.down(2, const Offset(200, 300), ms(10));
    tap.up(1, ms(500));
    expect(tap.up(2, ms(520)), isNull);
  });

  test('tre dita non contano e il gesto dopo riparte da zero', () {
    final tap = TwoFingerTapDetector();
    tap.down(1, const Offset(0, 0), ms(0));
    tap.down(2, const Offset(10, 0), ms(5));
    tap.down(3, const Offset(20, 0), ms(10));
    tap.up(1, ms(50));
    tap.up(2, ms(60));
    expect(tap.up(3, ms(70)), isNull);

    tap.down(4, const Offset(0, 0), ms(1000));
    tap.down(5, const Offset(40, 0), ms(1010));
    tap.up(4, ms(1080));
    expect(tap.up(5, ms(1090)), const Offset(20, 0));
  });
}
