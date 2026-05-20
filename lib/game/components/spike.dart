import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'dart:math';
import 'dart:ui';
import '../level/level_theme.dart';
import '../config.dart';
import '../level/tile_grid.dart';

/// Spike hazard. Damages the player on contact. Can be on floors or walls.
class Spike extends PositionComponent with CollisionCallbacks {
  final double damage;
  final LevelTheme theme;
  final TileGrid? grid;
  final int tileX;
  final int tileY;

  Spike({
    required Vector2 position, // Base tile position (top-left of tile)
    required Vector2 size,
    required this.theme,
    this.grid,
    this.tileX = 0,
    this.tileY = 0,
    this.damage = GameConfig.spikeDamageDefault,
  }) : super(position: position, size: size) {
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    _determineOrientationAndPosition();

    // Spikes are triangular and sit at the base of the tile.
    // To make collision feel extremely fair, precise, and premium, we shrink the hitbox:
    // - Width: 20px (centered horizontally within the 32px tile)
    // - Height: 18px (aligned to the bottom/base of the tile)
    // Flame automatically rotates this hitbox along with the component for walls/ceilings!
    final hitbox = RectangleHitbox(
      size: Vector2(20, 18),
      position: Vector2(6, 14),
    );
    add(hitbox);
  }

  void _determineOrientationAndPosition() {
    if (grid == null) {
      position = position + size / 2;
      return;
    }

    final ts = GameConfig.tileSize;
    final halfX = size.x / 2;
    final halfY = size.y / 2;

    // Set position to the exact center of the grid tile
    position = Vector2(tileX * ts + halfX, tileY * ts + halfY);

    // Check adjacent blocks to determine orientation and set rotation angle.
    // Order of preference: left wall, right wall, floor, ceiling
    if (grid!.isSolid(tileX - 1, tileY)) {
      angle = pi / 2;
    } else if (grid!.isSolid(tileX + 1, tileY)) {
      angle = -pi / 2;
    } else if (grid!.isSolid(tileX, tileY + 1)) {
      angle = 0;
    } else if (grid!.isSolid(tileX, tileY - 1)) {
      angle = pi;
    } else {
      angle = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    final sprite = theme.floorSpikeSprite;
    const double spikeTileSize = GameConfig.tileSize;

    // Draw all spikes horizontally relative to the component bounds (Flame handles rotation/translation)
    for (double x = 0; x < size.x; x += spikeTileSize) {
      sprite.render(
        canvas,
        position: Vector2(x, GameConfig.spikeOffset),
        size: Vector2(spikeTileSize, size.y),
      );
    }
  }
}
