import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../config.dart';
import 'dart:ui';
import 'dart:math';

import '../struggler_game.dart';

/// Dark Souls style "Bloodstain" or "Lost Will" that contains the player's dropped willpower.
class LostWillPickup extends PositionComponent with CollisionCallbacks, HasGameReference<StruggleGame> {
  final int willpowerAmount;
  double _sparkleTimer = 0;
  bool collected = false;

  LostWillPickup({
    required Vector2 position,
    required this.willpowerAmount,
  }) : super(
          position: position,
          size: Vector2(24, 24),
        );

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    _sparkleTimer += dt * 3;
    // Gentle bob up and down
    position.y += sin(_sparkleTimer) * 0.2;
  }

  @override
  void render(Canvas canvas) {
    if (collected) return;
    
    // Subtle green ethereal glow
    final cx = size.x / 2;
    final cy = size.y / 2;
    
    // Outer pulsating aura
    final pulseScale = 1.0 + sin(_sparkleTimer * 2) * 0.2;
    canvas.drawCircle(
      Offset(cx, cy),
      size.x * 0.6 * pulseScale,
      Paint()
        ..color = const Color(0x6600FF66)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Inner bright core
    canvas.drawCircle(
      Offset(cx, cy),
      size.x * 0.3,
      Paint()
        ..color = const Color(0xFFDDFFDD)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    // Player collision is handled entirely within the Player component to centralize it.
  }
}
