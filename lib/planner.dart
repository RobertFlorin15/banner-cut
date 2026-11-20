import 'dart:math' as math;
import 'dart:ui';

enum PieceKind { front, back, handleA, handleB, flap }

class Piece {
  const Piece(this.kind, this.width, this.height);
  final PieceKind kind;
  final double width;
  final double height;
}

enum Pattern {
  tote([
    Piece(PieceKind.front, 30, 34),
    Piece(PieceKind.back, 30, 34),
    Piece(PieceKind.handleA, 5, 50),
    Piece(PieceKind.handleB, 5, 50),
  ]),
  sleeve([
    Piece(PieceKind.front, 24, 32),
    Piece(PieceKind.back, 24, 32),
    Piece(PieceKind.flap, 24, 9),
  ]);

  const Pattern(this.pieces);
  final List<Piece> pieces;
}

class Cut {
  const Cut(this.pieceIndex, this.kit, this.rect);
  final int pieceIndex;
  final int kit;
  final Rect rect;
  String get code => '$kit${String.fromCharCode(65 + pieceIndex)}';
}

class CutPlan {
  const CutPlan(this.cuts, this.kits);
  static const empty = CutPlan([], 0);

  final List<Cut> cuts;
  final int kits;

  double get area =>
      cuts.fold(0, (total, cut) => total + cut.rect.width * cut.rect.height);
}

class Planner {
  Planner(this.size, Iterable<Rect> defects, this.pattern, this.margin)
    : defects = defects
          .map((rect) => rect.intersect(Offset.zero & size))
          .where((rect) => !rect.isEmpty)
          .toList(growable: false);

  final Size size;
  final List<Rect> defects;
  final Pattern pattern;
  final double margin;

  double get usableArea {
    final edges = {
      for (final fault in defects) ...[fault.left, fault.right],
    }.toList()..sort();
    var waste = 0.0;
    for (var i = 1; i < edges.length; i++) {
      final left = edges[i - 1];
      final right = edges[i];
      final active =
          defects
              .where((rect) => rect.left < right && rect.right > left)
              .toList()
            ..sort((a, b) => a.top.compareTo(b.top));
      var bottom = 0.0;
      for (final rect in active) {
        waste +=
            (right - left) *
            math.max(0, rect.bottom - math.max(bottom, rect.top));
        bottom = math.max(bottom, rect.bottom);
      }
    }
    return math.max(0, size.width * size.height - waste);
  }

  double usage(CutPlan plan) => usableArea == 0 ? 0 : plan.area / usableArea;

  CutPlan baseline(int limit) => _pack(
    limit,
    List.generate(pattern.pieces.length, (index) => index),
    _Fit.topLeft,
    rotate: false,
  );

  CutPlan optimize(int limit, {CutPlan? initial}) {
    final natural = List.generate(pattern.pieces.length, (index) => index);
    final byArea = [...natural]
      ..sort((a, b) {
        final first = pattern.pieces[a];
        final second = pattern.pieces[b];
        return (second.width * second.height).compareTo(
          first.width * first.height,
        );
      });
    final byLength = [...natural]
      ..sort((a, b) {
        final first = pattern.pieces[a];
        final second = pattern.pieces[b];
        return math
            .max(second.width, second.height)
            .compareTo(math.max(first.width, first.height));
      });
    var best = initial ?? baseline(limit);
    for (final order in [natural, byArea, byLength]) {
      for (final rule in _Fit.values) {
        if (best.kits == limit) return best;
        final candidate = _pack(limit, order, rule, rotate: true);
        if (candidate.kits > best.kits) best = candidate;
      }
    }
    return best;
  }

  bool canPlace(Rect rect, Iterable<Cut> others) =>
      (Offset.zero & size).intersect(rect) == rect &&
      !defects.any(rect.overlaps) &&
      !others.any((other) => rect.overlaps(other.rect));

  Rect pieceAt(int index, Offset origin, {required bool rotate}) {
    final piece = pattern.pieces[index];
    final width = piece.width + 2 * margin;
    final height = piece.height + 2 * margin;
    return _at(origin, rotate ? height : width, rotate ? width : height);
  }

  CutPlan _pack(int limit, List<int> order, _Fit rule, {required bool rotate}) {
    var free = [Offset.zero & size];
    for (final defect in defects) {
      free = _subtract(free, defect);
    }
    final cuts = <Cut>[];
    for (var kit = 1; kit <= limit; kit++) {
      final pending = <Cut>[];
      for (final index in order) {
        final piece = pattern.pieces[index];
        final width = piece.width + 2 * margin;
        final height = piece.height + 2 * margin;
        final rect = _findSpace(free, width, height, rule, rotate);
        if (rect == null) return CutPlan(cuts, kit - 1);
        pending.add(Cut(index, kit, rect));
        free = _subtract(free, rect);
      }
      cuts.addAll(pending);
    }
    return CutPlan(cuts, limit);
  }
}

enum _Fit { topLeft, shortSide, remainingArea }

Rect? _findSpace(
  List<Rect> spaces,
  double width,
  double height,
  _Fit rule,
  bool rotate,
) {
  Rect? best;
  var score = double.infinity;
  for (final space in spaces) {
    for (final (w, h) in [
      (width, height),
      if (rotate && width != height) (height, width),
    ]) {
      final candidate = _at(space.topLeft, w, h);
      if (candidate.right > space.right || candidate.bottom > space.bottom) {
        continue;
      }
      final value = switch (rule) {
        _Fit.topLeft => candidate.bottom,
        _Fit.shortSide => math.min(space.width - w, space.height - h),
        _Fit.remainingArea => space.width * space.height - w * h,
      };
      if (best == null ||
          value < score ||
          (value == score &&
              (candidate.top < best.top ||
                  (candidate.top == best.top && candidate.left < best.left)))) {
        best = candidate;
        score = value;
      }
    }
  }
  return best;
}

Rect _at(Offset origin, double width, double height) => Rect.fromLTRB(
  origin.dx,
  origin.dy,
  ((origin.dx + width) * 10).round() / 10,
  ((origin.dy + height) * 10).round() / 10,
);

List<Rect> _subtract(List<Rect> spaces, Rect occupied) {
  final split = <Rect>{};
  for (final space in spaces) {
    if (!space.overlaps(occupied)) {
      split.add(space);
      continue;
    }
    if (occupied.left > space.left) {
      split.add(
        Rect.fromLTRB(space.left, space.top, occupied.left, space.bottom),
      );
    }
    if (occupied.right < space.right) {
      split.add(
        Rect.fromLTRB(occupied.right, space.top, space.right, space.bottom),
      );
    }
    if (occupied.top > space.top) {
      split.add(
        Rect.fromLTRB(space.left, space.top, space.right, occupied.top),
      );
    }
    if (occupied.bottom < space.bottom) {
      split.add(
        Rect.fromLTRB(space.left, occupied.bottom, space.right, space.bottom),
      );
    }
  }
  final unique = split.toList();
  return unique
      .where(
        (inner) => !unique.any(
          (outer) =>
              outer != inner &&
              outer.left <= inner.left &&
              outer.top <= inner.top &&
              outer.right >= inner.right &&
              outer.bottom >= inner.bottom,
        ),
      )
      .toList();
}
