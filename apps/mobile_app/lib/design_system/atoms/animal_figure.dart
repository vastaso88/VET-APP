import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The flat drawings of the app, one per kind of animal. [paw] is the neutral
/// one, for an animal without a drawing of its own.
enum AnimalFigure { dog, cat, rabbit, smallMammal, bird, reptile, fish, paw }

/// An [AnimalFigure] in one flat colour. Eyes and noses are holes: what is
/// under the figure shows, so it can sit on any ground.
class AnimalFigureIcon extends StatelessWidget {
  const AnimalFigureIcon(
    this.figure, {
    super.key,
    required this.size,
    required this.color,
    this.accent,
  });

  final AnimalFigure figure;

  /// Side on screen, in logical pixels.
  final double size;
  final Color color;

  /// The second colour, for the beak; [color] when absent.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _AnimalPainter(figure, color, accent ?? color),
      ),
    );
  }
}

class _AnimalPainter extends CustomPainter {
  const _AnimalPainter(this.figure, this.color, this.accent);

  final AnimalFigure figure;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.shortestSide / _box);
    final drawing = _drawings[figure] ??= _draw(figure);
    canvas.drawPath(drawing.body, Paint()..color = color);
    if (drawing.beak case final beak?) canvas.drawPath(beak, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_AnimalPainter old) =>
      old.figure != figure || old.color != color || old.accent != accent;
}

/// The side of the box the drawings are made in.
const _box = 32.0;

typedef _Drawing = ({Path body, Path? beak});

final _drawings = <AnimalFigure, _Drawing>{};

_Drawing _draw(AnimalFigure figure) => switch (figure) {
      AnimalFigure.dog => (body: _dog(), beak: null),
      AnimalFigure.cat => (body: _cat(), beak: null),
      AnimalFigure.rabbit => (body: _rabbit(), beak: null),
      AnimalFigure.smallMammal => (body: _smallMammal(), beak: null),
      AnimalFigure.bird => (body: _bird(), beak: _beak()),
      AnimalFigure.reptile => (body: _reptile(), beak: null),
      AnimalFigure.fish => (body: _fish(), beak: null),
      AnimalFigure.paw => (body: _paw(), beak: null),
    };

/// An ellipse, turned clockwise by [degrees] around its centre.
Path _oval(double x, double y, double rx, double ry, [double degrees = 0]) {
  final oval = Path()
    ..addOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2));
  return oval.transform(
    (Matrix4.translationValues(x, y, 0)..rotateZ(degrees * math.pi / 180)).storage,
  );
}

Path _join(List<Path> parts) =>
    parts.reduce((all, part) => Path.combine(PathOperation.union, all, part));

Path _cut(Path from, List<Path> holes) => Path.combine(PathOperation.difference, from, _join(holes));

Path _dog() {
  final head = _join([_oval(16, 15.4, 8.8, 8.8), _oval(16, 21.4, 6.4, 6)]);
  final ears = [_oval(6.5, 15.2, 3.5, 7.6, 14), _oval(25.5, 15.2, 3.5, 7.6, -14)];
  // A thin gap around the ears, which hang over the head.
  final gap = [_oval(6.5, 15.2, 4.6, 8.7, 14), _oval(25.5, 15.2, 4.6, 8.7, -14)];
  final face = _cut(head, [
    ...gap,
    _oval(12.9, 14.6, 1.4, 1.6),
    _oval(19.1, 14.6, 1.4, 1.6),
    _oval(16, 20.2, 2.5, 1.9),
  ]);
  return _join([face, ...ears]);
}

Path _cat() {
  final head = Path()
    ..moveTo(4.8, 18)
    ..cubicTo(4.8, 15, 5.6, 12.4, 5.8, 10)
    ..lineTo(5.4, 4.6)
    ..quadraticBezierTo(5.5, 2.6, 7.4, 3.8)
    ..lineTo(12.4, 7.4)
    ..quadraticBezierTo(16, 6.4, 19.6, 7.4)
    ..lineTo(24.6, 3.8)
    ..quadraticBezierTo(26.5, 2.6, 26.6, 4.6)
    ..lineTo(26.2, 10)
    ..cubicTo(26.4, 12.4, 27.2, 15, 27.2, 18)
    ..cubicTo(27.2, 24, 22.4, 27.8, 16, 27.8)
    ..cubicTo(9.6, 27.8, 4.8, 24, 4.8, 18)
    ..close();
  final nose = Path()
    ..moveTo(13.9, 20.2)
    ..quadraticBezierTo(16, 19.4, 18.1, 20.2)
    ..quadraticBezierTo(17.5, 22, 16, 22.6)
    ..quadraticBezierTo(14.5, 22, 13.9, 20.2)
    ..close();
  return _cut(head, [
    _oval(11.2, 16, 1.6, 2.1),
    _oval(20.8, 16, 1.6, 2.1),
    nose,
    for (final (y, turn) in const [(20.2, 6.0), (23.2, -8.0)]) ...[
      _oval(5.6, y, 4.2, 0.55, turn),
      _oval(26.4, y, 4.2, 0.55, -turn),
    ],
  ]);
}

Path _rabbit() => _cut(
      _join([
        _oval(16, 21, 8.8, 7.6),
        _oval(11.2, 9.4, 3.2, 8.2, -10),
        _oval(20.8, 9.4, 3.2, 8.2, 10),
      ]),
      [
        _oval(11, 8.8, 1.1, 4.8, -10),
        _oval(21, 8.8, 1.1, 4.8, 10),
        _oval(12.4, 20, 1.5, 1.6),
        _oval(19.6, 20, 1.5, 1.6),
        _oval(16, 23.6, 1.7, 1.2),
      ],
    );

Path _smallMammal() {
  final teeth = Path()
    ..addRRect(RRect.fromLTRBR(14.5, 22.6, 17.5, 25.4, const Radius.circular(0.7)));
  return _cut(
    _join([
      _oval(16, 16.4, 9.8, 8.8),
      _oval(16, 20.4, 12.2, 7.2),
      _oval(8, 9.6, 3.1, 3.1),
      _oval(24, 9.6, 3.1, 3.1),
    ]),
    [
      _oval(10.8, 15.6, 1.6, 1.8),
      _oval(21.2, 15.6, 1.6, 1.8),
      _oval(16, 19.8, 1.9, 1.3),
      teeth,
    ],
  );
}

Path _bird() {
  final tail = Path()
    ..moveTo(8.6, 19.6)
    ..lineTo(3, 26.6)
    ..quadraticBezierTo(2.4, 28.4, 4.4, 28.4)
    ..lineTo(14, 26.4)
    ..close();
  // The edge of the wing: what a second oval leaves of the first.
  final wing = _cut(_oval(12, 19, 4.2, 6.4, 32), [_oval(11, 18.1, 4.2, 6.4, 32)]);
  return _cut(
    _join([_oval(18.2, 10, 5.8, 5.8), _oval(14.6, 18.2, 7.4, 8.8, 26), tail]),
    [wing, _oval(19.8, 9, 1.4, 1.4)],
  );
}

Path _beak() => Path()
  ..moveTo(24.4, 8)
  ..quadraticBezierTo(29, 9.2, 29.6, 10.8)
  ..quadraticBezierTo(28.6, 12.2, 24.2, 12.4)
  ..close();

Path _reptile() {
  final tail = Path()
    ..moveTo(13, 19)
    ..cubicTo(13.6, 25, 16.4, 29.8, 22, 29.8)
    ..cubicTo(26.4, 29.8, 28.6, 26.6, 28, 23.4)
    ..cubicTo(27.6, 21.6, 25.2, 21.6, 24.8, 23.4)
    ..cubicTo(25, 25.4, 24, 26.6, 22.2, 26.6)
    ..cubicTo(20, 26.6, 19, 23.4, 19, 19)
    ..close();
  Path limb(double x, double y, double reach, double turn) => _oval(x, y, reach, 1.5, turn);
  return _cut(
    _join([
      _oval(16, 6.6, 4.2, 4.8),
      _oval(16, 14.4, 4.4, 7.6),
      tail,
      for (final side in const [-1.0, 1.0]) ...[
        limb(16 + side * 5.8, 11.4, 4.4, side * -14),
        limb(16 + side * 9.2, 9, 3.2, side * -64),
        limb(16 + side * 5.8, 18.6, 4.4, side * 14),
        limb(16 + side * 9.2, 21.2, 3.2, side * 64),
      ],
    ]),
    [_oval(13.9, 5.6, 1, 1.2), _oval(18.1, 5.6, 1, 1.2)],
  );
}

Path _fish() {
  final body = Path()
    ..moveTo(2.4, 16)
    ..cubicTo(6, 9.4, 12.6, 7.6, 17.4, 9.8)
    ..cubicTo(20.2, 11.2, 22.2, 13.4, 23.6, 16)
    ..cubicTo(22.2, 18.6, 20.2, 20.8, 17.4, 22.2)
    ..cubicTo(12.6, 24.4, 6, 22.6, 2.4, 16)
    ..close();
  final tail = Path()
    ..moveTo(21.6, 16)
    ..lineTo(28, 9.6)
    ..quadraticBezierTo(30.2, 8.4, 29.6, 10.8)
    ..quadraticBezierTo(28, 16, 29.6, 21.2)
    ..quadraticBezierTo(30.2, 23.6, 28, 22.4)
    ..close();
  final fin = Path()
    ..moveTo(10.4, 9.4)
    ..quadraticBezierTo(14.4, 4.6, 19.4, 6.2)
    ..quadraticBezierTo(18.2, 9, 19, 11.6)
    ..close();
  final gill = _cut(_oval(10.4, 16, 3.6, 5.4), [_oval(9.3, 16, 3.6, 5.8)]);
  return _cut(_join([body, tail, fin]), [gill, _oval(8.2, 14.4, 1.5, 1.5)]);
}

Path _paw() {
  final pad = Path()
    ..moveTo(16, 14.8)
    ..cubicTo(19.4, 14.8, 20.6, 17.4, 22.6, 19.6)
    ..cubicTo(24.8, 22, 24, 26.8, 20.4, 27)
    ..cubicTo(18.6, 27.1, 17.6, 26.2, 16, 26.2)
    ..cubicTo(14.4, 26.2, 13.4, 27.1, 11.6, 27)
    ..cubicTo(8, 26.8, 7.2, 22, 9.4, 19.6)
    ..cubicTo(11.4, 17.4, 12.6, 14.8, 16, 14.8)
    ..close();
  return _join([
    pad,
    _oval(6.4, 14.2, 2.9, 3.6, -18),
    _oval(12.2, 8.4, 2.9, 3.9, -6),
    _oval(19.8, 8.4, 2.9, 3.9, 6),
    _oval(25.6, 14.2, 2.9, 3.6, 18),
  ]);
}
