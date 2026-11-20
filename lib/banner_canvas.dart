import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'planner.dart';

const ink = Color(0xff182d25);
const muted = Color(0xff536960);
const paper = Color(0xfff4f7f2);
const line = Color(0xffdbe5de);
const green = Color(0xff234e3e);
const lime = Color(0xffdcf889);

class BannerCanvas extends StatefulWidget {
  const BannerCanvas({
    super.key,
    required this.sheet,
    required this.defects,
    required this.cuts,
    required this.photo,
    required this.editing,
    required this.onDefect,
    required this.onCut,
    this.onPlace,
  });

  final Size sheet;
  final List<Rect> defects;
  final List<Cut> cuts;
  final ui.Image? photo;
  final bool editing;
  final ValueChanged<Rect> onDefect;
  final ValueChanged<Cut> onCut;
  final ValueChanged<Offset>? onPlace;

  @override
  State<BannerCanvas> createState() => _BannerCanvasState();
}

class _BannerCanvasState extends State<BannerCanvas> {
  int? _pointer;
  Offset? _start;
  Rect? _draft;

  void _clearDrag() => setState(() {
    _pointer = null;
    _start = null;
    _draft = null;
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          (constraints.maxWidth - 44) / widget.sheet.width,
          (constraints.maxHeight - 44) / widget.sheet.height,
        );
        final size = widget.sheet * scale;
        final origin = Offset(
          (constraints.maxWidth - size.width) / 2 + 6,
          (constraints.maxHeight - size.height) / 2 + 5,
        );
        final bounds = origin & size;
        Offset toCm(Offset point) {
          final local = point - origin;
          return Offset(
            (local.dx / scale).roundToDouble().clamp(0, widget.sheet.width),
            (local.dy / scale).roundToDouble().clamp(0, widget.sheet.height),
          );
        }

        final sketch = CustomPaint(
          painter: _BannerPainter(
            bounds,
            scale,
            widget.sheet,
            widget.defects,
            widget.cuts,
            widget.photo,
            _draft,
          ),
          child: const SizedBox.expand(),
        );

        if (!widget.editing) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (event) {
              if (!bounds.contains(event.localPosition)) return;
              final place = widget.onPlace;
              if (place != null) {
                place(toCm(event.localPosition));
                return;
              }
              final point = (event.localPosition - origin) / scale;
              for (final cut in widget.cuts) {
                if (cut.rect.contains(point)) {
                  widget.onCut(cut);
                  break;
                }
              }
            },
            child: sketch,
          );
        }

        return Stack(
          children: [
            sketch,
            Positioned.fromRect(
              rect: bounds,
              child: RawGestureDetector(
                gestures: {
                  EagerGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        EagerGestureRecognizer
                      >(EagerGestureRecognizer.new, (_) {}),
                },
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) {
                    if (_pointer != null || event.buttons != kPrimaryButton) {
                      return;
                    }
                    _pointer = event.pointer;
                    _start = toCm(event.localPosition + origin);
                  },
                  onPointerMove: (event) {
                    if (event.pointer != _pointer) return;
                    setState(
                      () => _draft = Rect.fromPoints(
                        _start!,
                        toCm(event.localPosition + origin),
                      ),
                    );
                  },
                  onPointerUp: (event) {
                    if (event.pointer != _pointer) return;
                    final rect = Rect.fromPoints(
                      _start!,
                      toCm(event.localPosition + origin),
                    );
                    _clearDrag();
                    if (rect.width >= 2 && rect.height >= 2) {
                      widget.onDefect(rect);
                    }
                  },
                  onPointerCancel: (event) {
                    if (event.pointer == _pointer) _clearDrag();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BannerPainter extends CustomPainter {
  _BannerPainter(
    this.bounds,
    this.scale,
    this.sheet,
    this.defects,
    this.cuts,
    this.photo,
    this.draft,
  );

  final Rect bounds;
  final double scale;
  final Size sheet;
  final List<Rect> defects;
  final List<Cut> cuts;
  final ui.Image? photo;
  final Rect? draft;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xfff4f7f0), BlendMode.src);
    final dots = Paint()..color = const Color(0xffdbe5d9);
    for (var y = 8.0; y < size.height; y += 13) {
      for (var x = 8.0; x < size.width; x += 13) {
        canvas.drawCircle(Offset(x, y), .7, dots);
      }
    }
    canvas.drawRect(bounds.shift(const Offset(2, 3)), Paint()..color = line);
    canvas.drawRect(bounds, Paint()..color = const Color(0xfffcfff9));
    final image = photo;
    if (image != null) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        bounds,
        Paint()
          ..color = const Color(0x90ffffff)
          ..filterQuality = FilterQuality.medium,
      );
    }

    final grid = Paint()
      ..color = const Color(0xffdce6db)
      ..strokeWidth = .65;
    final step = _gridStep();
    for (var x = step; x < sheet.width; x += step) {
      final dx = bounds.left + x * scale;
      canvas.drawLine(Offset(dx, bounds.top), Offset(dx, bounds.bottom), grid);
      _label(canvas, '$x', Offset(dx, bounds.top - 11), 8, muted);
    }
    for (var y = step; y < sheet.height; y += step) {
      final dy = bounds.top + y * scale;
      canvas.drawLine(Offset(bounds.left, dy), Offset(bounds.right, dy), grid);
      _label(canvas, '$y', Offset(bounds.left - 11, dy), 8, muted);
    }
    canvas.drawRect(
      bounds,
      Paint()
        ..color = green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    _label(canvas, 'cm', bounds.topLeft - const Offset(12, 11), 8, muted);

    const colors = [
      (Color(0xffd6edb6), Color(0xff52703b)),
      (Color(0xffc6e5d6), Color(0xff356956)),
      (Color(0xfff1dfa8), Color(0xff806839)),
      (Color(0xffdce5fb), Color(0xff526d9a)),
    ];
    for (final cut in cuts) {
      final rect = _project(cut.rect).deflate(.45);
      if (rect.isEmpty) continue;
      final (fill, outline) = colors[cut.pieceIndex % colors.length];
      canvas.drawRect(rect, Paint()..color = fill.withValues(alpha: .91));
      canvas.drawRect(
        rect,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke,
      );
      if (rect.width >= 24 && rect.height >= 13) {
        _label(canvas, cut.code, rect.center, 10, outline, bold: true);
      }
    }
    for (final defect in [...defects, ?draft]) {
      final rect = _project(defect);
      canvas.drawRect(rect, Paint()..color = const Color(0xfff9ddd3));
      canvas.save();
      canvas.clipRect(rect);
      final stripe = Paint()
        ..color = const Color(0xffe69f88)
        ..strokeWidth = 1;
      for (var dx = -rect.height; dx < rect.width; dx += 7) {
        canvas.drawLine(
          Offset(rect.left + dx, rect.bottom),
          Offset(rect.left + dx + rect.height, rect.top),
          stripe,
        );
      }
      canvas.restore();
      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0xffbb6048)
          ..style = PaintingStyle.stroke,
      );
    }
  }

  int _gridStep() {
    for (final step in [5, 10, 20, 25, 50, 100, 200, 500]) {
      if (step * scale >= 34) return step;
    }
    return 1000;
  }

  Rect _project(Rect rect) => Rect.fromLTWH(
    bounds.left + rect.left * scale,
    bounds.top + rect.top * scale,
    rect.width * scale,
    rect.height * scale,
  );

  void _label(
    Canvas canvas,
    String text,
    Offset center,
    double size,
    Color color, {
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
    painter.dispose();
  }

  @override
  bool shouldRepaint(_BannerPainter oldDelegate) => true;
}
