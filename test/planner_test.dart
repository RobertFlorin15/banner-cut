import 'dart:ui';

import 'package:bannercut/planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overlapping defects subtract only their combined footprint', () {
    final planner = Planner(
      const Size(100, 80),
      const [Rect.fromLTWH(-10, 0, 30, 20), Rect.fromLTWH(10, 10, 20, 30)],
      Pattern.sleeve,
      1,
    );
    expect(planner.usableArea, 7100);
  });

  test('rotation can fit a complete set in a narrow strip', () {
    final planner = Planner(const Size(35, 90), [], Pattern.sleeve, 1);
    expect(planner.baseline(1).kits, 1);
    final narrower = Planner(const Size(34, 74), [], Pattern.sleeve, 1);
    expect(narrower.baseline(1).kits, 0);
    expect(narrower.optimize(1).kits, 1);
  });

  test(
    'plans contain complete, non-overlapping kits and include seam allowance',
    () {
      for (final template in Pattern.values) {
        for (final margin in [0.0, .3, 1.0, 5.0]) {
          final planner = Planner(
            const Size(181.3, 116.1),
            const [Rect.fromLTWH(0, 0, 22, 24), Rect.fromLTWH(114, 69, 19, 17)],
            template,
            margin,
          );
          final reference = planner.baseline(12);
          final optimized = planner.optimize(12, initial: reference);
          expect(optimized.kits, greaterThanOrEqualTo(reference.kits));
          expect(optimized.kits, greaterThan(0));
          expect(
            optimized.cuts.length,
            optimized.kits * template.pieces.length,
          );
          for (final part in optimized.cuts) {
            final shape = template.pieces[part.pieceIndex];
            expect(
              planner.canPlace(
                part.rect,
                optimized.cuts.where((other) => other != part),
              ),
              isTrue,
            );
            final cutArea =
                (shape.width + 2 * margin) * (shape.height + 2 * margin);
            expect(part.rect.width * part.rect.height, closeTo(cutArea, .001));
          }
        }
      }
    },
  );

  test('a kit that cannot fit leaves no partial pieces', () {
    final planner = Planner(const Size(35, 35), [], Pattern.tote, 1);
    expect(planner.optimize(12).cuts, isEmpty);
    final blocked = Planner(
      const Size(35, 35),
      [const Rect.fromLTWH(0, 0, 35, 35)],
      Pattern.tote,
      1,
    );
    expect(blocked.usage(blocked.optimize(12)), 0);
  });

  test('the built-in example improves on the unrotated reference', () {
    final planner = Planner(
      const Size(147, 107),
      const [Rect.fromLTWH(0, 0, 22, 24), Rect.fromLTWH(114, 69, 19, 17)],
      Pattern.tote,
      1,
    );
    expect(planner.optimize(12).kits, greaterThan(planner.baseline(12).kits));
  });
}
