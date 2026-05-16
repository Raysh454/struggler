import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'dart:ui';

/// Spike hazard. Damages the player on contact. Can be on floors or walls.
class Spike extends PositionComponent with CollisionCallbacks {
  final double damage;

  Spike({
    required Vector2 position,
    required Vector2 size,
    this.damage = 20.0,
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFFB0B0B0);

    // Draw triangle spikes across the width
    final spikeWidth = size.y; // Each spike is as wide as the tile is tall
    final count = (size.x / spikeWidth).ceil();
    final actualWidth = size.x / count;

    for (int i = 0; i < count; i++) {
      final path = Path()
        ..moveTo(i * actualWidth, size.y)
        ..lineTo(i * actualWidth + actualWidth / 2, 0)
        ..lineTo((i + 1) * actualWidth, size.y)
        ..close();
      canvas.drawPath(path, paint);
    }
  }
}
