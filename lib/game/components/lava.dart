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
    await add(RectangleHitbox(
      position: Vector2(8, 12), // Inset 8px from left, 12px from top
      size: Vector2(size.x - 16, size.y - 12), // Shrink width by 16px, height by 12px
    ));
  }

  final Paint _darkenPaint = Paint()
    ..colorFilter = const ColorFilter.mode(
      Color(0x50000000), // 40% shadow like block pillars
      BlendMode.srcATop,
    );
  final Paint _glowPaint = Paint()..blendMode = BlendMode.screen;
  final Vector2 _renderPos = Vector2.zero();
  final Vector2 _renderSize = Vector2.zero();

  @override
  void update(double dt) {
    super.update(dt);
    _glowTimer += dt * 3;
  }

  Sprite _pickPillarSprite(int gx, int gy, bool isLastRow, Random random) {
    if (theme.pillarSprites.isEmpty) return theme.lavaFillSprite;
    
    final isLeftEdge = !grid.isSolid(gx - 1, gy) && !grid.isLava(gx - 1, gy);
    final isRightEdge = !grid.isSolid(gx + 1, gy) && !grid.isLava(gx + 1, gy);

    if (isLastRow) {
      if (isLeftEdge && theme.bottomLeftSprites.isNotEmpty) {
        return theme.bottomLeftSprites[random.nextInt(theme.bottomLeftSprites.length)];
      }
      if (isRightEdge && theme.bottomRightSprites.isNotEmpty) {
        return theme.bottomRightSprites[random.nextInt(theme.bottomRightSprites.length)];
      }
      if (theme.bottomSprites.isNotEmpty) {
        return theme.bottomSprites[random.nextInt(theme.bottomSprites.length)];
      }
    } else {
      if (isLeftEdge && theme.leftWallSprites.isNotEmpty) {
        return theme.leftWallSprites[random.nextInt(theme.leftWallSprites.length)];
      }
      if (isRightEdge && theme.rightWallSprites.isNotEmpty) {
        return theme.rightWallSprites[random.nextInt(theme.rightWallSprites.length)];
      }
    }
    return theme.pillarSprites[random.nextInt(theme.pillarSprites.length)];
  }

  @override
  void render(Canvas canvas) {
    const double destTileSize = GameConfig.tileSize;
    const double bleed = GameConfig.lavaBleed; 
    
    final int startGx = (position.x / destTileSize).round();
    final int wTiles = (size.x / destTileSize).round();
    final int bottomGy = ((position.y + size.y) / destTileSize).round();
    
    // Determine target depth for block pillars under support columns
    final random = Random(startGx ^ bottomGy);
    final int targetPillarDepth = random.nextInt(3) + 4; // 4 to 6 tiles

    // Viewport-culling max depth for columns with void underneath
    double maxLavaDepth = size.y;
    final double cameraY = game.camera.viewfinder.position.y;
    final double zoom = game.camera.viewfinder.zoom;
    final double halfScreenHeight = (game.canvasSize.y / 2) / zoom;
    final double visibleBottom = cameraY + halfScreenHeight;
    final double maxVisibleY = visibleBottom - position.y + 64.0;
    maxLavaDepth = min(2000.0, max(size.y, maxVisibleY));

    // First draw background containment and underneath pillars!
    for (int col = -1; col <= wTiles; col++) {
      final double x = col * destTileSize;
      final int gx = startGx + col;
      
      // Determine if there is void underneath this column
      bool columnHasVoid = true;
      int supportGy = grid.height;
      for (int gy = bottomGy; gy < grid.height; gy++) {
        if (grid.isSolid(gx, gy)) {
          columnHasVoid = false;
          supportGy = gy;
          break;
        }
      }

      if (col == -1 || col == wTiles) {
        // Containment pillars: draw to maxLavaDepth if void, or to support block/target depth if not void
        final double colLimitY = columnHasVoid 
            ? maxLavaDepth 
            : min((supportGy - (position.y / destTileSize).round()) * destTileSize, targetPillarDepth * destTileSize);
            
        for (double y = size.y; y < colLimitY; y += destTileSize) {
          final int currentGy = ((position.y + y) / destTileSize).round();
          if (grid.isSolid(gx, currentGy)) break;
          
          final isLastRow = (y + destTileSize >= colLimitY);
          final sprite = _pickPillarSprite(gx, currentGy, isLastRow, random);
          
          _renderPos.setValues(x, y);
          _renderSize.setValues(destTileSize + 1.0, destTileSize + 1.0);
          sprite.render(
            canvas,
            position: _renderPos,
            size: _renderSize,
            overridePaint: _darkenPaint,
          );
        }
      } else {
        // Underneath columns without void: draw block pillars starting below the lava top/fill block
        if (!columnHasVoid) {
          final double colLimitY = min((supportGy - (position.y / destTileSize).round()) * destTileSize, targetPillarDepth * destTileSize);
          
          for (double y = size.y; y < colLimitY; y += destTileSize) {
            final int currentGy = ((position.y + y) / destTileSize).round();
            if (grid.isSolid(gx, currentGy)) break;
            
            final isLastRow = (y + destTileSize >= colLimitY);
            final sprite = _pickPillarSprite(gx, currentGy, isLastRow, random);
            
            _renderPos.setValues(x, y);
            _renderSize.setValues(destTileSize + 1.0, destTileSize + 1.0);
            sprite.render(
              canvas,
              position: _renderPos,
              size: _renderSize,
              overridePaint: _darkenPaint,
            );
          }
        }
      }
    }

    // Now draw the lava itself!
    for (int col = 0; col < wTiles; col++) {
      final double x = col * destTileSize;
      final int gx = startGx + col;

      // Check void
      bool columnHasVoid = true;
      for (int gy = bottomGy; gy < grid.height; gy++) {
        if (grid.isSolid(gx, gy)) {
          columnHasVoid = false;
          break;
        }
      }

      final double colLavaDepth = columnHasVoid ? maxLavaDepth : size.y;

      for (double y = 0; y < colLavaDepth; y += destTileSize) {
        final sprite = y == 0 
            ? theme.lavaWaveSprites[((_glowTimer * 2.0).floor() % theme.lavaWaveSprites.length)]
            : theme.lavaFillSprite;

        // Apply a small bleed overlap only to the outer left/right bounds if they are not bordered by containment pillars
        double drawX = x;
        double drawWidth = destTileSize;
        if (col == 0) {
          drawX = x - bleed;
          drawWidth = destTileSize + bleed;
        } else if (col == wTiles - 1) {
          drawWidth = destTileSize + bleed;
        }

        final double drawHeight = min(destTileSize, colLavaDepth - y);
        _renderSize.setValues(drawWidth + 1.0, drawHeight + 1.0);
        _renderPos.setValues(drawX, y);

        if (drawWidth == destTileSize && drawHeight == destTileSize) {
          sprite.render(
            canvas,
            position: _renderPos,
            size: _renderSize,
          );
        } else {
          canvas.save();
          canvas.clipRect(Rect.fromLTWH(drawX, y, drawWidth, drawHeight));
          sprite.render(
            canvas,
            position: _renderPos,
            size: _renderSize,
          );
          canvas.restore();
        }
      }
    }

    // Overlay pulsing glow (constrained to actual size plus bleed)
    final pulse = (sin(_glowTimer) * 0.3 + 0.7);
    final r = (100 * pulse).round().clamp(0, 255);
    _glowPaint.color = Color.fromARGB((50 * pulse).round(), r, 30, 0);
    canvas.drawRect(
      Rect.fromLTWH(-bleed, 0, size.x + bleed * 2, size.y),
      _glowPaint,
    );
  }
}
