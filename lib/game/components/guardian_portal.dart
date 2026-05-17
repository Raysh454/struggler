import 'dart:math';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart' hide Block;
import '../config.dart';
import '../struggler_game.dart';
import 'player.dart';

/// Portal used to travel to/from the Guardian's Realm.
class GuardianPortal extends PositionComponent with CollisionCallbacks, HasGameReference<StruggleGame> {
  final bool isReturn;
  double _animationTimer = 0;
  bool playerOverlapping = false;

  GuardianPortal({
    required Vector2 position,
    this.isReturn = false,
  }) : super(
          position: position,
          size: GameConfig.guardianPortalSize,
        );

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animationTimer += dt;
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final r = size.x / 2;

    // Pulse factor
    final pulse = 1.0 + sin(_animationTimer * 5) * 0.08;

    // Glowing outer aura
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.x * pulse,
        height: size.y * pulse,
      ),
      Paint()
        ..color = isReturn ? const Color(0x3344FF44) : const Color(0x334488FF) // Green for return, Blue for enter
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Inner portal disc
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.x * 0.9,
        height: size.y * 0.9,
      ),
      Paint()
        ..color = isReturn ? const Color(0xAA113311) : const Color(0xAA111133)
        ..style = PaintingStyle.fill,
    );

    // Swirling rings
    final rings = 3;
    for (int i = 0; i < rings; i++) {
      final angle = _animationTimer * (i + 1) * 0.8;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);
      
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.x * (0.8 - i * 0.2),
          height: size.y * (0.8 - i * 0.2),
        ),
        Paint()
          ..color = isReturn 
              ? const Color(0xFF66FF66).withOpacity(0.4 + 0.1 * i)
              : const Color(0xFF66B2FF).withOpacity(0.4 + 0.1 * i)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.restore();
    }

    // Portal border
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.x,
        height: size.y,
      ),
      Paint()
        ..color = isReturn ? const Color(0xFF88FF88) : const Color(0xFF88CCFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // "E" key interact prompt if player overlaps
    if (playerOverlapping) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: isReturn ? 'Interact to Return' : 'Interact to Enter Portal',
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
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      playerOverlapping = true;
      other.currentPortal = this;
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is Player) {
      playerOverlapping = false;
      if (other.currentPortal == this) {
        other.currentPortal = null;
      }
    }
  }
}
