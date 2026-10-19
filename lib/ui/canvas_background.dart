import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import 'settings_controller.dart';

Color canvasColor(String hex) =>
    Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

/// A viewport-sized pattern, anchored to board coordinates even while panning.
class CanvasBackground extends StatelessWidget {
  const CanvasBackground(
      {required this.child,
      this.transformation,
      this.settings,
      this.brightness,
      super.key});
  final Widget child;
  final TransformationController? transformation;
  final AppSettings? settings;
  final Brightness? brightness;

  @override
  Widget build(BuildContext context) {
    final preferences = settings ?? AppSettingsScope.settingsOf(context);
    final dark =
        (brightness ?? Theme.of(context).brightness) == Brightness.dark;
    final suffix = dark ? 'Dark' : 'Light';
    return ClipRect(
        child: Stack(fit: StackFit.expand, children: [
      Positioned.fill(
          child: IgnorePointer(
              child: RepaintBoundary(
        child: CustomPaint(
            painter: CanvasPatternPainter(
          background: canvasColor(preferences.text('canvasBackground$suffix')),
          ink: canvasColor(preferences.text('canvasPattern$suffix')),
          pattern: preferences.text('canvasPattern'),
          transformation: transformation,
        )),
      ))),
      child,
    ]));
  }
}

class CanvasPatternPainter extends CustomPainter {
  CanvasPatternPainter(
      {required this.background,
      required this.ink,
      required this.pattern,
      this.transformation})
      : super(repaint: transformation);
  final Color background, ink;
  final String pattern;
  final TransformationController? transformation;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    if (pattern == 'none') return;
    final matrix = transformation?.value;
    final scale = (matrix?.getMaxScaleOnAxis() ?? 1).clamp(.4, 2.2);
    final spacing = 24 * scale;
    final offsetX = (matrix?.storage[12] ?? 0) % spacing;
    final offsetY = (matrix?.storage[13] ?? 0) % spacing;
    final paint = Paint()..color = ink;
    if (pattern == 'grid') {
      paint.color = ink.withValues(alpha: .5);
      paint.strokeWidth = .75;
      for (var x = offsetX; x < size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (var y = offsetY; y < size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    } else {
      final radius = scale.clamp(.7, 1.5).toDouble();
      for (var x = offsetX; x < size.width; x += spacing) {
        for (var y = offsetY; y < size.height; y += spacing) {
          canvas.drawCircle(Offset(x, y), radius, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(CanvasPatternPainter oldDelegate) =>
      background != oldDelegate.background ||
      ink != oldDelegate.ink ||
      pattern != oldDelegate.pattern ||
      transformation != oldDelegate.transformation;
}
