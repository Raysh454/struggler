import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../config.dart';
import '../struggler_game.dart';
import 'player.dart';

/// Companion Cat "Hope" - follows the player's movements automatically and mirrors jumps.
class CompanionCat extends PositionComponent with HasGameReference<StruggleGame> {
  double _animationTimer = 0;
  int _facingDirection = 1;

  CompanionCat({
    required Vector2 position,
  }) : super(
          position: position,
          size: GameConfig.catSize,
        );

  @override
  void update(double dt) {
    super.update(dt);
    _animationTimer += dt;

    // Locate player to mirror movements
    final player = game.world.children.whereType<Player>().firstOrNull;
    if (player != null) {
      // Stay slightly behind the player
      _facingDirection = player.facingDirection;
      final targetX = player.position.x - (_facingDirection * 24.0);
      final targetY = player.position.y + player.size.y - size.y;

      // Smoothly interpolate positions (spring/lerp)
      position.x += (targetX - position.x) * 0.12;
      position.y += (targetY - position.y) * 0.16;
    }
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2 - 2;

    canvas.save();
    // Flip canvas based on direction
    if (_facingDirection == -1) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }

    final catPaint = Paint()
      ..color = const Color(0xFFFF8C00) // Deep Orange
      ..style = PaintingStyle.fill;

    final whitePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;

    final detailPaint = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.fill;

    // 1. Draw Tail (wiggling)
    final tailWiggle = sin(_animationTimer * 6) * 0.15;
    canvas.save();
    canvas.translate(cx - 10, cy + 4);
    canvas.rotate(tailWiggle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-2, -12, 4, 12),
        const Radius.circular(2),
      ),
      catPaint,
    );
    canvas.restore();

    // 2. Draw Body (round oval)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - 2, cy + 4),
        width: 18,
        height: 12,
      ),
      catPaint,
    );

    // 3. Draw Head
    canvas.drawCircle(
      Offset(cx + 4, cy - 2),
      6.5,
      catPaint,
    );

    // 4. Draw Ears (triangles)
    final leftEar = Path()
      ..moveTo(cx + 1, cy - 7)
      ..lineTo(cx + 1, cy - 12)
      ..lineTo(cx + 5, cy - 8)
      ..close();
    canvas.drawPath(leftEar, catPaint);

    final rightEar = Path()
      ..moveTo(cx + 5, cy - 7)
      ..lineTo(cx + 8, cy - 12)
      ..lineTo(cx + 8, cy - 7)
      ..close();
    canvas.drawPath(rightEar, catPaint);

    // 5. Draw Eyes
    canvas.drawCircle(Offset(cx + 6, cy - 3), 1, detailPaint);
    canvas.drawCircle(Offset(cx + 9, cy - 3), 1, detailPaint);

    // 6. Cute white chest fluff
    canvas.drawCircle(Offset(cx + 1, cy + 4), 3, whitePaint);

    canvas.restore();
  }
}
