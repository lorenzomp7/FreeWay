import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/theme/motion.dart';
import 'package:freeway/widgets/common.dart';

void main() {
  /// App di prova con «Riduci movimento» attivo o no.
  Widget app({required bool reduced, required WidgetBuilder builder}) {
    return MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: Scaffold(body: Builder(builder: builder)),
    );
  }

  testWidgets('senza «Riduci movimento» valgono le durate dell\'app', (
    tester,
  ) async {
    late BuildContext captured;
    await tester.pumpWidget(
      app(
        reduced: false,
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    );
    expect(AppMotion.reduced(captured), isFalse);
    expect(AppMotion.of(captured, AppMotion.quick), AppMotion.quick);
    expect(AppMotion.routeStyle(captured), isNull);
  });

  testWidgets('con «Riduci movimento» i passaggi sono immediati', (
    tester,
  ) async {
    late BuildContext captured;
    await tester.pumpWidget(
      app(
        reduced: true,
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    );
    expect(AppMotion.reduced(captured), isTrue);
    expect(AppMotion.of(captured, AppMotion.standard), Duration.zero);
    expect(AppMotion.routeStyle(captured), AnimationStyle.noAnimation);
  });

  testWidgets('con «Riduci movimento» il bottom sheet è subito al suo posto', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        reduced: true,
        builder: (context) => TextButton(
          onPressed: () => showAppBottomSheet<void>(
            context,
            (_) => const Text('Contenuto di prova'),
          ),
          child: const Text('Apri'),
        ),
      ),
    );
    await tester.tap(find.text('Apri'));
    await tester.pump();
    // Dopo un solo frame il contenuto è già dove resterà: non sale dal basso.
    final content = find.text('Contenuto di prova');
    expect(content, findsOneWidget);
    final first = tester.getRect(content);
    await tester.pumpAndSettle();
    expect(tester.getRect(content), first);
  });

  test('le durate sono brevi e in ordine crescente', () {
    expect(AppMotion.quick, lessThan(AppMotion.standard));
    expect(AppMotion.standard, lessThan(AppMotion.camera));
    expect(AppMotion.camera.inMilliseconds, lessThanOrEqualTo(500));
  });
}
