import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart'
    show Colors, TextStyle, TextPainter, TextSpan, Canvas, Offset, Paint;

/// A text bubble component that floats above an entity.
class DialogueBubble extends PositionComponent {
  final String text;
  final double duration;
  final bool isStatic;
  double _elapsed = 0;
  late final TextPainter _textPainter;

  DialogueBubble({
    required this.text,
    required this.duration,
    this.isStatic = false,
  }) {
    _textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontFamily: 'Gotfridus',
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black87, blurRadius: 2, offset: Offset(1, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    _textPainter.layout(maxWidth: 120);

    // Bubble padding
    size = Vector2(_textPainter.width + 12, _textPainter.height + 12);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    // Float upwards slightly only if not static
    if (!isStatic) {
      position.y -= 10 * dt;
    }
    if (_elapsed >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Fade out towards the end
    double opacity = 1.0;
    if (duration - _elapsed < 0.5) {
      opacity = ((duration - _elapsed) / 0.5).clamp(0.0, 1.0);
    }
    if (opacity <= 0) return;

    final paint = Paint()
      ..color = const Color(0xAA000000).withValues(alpha: 0.6 * opacity);

    // Draw bubble background
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      paint,
    );

    // Draw text
    _textPainter.paint(canvas, Offset(6, 6));
  }
}
