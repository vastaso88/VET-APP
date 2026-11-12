import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../domain/body_condition.dart';
import '../../domain/body_condition_guide.dart';

/// Original vector drawing (no photos, no third-party art) of a pet seen from
/// above and from the side, at one of the five body condition levels. The
/// shape changes with the level exactly where the owner is asked to look:
/// the waist behind the ribs from above, the tuck of the belly from the side
/// and the ribs themselves.
class BodyConditionIllustration extends StatelessWidget {
  const BodyConditionIllustration({
    required this.kind,
    required this.condition,
    super.key,
  });

  final BodyConditionGuideKind kind;
  final BodyCondition condition;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: AspectRatio(
            aspectRatio: 0.72,
            child: CustomPaint(
              key: const ValueKey('bcs-illustration-top'),
              painter: BodyConditionPainter(
                kind: kind,
                condition: condition,
                view: BodyConditionView.top,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 7,
          child: AspectRatio(
            aspectRatio: 1.45,
            child: CustomPaint(
              key: const ValueKey('bcs-illustration-side'),
              painter: BodyConditionPainter(
                kind: kind,
                condition: condition,
                view: BodyConditionView.side,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum BodyConditionView { top, side }

/// Draws one view. Everything is computed on a 100 x 100 (top) / 145 x 100
/// (side) design grid and scaled to the canvas.
class BodyConditionPainter extends CustomPainter {
  const BodyConditionPainter({
    required this.kind,
    required this.condition,
    required this.view,
  });

  final BodyConditionGuideKind kind;
  final BodyCondition condition;
  final BodyConditionView view;

  /// -2 (very thin) .. +2 (overweight), 0 = normal.
  double get _f => (condition.score - 3).toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    if (view == BodyConditionView.top) {
      canvas.scale(size.width / 72, size.height / 100);
      _paintTop(canvas);
    } else {
      canvas.scale(size.width / 145, size.height / 100);
      _paintSide(canvas);
    }
  }

  Paint get _fill => Paint()
    ..style = PaintingStyle.fill
    ..color = condition.color.withValues(alpha: 0.2);

  Paint get _stroke => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = condition.color;

  Paint get _hint => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round
    ..color = AppColors.primary.withValues(alpha: 0.75);

  /// How clearly the ribs show through, 1 (very thin) .. 0 (normal and up).
  double get _ribVisibility => switch (condition) {
        BodyCondition.veryThin => 1,
        BodyCondition.thin => 0.65,
        BodyCondition.normal => 0.3,
        _ => 0,
      };

  // ---- top view: head up, tail down, 72 wide ------------------------------

  void _paintTop(Canvas canvas) {
    const cx = 36.0;
    final f = _f;
    // Half widths: the chest barely changes, the waist is what tells the
    // levels apart (visible hourglass -> straight sides -> bulging).
    final rabbit = kind == BodyConditionGuideKind.rabbit;
    final cat = kind == BodyConditionGuideKind.cat;
    final chest = (cat ? 15.0 : rabbit ? 16.0 : 19.0) + f * 1.8;
    final hip = (cat ? 14.0 : rabbit ? 21.0 : 17.0) + f * 2.4;
    final waist = math.max(
      rabbit ? 11.0 : 7.0,
      (cat ? 11.0 : rabbit ? 15.0 : 13.0) + f * (rabbit ? 3.0 : 4.6),
    );

    const neckY = 25.0;
    const chestY = 40.0;
    const waistY = 59.0;
    const hipY = 74.0;
    const rumpY = 92.0;

    final body = Path()
      ..moveTo(cx - 8, neckY)
      ..cubicTo(cx - 12, neckY + 6, cx - chest, chestY - 8, cx - chest, chestY)
      ..cubicTo(
          cx - chest, chestY + 9, cx - waist, waistY - 10, cx - waist, waistY)
      ..cubicTo(cx - waist, waistY + 8, cx - hip, hipY - 8, cx - hip, hipY)
      ..cubicTo(cx - hip, hipY + 10, cx - 9, rumpY, cx, rumpY)
      ..cubicTo(cx + 9, rumpY, cx + hip, hipY + 10, cx + hip, hipY)
      ..cubicTo(cx + hip, hipY - 8, cx + waist, waistY + 8, cx + waist, waistY)
      ..cubicTo(
          cx + waist, waistY - 10, cx + chest, chestY + 9, cx + chest, chestY)
      ..cubicTo(cx + chest, chestY - 8, cx + 12, neckY + 6, cx + 8, neckY)
      ..close();

    _paintTopHeadAndTail(canvas, cx);
    canvas.drawPath(body, _fill);
    canvas.drawPath(body, _stroke);

    // The dashed line the owner checks: the waist, behind the ribs.
    _dashedLine(
        canvas, Offset(cx - hip - 3, waistY), Offset(cx + hip + 3, waistY));
  }

  void _paintTopHeadAndTail(Canvas canvas, double cx) {
    final skin = Paint()
      ..style = PaintingStyle.fill
      ..color = condition.color.withValues(alpha: 0.2);
    switch (kind) {
      case BodyConditionGuideKind.dog:
        final head = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, 11), width: 17, height: 24),
            const Radius.circular(8));
        canvas.drawRRect(head, skin);
        canvas.drawRRect(head, _stroke);
        for (final side in [-1.0, 1.0]) {
          final ear = Path()
            ..moveTo(cx + side * 8, 5)
            ..quadraticBezierTo(cx + side * 17, 6, cx + side * 15, 19)
            ..quadraticBezierTo(cx + side * 10, 18, cx + side * 8, 14)
            ..close();
          canvas.drawPath(ear, skin);
          canvas.drawPath(ear, _stroke);
        }
        final tail = Path()
          ..moveTo(cx, 91)
          ..quadraticBezierTo(cx + 8, 96, cx + 12, 99);
        canvas.drawPath(tail, _stroke..strokeWidth = 2.6);
      case BodyConditionGuideKind.cat:
        final head = Rect.fromCenter(center: Offset(cx, 14), width: 24, height: 22);
        canvas.drawOval(head, skin);
        canvas.drawOval(head, _stroke);
        for (final side in [-1.0, 1.0]) {
          final ear = Path()
            ..moveTo(cx + side * 4, 5)
            ..lineTo(cx + side * 11, -1)
            ..lineTo(cx + side * 12, 11)
            ..close();
          canvas.drawPath(ear, skin);
          canvas.drawPath(ear, _stroke);
        }
        final tail = Path()
          ..moveTo(cx, 91)
          ..cubicTo(cx + 2, 99, cx + 14, 99, cx + 16, 90);
        canvas.drawPath(tail, _stroke..strokeWidth = 2.6);
      case BodyConditionGuideKind.rabbit:
        final head = Rect.fromCenter(center: Offset(cx, 16), width: 20, height: 22);
        canvas.drawOval(head, skin);
        canvas.drawOval(head, _stroke);
        for (final side in [-1.0, 1.0]) {
          final ear = Rect.fromCenter(
              center: Offset(cx + side * 6, 4), width: 7, height: 20);
          canvas.drawOval(ear, skin);
          canvas.drawOval(ear, _stroke);
        }
        canvas.drawCircle(Offset(cx, 95), 3.2, skin);
        canvas.drawCircle(Offset(cx, 95), 3.2, _stroke..strokeWidth = 1.4);
    }
  }

  // ---- side view: head left, tail right, 145 wide --------------------------

  void _paintSide(Canvas canvas) {
    final f = _f;
    final rabbit = kind == BodyConditionGuideKind.rabbit;
    final cat = kind == BodyConditionGuideKind.cat;

    const backY = 26.0;
    final chestBottom = 62.0 + f * 2.5 + (rabbit ? 2 : 0);
    // How far the belly is pulled up behind the ribs (negative = it hangs).
    final tuck = (rabbit ? 8.0 : cat ? 12.0 : 17.0) -
        (f + 2) * (rabbit ? 3.0 : cat ? 4.0 : 5.2);
    final waistBottom = chestBottom - tuck;
    final rumpBottom = chestBottom - 6 + f * 0.8;

    const frontX = 40.0;
    const rearX = 128.0;
    const waistX = 86.0;

    // Legs sit behind the body.
    final legPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..color = condition.color.withValues(alpha: 0.45);
    canvas.drawLine(Offset(52, chestBottom - 3), const Offset(52, 90), legPaint);
    canvas.drawLine(Offset(112, rumpBottom - 3), const Offset(114, 90), legPaint);

    final body = Path()
      ..moveTo(frontX, backY + 6)
      ..cubicTo(frontX + 18, backY - 4, waistX, backY - (rabbit ? 8 : 0),
          rearX - 10, backY + (rabbit ? -2 : 2))
      ..cubicTo(rearX + 2, backY + 4, rearX + 4, rumpBottom - 10, rearX - 4,
          rumpBottom)
      ..cubicTo(rearX - 16, rumpBottom + 3, waistX + 14, waistBottom + 1,
          waistX, waistBottom)
      ..cubicTo(waistX - 14, waistBottom - 1, frontX + 26, chestBottom + 6,
          frontX + 12, chestBottom)
      ..cubicTo(frontX + 2, chestBottom - 4, frontX - 4, backY + 30, frontX,
          backY + 6)
      ..close();

    _paintSideHeadAndTail(canvas, frontX, backY, rearX);
    canvas.drawPath(body, _fill);
    canvas.drawPath(body, _stroke);

    // Ribs: lines across the chest that fade out as the fat cover grows.
    final visibility = _ribVisibility;
    if (visibility > 0) {
      final ribs = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round
        ..color = condition.color.withValues(alpha: 0.85 * visibility);
      for (var i = 0; i < 5; i++) {
        final x = frontX + 20 + i * 7.5;
        canvas.drawArc(
          Rect.fromLTWH(x - 9, backY + 5, 18, chestBottom - backY - 10),
          math.pi * 0.2,
          math.pi * 0.6,
          false,
          ribs,
        );
      }
    }

    // The belly line the owner checks: it should rise behind the ribs.
    _dashedLine(canvas, Offset(frontX + 24, chestBottom + 5),
        Offset(rearX - 8, chestBottom + 5));
  }

  void _paintSideHeadAndTail(
      Canvas canvas, double frontX, double backY, double rearX) {
    final skin = Paint()
      ..style = PaintingStyle.fill
      ..color = condition.color.withValues(alpha: 0.2);
    switch (kind) {
      case BodyConditionGuideKind.dog:
        final head = Path()
          ..moveTo(frontX + 2, backY + 4)
          ..quadraticBezierTo(frontX - 8, backY - 8, frontX - 20, backY + 2)
          ..quadraticBezierTo(frontX - 32, backY + 6, frontX - 31, backY + 15)
          ..quadraticBezierTo(frontX - 26, backY + 22, frontX - 12, backY + 20)
          ..quadraticBezierTo(frontX - 2, backY + 30, frontX + 4, backY + 30)
          ..close();
        canvas.drawPath(head, skin);
        canvas.drawPath(head, _stroke);
        final ear = Path()
          ..moveTo(frontX - 8, backY - 3)
          ..quadraticBezierTo(frontX - 4, backY + 12, frontX - 12, backY + 17)
          ..quadraticBezierTo(frontX - 18, backY + 8, frontX - 8, backY - 3);
        canvas.drawPath(ear, _stroke);
        canvas.drawLine(Offset(rearX - 2, backY + 4), Offset(rearX + 12, backY - 8),
            _stroke..strokeWidth = 2.6);
      case BodyConditionGuideKind.cat:
        final head = Rect.fromCenter(
            center: Offset(frontX - 12, backY + 10), width: 28, height: 24);
        canvas.drawOval(head, skin);
        canvas.drawOval(head, _stroke);
        final ear = Path()
          ..moveTo(frontX - 20, backY + 1)
          ..lineTo(frontX - 18, backY - 10)
          ..lineTo(frontX - 10, backY - 1)
          ..close();
        canvas.drawPath(ear, skin);
        canvas.drawPath(ear, _stroke);
        final tail = Path()
          ..moveTo(rearX - 2, backY + 6)
          ..cubicTo(rearX + 14, backY + 4, rearX + 12, backY - 14, rearX + 4,
              backY - 18);
        canvas.drawPath(tail, _stroke..strokeWidth = 2.6);
      case BodyConditionGuideKind.rabbit:
        final head = Rect.fromCenter(
            center: Offset(frontX - 10, backY + 14), width: 30, height: 24);
        canvas.drawOval(head, skin);
        canvas.drawOval(head, _stroke);
        final ear = Path()
          ..moveTo(frontX - 8, backY + 4)
          ..quadraticBezierTo(frontX + 4, backY - 22, frontX + 12, backY - 14)
          ..quadraticBezierTo(frontX + 8, backY, frontX - 2, backY + 8)
          ..close();
        canvas.drawPath(ear, skin);
        canvas.drawPath(ear, _stroke);
        canvas.drawCircle(Offset(rearX + 1, backY + 10), 3.4, skin);
        canvas.drawCircle(Offset(rearX + 1, backY + 10), 3.4, _stroke..strokeWidth = 1.4);
    }
  }

  void _dashedLine(Canvas canvas, Offset from, Offset to) {
    final paint = _hint;
    final total = (to - from).distance;
    final direction = (to - from) / total;
    const dash = 3.0;
    const gap = 3.0;
    for (var d = 0.0; d < total; d += dash + gap) {
      final end = math.min(d + dash, total);
      canvas.drawLine(from + direction * d, from + direction * end, paint);
    }
  }

  @override
  bool shouldRepaint(BodyConditionPainter old) =>
      old.kind != kind || old.condition != condition || old.view != view;
}
