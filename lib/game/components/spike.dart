import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'dart:math';
import 'dart:ui';
import '../level/level_theme.dart';
import '../config.dart';
import '../level/tile_grid.dart';

enum SpikeOrientation { floor, ceiling, leftWall, rightWall }

/// Spike hazard. Damages the player on contact. Can be on floors or walls.
class Spike extends PositionComponent with CollisionCallbacks {
  final double damage;
  final LevelTheme theme;
  final TileGrid? grid;
  final int tileX;
  final int tileY;
  
  SpikeOrientation _orientation = SpikeOrientation.floor;

  Spike({
    required Vector2 position, // Base tile position
    required Vector2 size,
    required this.theme,
    this.grid,
    this.tileX = 0,
    this.tileY = 0,
    this.damage = GameConfig.spikeDamageDefault,
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    _determineOrientation();
    add(RectangleHitbox());
  }

  void _determineOrientation() {
    if (grid == null) return;
    
    // Check adjacent blocks to determine orientation.
    // Order of preference: floor, left wall, right wall, ceiling
    if (grid!.isSolid(tileX, tileY + 1)) {
      _orientation = SpikeOrientation.floor;
      position.y += 3; // Sink slightly into floor
    } else if (grid!.isSolid(tileX - 1, tileY)) {
      _orientation = SpikeOrientation.leftWall;
      position.x -= 3; // Sink into left wall
    } else if (grid!.isSolid(tileX + 1, tileY)) {
      _orientation = SpikeOrientation.rightWall;
      position.x += 3; // Sink into right wall
    } else if (grid!.isSolid(tileX, tileY - 1)) {
      _orientation = SpikeOrientation.ceiling;
      position.y -= 3; // Sink into ceiling
    }
  }

  @override
  void render(Canvas canvas) {
    final sprite = theme.floorSpikeSprite;
    const double spikeTileSize = GameConfig.tileSize;
    
    canvas.save();
    
    // Move to center to rotate
    canvas.translate(size.x / 2, size.y / 2);
    
    switch (_orientation) {
      case SpikeOrientation.floor:
        break; // Default orientation
      case SpikeOrientation.rightWall:
        canvas.rotate(-pi / 2);
        break;
      case SpikeOrientation.leftWall:
        canvas.rotate(pi / 2);
        break;
      case SpikeOrientation.ceiling:
        canvas.rotate(pi);
        break;
    }
    
    // Move back
    canvas.translate(-size.x / 2, -size.y / 2);
    
    for (double x = 0; x < size.x; x += spikeTileSize) {
      sprite.render(
        canvas,
        position: Vector2(x, 0),
        size: Vector2(spikeTileSize, size.y),
      );
    }
    
    canvas.restore();
  }
}
