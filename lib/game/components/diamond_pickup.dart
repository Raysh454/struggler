import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../config.dart';
import 'dart:ui';
import 'dart:math';

import '../struggler_game.dart';

/// Diamond pickup. Used for upgrading at the Guardian. One per level, hard to reach.
class DiamondPickup extends PositionComponent with CollisionCallbacks, HasGameReference<StruggleGame> {
  double _sparkleTimer = 0;
  bool collected = false;
  late Sprite _sprite;

  late final Vector2 initialPosition;

  DiamondPickup({
    required Vector2 position,
  }) : super(
          position: position,
          size: GameConfig.diamondPickupSize,
        ) {
    initialPosition = position.clone();
  }

  @override
  Future<void> onLoad() async {
    _sprite = await game.loadSprite('blocks/Collectible/diamond_big_01.png');
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    _sparkleTimer += dt * 4;
    // Gentle bob up and down
    position.y += sin(_sparkleTimer) * 0.15;
  }

  @override
  void render(Canvas canvas) {
    if (collected) return;
    
    // Render the sprite
    _sprite.render(canvas, size: size);

    // Subtle cyan/blue glow behind it
    final cx = size.x / 2;
    final cy = size.y / 2;
    canvas.drawCircle(
      Offset(cx, cy),
      size.x * 0.45,
      Paint()
        ..color = const Color(0x334488FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }
}
