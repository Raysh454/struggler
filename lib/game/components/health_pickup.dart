import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../config.dart';
import 'dart:ui';
import 'dart:math';

import '../struggler_game.dart';

/// Health pickup. Restores player health when collected.
class HealthPickup extends PositionComponent with CollisionCallbacks, HasGameReference<StruggleGame> {
  final double healAmount;
  double _bobTimer = 0;
  bool collected = false;
  late Sprite _sprite;

  HealthPickup({
    required Vector2 position,
    this.healAmount = GameConfig.healthPickupHealAmountDefault,
  }) : super(
          position: position,
          size: GameConfig.healthPickupSize,
        );

  @override
  Future<void> onLoad() async {
    _sprite = await game.loadSprite('blocks/Collectible/heart01.png');
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

    // Render the heart sprite
    _sprite.render(canvas, size: size);

    // Subtle green glow behind the heart
    final cx = size.x / 2;
    final cy = size.y / 2;
    canvas.drawCircle(
      Offset(cx, cy),
      size.x * 0.5,
      Paint()
        ..color = const Color(0x3300FF88)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }
}
