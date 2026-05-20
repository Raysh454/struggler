import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import '../struggler_game.dart';

/// A floating tutorial hint sign rendered in the game world.
/// Displays instructional text with a subtle glow and background panel.
class TutorialHint extends PositionComponent
    with HasGameReference<StruggleGame> {
  final String text;
  final Color textColor;
  final double fontSize;

  TutorialHint({
    required Vector2 position,
    required this.text,
    this.textColor = const Color(0xFFFFD54F),
    this.fontSize = 9.0,
  }) : super(
         position: position,
         size: Vector2(200, 40),
         anchor: Anchor.topCenter,
       );

  double _bobTimer = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _bobTimer += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final bob = _sinBob(_bobTimer, 2.0, 1.5);

    final lines = text.split('\n');
    final lineHeight = fontSize + 3;
    final totalTextHeight = lines.length * lineHeight;
    final maxLineWidth = _measureMaxLineWidth(lines, fontSize);

    final panelW = maxLineWidth + 16;
    final panelH = totalTextHeight + 10;
    final panelX = (size.x - panelW) / 2;
    final panelY = bob + (size.y - panelH) / 2;

    // Background panel
    final panelRect = Rect.fromLTWH(panelX, panelY, panelW, panelH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect, const Radius.circular(4)),
      Paint()..color = const Color(0xBB1A1A2E),
    );
    // Border
    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect, const Radius.circular(4)),
      Paint()
        ..color = textColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Render text lines
    for (int i = 0; i < lines.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: lines[i],
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          panelX + (panelW - tp.width) / 2,
          panelY + 5 + i * lineHeight + bob * 0.1,
        ),
      );
    }
  }

  double _sinBob(double time, double speed, double amplitude) {
    return amplitude * _sin(time * speed);
  }

  double _sin(double x) {
    // Simple sin approximation to avoid importing dart:math in render
    x = x % 6.28318;
    if (x > 3.14159) x -= 6.28318;
    final x2 = x * x;
    return x * (1 - x2 / 6 * (1 - x2 / 20 * (1 - x2 / 42)));
  }

  double _measureMaxLineWidth(List<String> lines, double fs) {
    double maxW = 0;
    for (final line in lines) {
      final tp = TextPainter(
        text: TextSpan(
          text: line,
          style: TextStyle(
            fontSize: fs,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (tp.width > maxW) maxW = tp.width;
    }
    return maxW;
  }
}
