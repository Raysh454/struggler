import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:struggler/game/components/block.dart';
import 'package:struggler/game/level/level_theme.dart';
import 'dart:ui';
import 'dart:math';

/// Lava hazard. Damages the player on contact and has a pulsing glow.
class Lava extends PositionComponent with CollisionCallbacks {
  final double damage;
  final LevelTheme theme;
  double _glowTimer = 0;
  bool isOnGround = false;
  Vector2 velocity = Vector2.zero();

  static const double gravity = 1200.0;
  static const double maxFallSpeed = 1000.0;

  Lava({
    required Vector2 position,
    required Vector2 size,
    required this.theme,
    this.damage = 15.0,
  }) : super(position: position, size: size) {
    priority = -5; // Render behind the foreground blocks, but in front of background pillars
  }

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    _glowTimer += dt * 3;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is PlatformBlock) {
      _resolveBlockCollision(other);
    }
  }

  void _resolveBlockCollision(PlatformBlock block) {
    final lavaRect = toRect();
    final blockRect = block.toRect();

    // Calculate overlap on each side to find the direction
    final overlapLeft = lavaRect.right - blockRect.left;
    final overlapRight = blockRect.right - lavaRect.left;
    final overlapTop = lavaRect.bottom - blockRect.top;
    final overlapBottom = blockRect.bottom - lavaRect.top;

    // Find minimum overlap to determine collision direction
    final minOverlap = [overlapLeft, overlapRight, overlapTop, overlapBottom]
        .reduce((a, b) => a < b ? a : b);

    // ONLY resolve if we are landing on the top surface
    if (minOverlap == overlapTop && velocity.y >= 0) {
      position.y = block.position.y - size.y;
      velocity.y = 0;
      isOnGround = true;
    }
  }

  void _die() {
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    const double destTileSize = 32.0;
    
    // Large bleed to completely tuck behind the adjacent platform cliff walls.
    // Because Lava is rendered at priority -5, this safely stays behind the solid 
    // rocks, filling any transparent gaps perfectly.
    const double bleed = 32.0; 

    for (double y = 0; y < size.y; y += destTileSize) {
      for (double x = -bleed; x < size.x + bleed; x += destTileSize) {
        // We calculate draw width for the right-most tile considering the bleed
        double drawWidth = destTileSize;
        if (x + destTileSize > size.x + bleed) {
          drawWidth = (size.x + bleed) - x;
        }
        
        final double drawHeight = min(destTileSize, size.y - y);
        final sprite = y == 0 ? theme.lavaWaveSprite : theme.lavaFillSprite;

        // Sub-pixel seam overlap
        final renderSize = Vector2(drawWidth + 1.0, drawHeight + 1.0);

        if (drawWidth == destTileSize && drawHeight == destTileSize) {
          sprite.render(
            canvas,
            position: Vector2(x, y),
            size: renderSize,
          );
        } else {
          canvas.save();
          canvas.clipRect(Rect.fromLTWH(x, y, drawWidth, drawHeight));
          sprite.render(
            canvas,
            position: Vector2(x, y),
            size: renderSize,
          );
          canvas.restore();
        }
      }
    }

    // Overlay pulsing glow (constrained to actual size plus bleed)
    final pulse = (sin(_glowTimer) * 0.3 + 0.7);
    final r = (100 * pulse).round().clamp(0, 255);
    canvas.drawRect(
      Rect.fromLTWH(-bleed, 0, size.x + bleed * 2, size.y),
      Paint()
        ..color = Color.fromARGB((50 * pulse).round(), r, 30, 0)
        ..blendMode = BlendMode.screen,
    );
  }
}
