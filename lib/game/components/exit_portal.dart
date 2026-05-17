import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import '../config.dart';
import '../struggler_game.dart';
import 'enemy.dart';
import 'player.dart';
import 'dart:ui';
import 'dart:math';

/// Level exit portal. Touching this completes the level.
class ExitPortal extends PositionComponent with CollisionCallbacks, HasGameReference<StruggleGame> {
  double _animTimer = 0;
  bool playerOverlapping = false;

  ExitPortal({
    required Vector2 position,
  }) : super(
          position: position,
          size: GameConfig.exitPortalSize,
        );

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      other.currentExitPortal = this;
      playerOverlapping = true;
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is Player) {
      if (other.currentExitPortal == this) {
        other.currentExitPortal = null;
      }
      playerOverlapping = false;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animTimer += dt * 2;
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final pulse = sin(_animTimer) * 0.3 + 0.7;

    final enemiesRemaining = game.world.children.whereType<BaseEnemy>().where((e) => !e.isDead).length;
    final isLocked = enemiesRemaining > 0;

    // Portal glow ring
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.x * pulse,
        height: size.y * pulse,
      ),
      Paint()
        ..color = isLocked
            ? Color.fromARGB((200 * pulse).round(), 255, 34, 68)
            : Color.fromARGB((200 * pulse).round(), 100, 200, 255)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Inner glow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.x * 0.6,
        height: size.y * 0.6,
      ),
      Paint()
        ..color = isLocked
            ? const Color(0x44FF2244)
            : const Color(0x4464C8FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // "E" key interact prompt if player overlaps
    if (playerOverlapping) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: isLocked ? 'Clear all enemies ' : 'Interact to exit',
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            backgroundColor: Color(0x99000000),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas, 
        Offset(cx - textPainter.width / 2, -15),
      );
    }

    // Center bright point
    canvas.drawCircle(
      Offset(cx, cy),
      4,
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }
}
