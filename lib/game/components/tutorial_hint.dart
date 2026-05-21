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

  final List<TextPainter> _textPainters = [];
  double _maxLineWidth = 0;
  double _totalTextHeight = 0;
  double _lineHeight = 0;
  bool _isFullyLoaded = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _lineHeight = fontSize + 3;
    final lines = text.split('\n');
    _totalTextHeight = lines.length * _lineHeight;

    for (final line in lines) {
      final tp = TextPainter(
        text: TextSpan(
          text: line,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _textPainters.add(tp);
      if (tp.width > _maxLineWidth) {
        _maxLineWidth = tp.width;
      }
    }
    _isFullyLoaded = true;
  }

  double _bobTimer = 0;

  @override
  void update(double dt) {
    if (!_isFullyLoaded) return;
    super.update(dt);
    _bobTimer += dt;
  }

  @override
  void render(Canvas canvas) {
    if (!_isFullyLoaded) return;
    super.render(canvas);
    final bob = _sinBob(_bobTimer, 2.0, 1.5);

    final panelW = _maxLineWidth + 16;
    final panelH = _totalTextHeight + 10;
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
    for (int i = 0; i < _textPainters.length; i++) {
      final tp = _textPainters[i];
      tp.paint(
        canvas,
        Offset(
          panelX + (panelW - tp.width) / 2,
          panelY + 5 + i * _lineHeight + bob * 0.1,
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
}
