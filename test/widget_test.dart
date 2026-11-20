import 'package:bannercut/banner_canvas.dart';
import 'package:bannercut/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('edits material, places a manual piece and recalculates a plan', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const BannerCut());

    expect(find.text('Utilizarea materialului'), findsOneWidget);
    await tester.tap(find.text('Editează'));
    await tester.pumpAndSettle();

    final canvas = tester.getRect(find.byType(BannerCanvas));
    await tester.dragFrom(
      canvas.center - const Offset(75, 60),
      const Offset(35, 26),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Șterge zona 3'), findsOneWidget);
    expect(find.text('Utilizarea materialului'), findsNothing);

    await tester.tap(find.byTooltip('Șterge zona 3'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Șterge zona 3'), findsNothing);

    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();
    await tester.tapAt(canvas.center - const Offset(75, 57));
    await tester.pumpAndSettle();
    expect(find.textContaining('Următoarea piesă · Spate'), findsOneWidget);

    await tester.tap(find.text('Husă'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Optimizează planul'));
    await tester.pumpAndSettle();
    expect(find.text('Utilizarea materialului'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits a compact mobile screen and opens the demo menu', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const BannerCut());
    await tester.tap(find.byTooltip('Opțiuni proiect'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banner nou'));
    await tester.pumpAndSettle();
    expect(find.text('Banner nou'), findsOneWidget);
    expect(find.text('Utilizarea materialului'), findsNothing);

    final canvas = tester.getRect(find.byType(BannerCanvas));
    await tester.dragFrom(
      canvas.center - const Offset(55, 48),
      const Offset(24, 80),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Șterge zona 1'), findsOneWidget);

    await tester.ensureVisible(find.text('Optimizează planul'));
    await tester.tap(find.text('Optimizează planul'));
    await tester.pumpAndSettle();
    expect(find.text('Optimizat'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
