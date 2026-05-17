import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:struggler/game/level/level_theme.dart';
import 'package:struggler/game/level/tile_grid.dart';
import '../config.dart';
import '../struggler_game.dart';
import 'dart:ui';
import 'dart:math';

/// Lava hazard. Damages the player on contact and has a pulsing glow.
/// This is a static component — LevelValidator guarantees proper placement,
/// so no gravity or physics simulation is needed.
class Lava extends PositionComponent with CollisionCallbacks, HasGameReference<StruggleGame> {
  final double damage;
  final LevelTheme theme;
  final TileGrid grid;
  double _glowTimer = 0;

  Lava({
    required Vector2 position,
    required Vector2 size,
    required this.theme,
    required this.grid,
    this.damage = GameConfig.lavaDamageDefault,
  }) : super(position: position, size: size) {
    priority = -15; // Render behind both foreground blocks AND background pillars
  }

  @override
  Future<void> onLoad() async {
    // Shrink hitbox slightly (forgiveness margin) so players don't die instantly 
    // when standing on the very edge of adjacent safe blocks.
    add(RectangleHitbox(
      position: Vector2(8, 12), // Inset 8px from left, 12px from top
      size: Vector2(size.x - 16, size.y - 12), // Shrink width by 16px, height by 12px
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _glowTimer += dt * 3;
  }

  @override
  void render(Canvas canvas) {
    const double destTileSize = GameConfig.tileSize;
    
    // Large bleed to completely tuck behind the adjacent platform cliff walls.
    // Because Lava is rendered at priority -5, this safely stays behind the solid 
    // rocks, filling any transparent gaps perfectly.
    const double bleed = GameConfig.lavaBleed; 
    
    // Only render lava infinitely downwards if there is NO block beneath it
    final int startGx = (position.x / destTileSize).round();
    final int wTiles = (size.x / destTileSize).round();
    final int bottomGy = ((position.y + size.y) / destTileSize).round();
    
    bool hasSupport = false;
    for (int i = 0; i < wTiles; i++) {
      if (grid.isSolid(startGx + i, bottomGy)) {
        hasSupport = true;
        break;
      }
    }

    // Viewport-culling optimization:
    // If there is no support block beneath the lava pool, we normally render down to 2000px.
    // To maintain 60+ FPS, we query the camera to render only what is visible inside the screen height.
    double maxDepth = size.y;
    if (!hasSupport) {
      final double cameraY = game.camera.viewfinder.position.y;
      final double zoom = game.camera.viewfinder.zoom;
      final double halfScreenHeight = (game.canvasSize.y / 2) / zoom;
      final double visibleBottom = cameraY + halfScreenHeight;
      // Add a 64px safety padding so players never see tile loading seams during vertical movement
      final double maxVisibleY = visibleBottom - position.y + 64.0;
      maxDepth = min(2000.0, max(size.y, maxVisibleY));
    }
    final double visualDepth = maxDepth;

    for (double y = 0; y < visualDepth; y += destTileSize) {
      // Determine the sprite for this row. Only the top row (y == 0) is animated.
      // We do this outside the inner horizontal loop to save CPU cycles.
      final sprite = y == 0 
          ? theme.lavaWaveSprites[((_glowTimer * 2.0).floor() % theme.lavaWaveSprites.length)]
          : theme.lavaFillSprite;

      for (double x = -bleed; x < size.x + bleed; x += destTileSize) {
        // We calculate draw width for the right-most tile considering the bleed
        double drawWidth = destTileSize;
        if (x + destTileSize > size.x + bleed) {
          drawWidth = (size.x + bleed) - x;
        }
        
        final double drawHeight = min(destTileSize, visualDepth - y);

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
