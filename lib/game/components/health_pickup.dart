import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'dart:ui';
import 'dart:math';

/// Health pickup. Restores player health when collected.
class HealthPickup extends PositionComponent with CollisionCallbacks {
  final double healAmount;
  double _bobTimer = 0;
  bool collected = false;

  HealthPickup({
    required Vector2 position,
    this.healAmount = 30.0,
  }) : super(
          position: position,
          size: Vector2.all(24),
        );

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Gentle bob up and down
    _bobTimer += dt * 2;
    position.y += sin(_bobTimer) * 0.3;
  }

  @override
  void render(Canvas canvas) {
    if (collected) return;

    // Green cross/plus symbol
    final paint = Paint()..color = const Color(0xFF00FF88);
    final cx = size.x / 2;
    final cy = size.y / 2;
    final armW = size.x * 0.2;
    final armH = size.y * 0.6;

    // Vertical bar of cross
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy), width: armW, height: armH),
      paint,
    );
    // Horizontal bar of cross
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy), width: armH, height: armW),
      paint,
    );

    // Glow
    canvas.drawCircle(
      Offset(cx, cy),
      size.x * 0.5,
      Paint()
        ..color = const Color(0x3300FF88)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }
}
