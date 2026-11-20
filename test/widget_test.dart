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

    expect(find.text('Material usage'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final canvas = tester.getRect(find.byType(BannerCanvas));
    await tester.dragFrom(
      canvas.center - const Offset(75, 60),
      const Offset(35, 26),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Delete area 3'), findsOneWidget);
    expect(find.text('Material usage'), findsNothing);

    await tester.tap(find.byTooltip('Delete area 3'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Delete area 3'), findsNothing);

    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();
    await tester.tapAt(canvas.center - const Offset(75, 57));
    await tester.pumpAndSettle();
    expect(find.textContaining('Next piece · Back'), findsOneWidget);

    await tester.tap(find.text('Sleeve'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Optimize plan'));
    await tester.pumpAndSettle();
    expect(find.text('Material usage'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits a compact mobile screen and opens the demo menu', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const BannerCut());
    await tester.tap(find.byTooltip('Project options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New banner'));
    await tester.pumpAndSettle();
    expect(find.text('New banner'), findsOneWidget);
    expect(find.text('Material usage'), findsNothing);

    final canvas = tester.getRect(find.byType(BannerCanvas));
    await tester.dragFrom(
      canvas.center - const Offset(55, 48),
      const Offset(24, 80),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Delete area 1'), findsOneWidget);

    await tester.ensureVisible(find.text('Optimize plan'));
    await tester.tap(find.text('Optimize plan'));
    await tester.pumpAndSettle();
    expect(find.text('Optimized'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'starts in English and switches languages without replacing the plan',
    (tester) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale('ro');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      await tester.binding.setSurfaceSize(const Size(1100, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const BannerCut());
      await tester.pumpAndSettle();

      final canvas = find.byType(BannerCanvas);
      final cuts = tester.widget<BannerCanvas>(canvas).cuts;
    Finder languageOption(String name) => find.ancestor(
      of: find.text(name),
      matching: find.byWidgetPredicate(
        (widget) => widget is CheckedPopupMenuItem<Object?>,
      ),
    );
      expect(cuts, isNotEmpty);
      expect(find.text('Cut list'), findsOneWidget);

      await tester.tap(find.byTooltip('Project options'));
      await tester.pumpAndSettle();
    await tester.tap(languageOption('Română'));
      await tester.pumpAndSettle();

      expect(find.text('Listă de tăiere'), findsOneWidget);
      expect(find.text('Optimizează planul'), findsOneWidget);
      expect(tester.widget<BannerCanvas>(canvas).cuts, same(cuts));

      await tester.tap(find.byTooltip('Opțiuni proiect'));
      await tester.pumpAndSettle();
    await tester.tap(languageOption('English'));
      await tester.pumpAndSettle();

      expect(find.text('Cut list'), findsOneWidget);
      expect(tester.widget<BannerCanvas>(canvas).cuts, same(cuts));
      expect(tester.takeException(), isNull);
    },
  );
}
