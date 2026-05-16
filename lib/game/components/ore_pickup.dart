import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'dart:ui';
import 'dart:math';

/// Ore pickup. Used for upgrading at the Guardian. One per level, hard to reach.
class OrePickup extends PositionComponent with CollisionCallbacks {
  double _sparkleTimer = 0;
  bool collected = false;

  OrePickup({
    required Vector2 position,
  }) : super(
          position: position,
          size: Vector2.all(20),
        );

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    _sparkleTimer += dt * 4;
  }

  @override
  void render(Canvas canvas) {
    if (collected) return;

    // Amber/gold crystal shape
    final cx = size.x / 2;
    final cy = size.y / 2;
    final pulse = (sin(_sparkleTimer) * 0.2 + 0.8);

    // Diamond shape
    final path = Path()
      ..moveTo(cx, 2)
      ..lineTo(size.x - 2, cy)
      ..lineTo(cx, size.y - 2)
      ..lineTo(2, cy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Color.fromARGB(
          255,
          (255 * pulse).round(),
          (180 * pulse).round(),
          40,
        ),
    );

    // Sparkle glow
    canvas.drawCircle(
      Offset(cx, cy),
      size.x * 0.45,
      Paint()
        ..color = const Color(0x44FFB028)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }
}
