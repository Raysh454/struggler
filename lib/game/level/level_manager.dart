import 'package:flame/components.dart' hide Block;

import 'level_data.dart';
import '../components/block.dart';
import '../components/lava.dart';
import '../components/spike.dart';
import '../components/enemy.dart';
import '../components/health_pickup.dart';
import '../components/ore_pickup.dart';
import '../components/exit_portal.dart';

/// Converts a LevelData JSON blueprint into Flame game components.
class LevelManager {
  /// Tile size in pixels. All grid coordinates in the blueprint are multiplied by this.
  static const double tileSize = 32.0;

  /// Build all components for a level blueprint.
  /// Returns a list of components to add to the game world.
  static List<Component> buildLevel(LevelData data) {
    final components = <Component>[];

    // --- Tiles ---
    for (final tile in data.tiles) {
      final pos = Vector2(tile.x * tileSize, tile.y * tileSize);
      final size = Vector2(tile.w * tileSize, tile.h * tileSize);

      switch (tile.type) {
        case 'block':
          components.add(PlatformBlock(position: pos, size: size));
          break;
        case 'lava':
          components.add(Lava(position: pos, size: size));
          break;
        case 'spike':
          components.add(Spike(position: pos, size: size));
          break;
      }
    }

    // --- Enemies ---
    for (final enemy in data.enemies) {
      components.add(Enemy(
        position: Vector2(enemy.x * tileSize, enemy.y * tileSize),
        maxHealth: enemy.health,
        contactDamage: enemy.damage,
        speed: enemy.speed * 60, // Convert speed multiplier to pixels/sec
        enemyType: enemy.type,
        patrolRange: enemy.patrolRange * tileSize,
      ));
    }

    // --- Pickups ---
    for (final pickup in data.pickups) {
      final pos = Vector2(pickup.x * tileSize, pickup.y * tileSize);
      switch (pickup.type) {
        case 'health':
          components.add(HealthPickup(position: pos));
          break;
        case 'ore':
          components.add(OrePickup(position: pos));
          break;
      }
    }

    // --- Exit portal ---
    components.add(ExitPortal(
      position: Vector2(data.exit.x * tileSize, data.exit.y * tileSize),
    ));

    return components;
  }

  /// Get spawn position in pixel coordinates.
  static Vector2 getSpawnPosition(LevelData data) {
    return Vector2(data.spawn.x * tileSize, data.spawn.y * tileSize);
  }

  /// A hardcoded test level for development before AI integration.
  static LevelData createTestLevel(int levelId) {
    return LevelData(
      levelId: levelId,
      difficulty: 0.3,
      width: 60,
      height: 20,
      spawn: (x: 2, y: 17),
      exit: (x: 55, y: 14),
      tiles: [
        // Ground floor (with gaps for challenge)
        TileData(type: 'block', x: 0, y: 19, w: 15, h: 1),
        TileData(type: 'block', x: 15, y: 20, w: 3, h:0.5),
        TileData(type: 'block', x: 18, y: 19, w: 12, h: 1),
        TileData(type: 'block', x: 33, y: 19, w: 27, h: 1),

        // Lava in the gaps
        TileData(type: 'lava', x: 15, y: 19, w: 3, h: 1),

        // Platforms
        TileData(type: 'block', x: 8,  y: 17, w: 4, h: 0.5),
        TileData(type: 'block', x: 20, y: 15, w: 5, h: 1),
        TileData(type: 'block', x: 28, y: 13, w: 3, h: 1),
        TileData(type: 'block', x: 35, y: 16, w: 4, h: 1),
        TileData(type: 'block', x: 42, y: 14, w: 5, h: 1),
        TileData(type: 'block', x: 50, y: 16, w: 8, h: 1),

        // Spikes on the ground
        TileData(type: 'spike', x: 38, y: 18, w: 2, h: 1),

        // Wall
        TileData(type: 'block', x: 46, y: 15, w: 1, h: 4),

        // High platform for ore (hard to reach)
        TileData(type: 'block', x: 25, y: 10, w: 3, h: 1),
      ],
      enemies: [
        EnemyData(x: 22, y: 14, health: 50, damage: 10, speed: 1.0, type: 'basic', patrolRange: 2),
        EnemyData(x: 40, y: 18, health: 80, damage: 15, speed: 0.7, type: 'heavy', patrolRange: 3),
        EnemyData(x: 52, y: 15, health: 30, damage: 8, speed: 1.8, type: 'fast', patrolRange: 2),
      ],
      pickups: [
        PickupData(type: 'health', x: 35, y: 15),
        PickupData(type: 'ore', x: 26, y: 9),
      ],
      architectDialogue: "So... you've decided to struggle. How quaint.",
    );
  }
}
