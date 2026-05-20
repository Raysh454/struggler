import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart' hide Block;
import 'package:struggler/game/asset_registry.dart';
import '../config.dart';
import '../struggler_game.dart';
import 'player.dart';

enum _GAnim { idle }

/// The Guardian - a peaceful, unattackable crystalline entity.
class Guardian extends PositionComponent
    with CollisionCallbacks, HasGameReference<StruggleGame> {
  late final SpriteAnimationGroupComponent _animGroup;
  bool _spriteLoaded = false;
  double _animationTimer = 0;
  bool playerOverlapping = false;

  Guardian({required Vector2 position})
    : super(position: position, size: GameConfig.renderSizeGuardian);

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());

    final renderSize = GameConfig.renderSizeGuardian;
    final frame = Vector2(96, 96);

    try {
      final idle = await AssetRegistry.getAnimation(
        game,
        "characters/guardian/Idle.png",
        SpriteAnimationData.sequenced(
          amount: 10,
          stepTime: 0.14,
          textureSize: frame,
          loop: true,
        ),
        key: 'guardian/idle',
      );

      _animGroup = SpriteAnimationGroupComponent(
        animations: {_GAnim.idle: idle},
        current: _GAnim.idle,
        size: renderSize,
        position: Vector2(
          size.x / 2,
          size.y + (renderSize.y + GameConfig.offsetYGuardian),
        ),
        anchor: Anchor.bottomCenter,
      );

      add(_animGroup);
      _spriteLoaded = true;
    } catch (e) {
      // Render placeholder
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animationTimer += dt;

    final player = game.world.children.whereType<Player>().firstOrNull;
    if (player != null) {
      if (_spriteLoaded) {
        final playerCenterX = player.position.x + player.size.x / 2;
        final myCenterX = position.x + size.x / 2;

        if (playerCenterX < myCenterX) {
          // Player is to the left: flip scale.x to be negative (assuming default faces right)
          if (_animGroup.scale.x > 0) {
            _animGroup.scale.x = -_animGroup.scale.x.abs();
          }
        } else {
          // Player is to the right: make scale.x positive to face right
          if (_animGroup.scale.x < 0) {
            _animGroup.scale.x = _animGroup.scale.x.abs();
          }
        }
      }

      // Check overlap mathematically to avoid Flame boundary-only collision bugs when centered
      final interactionRect = Rect.fromCenter(
        center: Offset(position.x + size.x / 2, position.y + size.y / 2),
        width: 80.0, // Generous width for comfortable interaction
        height: size.y,
      );
      final playerRect = player.toRect();
      final isOverlapping = interactionRect.overlaps(playerRect);

      if (isOverlapping != playerOverlapping) {
        playerOverlapping = isOverlapping;
        if (isOverlapping) {
          player.currentGuardian = this;
        } else {
          if (player.currentGuardian == this) {
            player.currentGuardian = null;
          }
        }
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;

    // Interact prompt
    if (playerOverlapping) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'E to Upgrade Stats',
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            backgroundColor: Color(0x99000000),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(cx - textPainter.width / 2, -15));
    }

    if (_spriteLoaded) {
      return;
    }

    // Bobbing crystal position
    final bob = sin(_animationTimer * 2.0) * 4.0;

    // Pulse size
    final pulse = 1.0 + sin(_animationTimer * 4.0) * 0.05;

    // Glowing core aura
    canvas.drawCircle(
      Offset(cx, cy + bob),
      size.x * 0.4 * pulse,
      Paint()
        ..color = const Color(0x2200FFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // Draw crystalline obelisk (geometric crystal structure)
    final path = Path();
    path.moveTo(cx, cy - 25 + bob); // Top apex
    path.lineTo(cx - 15, cy + bob); // Mid-left
    path.lineTo(cx, cy + 25 + bob); // Bottom apex
    path.lineTo(cx + 15, cy + bob); // Mid-right
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xAA00E5FF)
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Inner facets for crystalline refraction look
    canvas.drawLine(
      Offset(cx, cy - 25 + bob),
      Offset(cx, cy + 25 + bob),
      Paint()
        ..color = const Color(0x44FFFFFF)
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(cx - 15, cy + bob),
      Offset(cx + 15, cy + bob),
      Paint()
        ..color = const Color(0x44FFFFFF)
        ..strokeWidth = 1.5,
    );

    // Base pedestal
    final baseRect = Rect.fromCenter(
      center: Offset(cx, size.y - 4),
      width: size.x * 0.8,
      height: 8,
    );
    canvas.drawRect(
      baseRect,
      Paint()
        ..color = const Color(0xFF444455)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      baseRect,
      Paint()
        ..color = const Color(0xFF888899)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Floating sparks
    for (int i = 0; i < 4; i++) {
      final sparkAngle = _animationTimer * 1.5 + (i * pi / 2);
      final sparkDist = 20.0 + sin(_animationTimer * 3 + i) * 4;
      final sx = cx + cos(sparkAngle) * sparkDist;
      final sy = cy + sin(sparkAngle) * sparkDist + bob;
      canvas.drawCircle(
        Offset(sx, sy),
        1.5,
        Paint()..color = const Color(0xFFE0FFFF),
      );
    }
  }

}
