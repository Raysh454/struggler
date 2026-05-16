import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'dart:ui';

/// Solid platform block. Players and enemies stand on these.
class PlatformBlock extends PositionComponent with CollisionCallbacks {
  PlatformBlock({
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    // Placeholder: dark grey stone block
    canvas.drawRect(
      size.toRect(),
      Paint()..color = const Color(0xFF4A4A5A),
    );
    // Subtle border for visibility
    canvas.drawRect(
      size.toRect(),
      Paint()
        ..color = const Color(0xFF3A3A4A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}
