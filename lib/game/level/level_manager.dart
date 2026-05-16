import 'package:flame/components.dart' hide Block;
import 'package:flame/game.dart';

import 'level_data.dart';
import 'tile_grid.dart';
import '../components/block.dart';
import '../components/lava.dart';
import '../components/spike.dart';
import '../components/enemy.dart';
import '../components/health_pickup.dart';
import '../components/ore_pickup.dart';
import '../components/exit_portal.dart';
import 'level_theme.dart';

/// Converts a LevelData JSON blueprint into Flame game components.
class LevelManager {
  /// Tile size in pixels. All grid coordinates multiply by this.
  static const double tileSize = 32.0;

  /// Build all components for a level blueprint.
  static Future<List<Component>> buildLevel(
    FlameGame game,
    LevelData data,
    LevelTheme theme,
  ) async {
    final components = <Component>[];

    // Preprocess tiles into a grid for O(1) neighbor lookups
    final grid = TileGrid.fromTiles(data.tiles, data.width, data.height);

    // --- Tiles ---
    for (final tile in data.tiles) {
      final pos = Vector2(tile.x * tileSize, tile.y * tileSize);
      final size = Vector2(tile.w * tileSize, tile.h * tileSize);

      switch (tile.type) {
        case 'block':
          components.add(PlatformBlock(
            position: pos,
            size: size,
            theme: theme,
            grid: grid,
          ));
          components.add(PillarComponent(
            theme: theme,
            grid: grid,
            position: Vector2(pos.x, pos.y + size.y),
            size: Vector2(size.x, 2000),
          ));
          break;
        case 'lava':
          components.add(Lava(position: pos, size: size, theme: theme));
          break;
        case 'spike':
          components.add(Spike(position: Vector2(pos.x, pos.y + 3), size: size, theme: theme));
          break;
      }
    }

    // --- Enemies ---
    for (final enemy in data.enemies) {
      components.add(Enemy(
        position: Vector2(enemy.x * tileSize, enemy.y * tileSize),
        maxHealth: enemy.health,
        contactDamage: enemy.damage,
        speed: enemy.speed * 60,
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

  /// Hardcoded test levels for development before AI integration.
  static LevelData createTestLevel(int levelId) {
    if (levelId == 1) {
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
          TileData(type: 'block', x: 15, y: 20, w: 3, h: 1),
          TileData(type: 'block', x: 18, y: 19, w: 12, h: 1),
          TileData(type: 'block', x: 33, y: 19, w: 27, h: 1),

          // Lava in the gaps
          TileData(type: 'lava', x: 15, y: 19, w: 3, h: 1),

          // Platforms
          TileData(type: 'block', x: 8, y: 16, w: 4, h: 1),
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
    } else if (levelId == 2) {
      // LEVEL 2: Vertical Climb
      return LevelData(
        levelId: levelId,
        difficulty: 0.5,
        width: 30,
        height: 40,
        spawn: (x: 2, y: 36),
        exit: (x: 25, y: 4),
        tiles: [
          // Ground floor (lava underneath)
          TileData(type: 'lava', x: 0, y: 39, w: 30, h: 1),
          TileData(type: 'block', x: 0, y: 38, w: 6, h: 1),
          
          // Stepping stones up
          TileData(type: 'block', x: 8, y: 34, w: 3, h: 1),
          TileData(type: 'block', x: 14, y: 31, w: 4, h: 1),
          TileData(type: 'block', x: 22, y: 28, w: 3, h: 1),
          
          // Switchback
          TileData(type: 'block', x: 12, y: 24, w: 6, h: 1),
          TileData(type: 'block', x: 2, y: 20, w: 5, h: 1),
          
          // A wall that forces you to go around
          TileData(type: 'block', x: 15, y: 15, w: 2, h: 10),
          
          // More climbing
          TileData(type: 'block', x: 9, y: 16, w: 4, h: 1),
          TileData(type: 'block', x: 20, y: 13, w: 3, h: 1),
          TileData(type: 'block', x: 10, y: 9, w: 5, h: 1),
          TileData(type: 'block', x: 22, y: 5, w: 6, h: 1),
          
          // Spikes on some platforms
          TileData(type: 'spike', x: 13, y: 23, w: 2, h: 1),
          TileData(type: 'spike', x: 3, y: 19, w: 1, h: 1),
          TileData(type: 'spike', x: 11, y: 8, w: 2, h: 1),
        ],
        enemies: [
          EnemyData(x: 14, y: 30, health: 50, damage: 10, speed: 1.0, type: 'basic', patrolRange: 2),
          EnemyData(x: 12, y: 23, health: 50, damage: 10, speed: 1.2, type: 'basic', patrolRange: 1),
          EnemyData(x: 10, y: 8, health: 30, damage: 5, speed: 2.0, type: 'fast', patrolRange: 2),
        ],
        pickups: [
          PickupData(type: 'health', x: 2, y: 19),
          PickupData(type: 'ore', x: 2, y: 10),
        ],
        architectDialogue: "You survived the pit. Let's see how you handle heights.",
      );
    } else if (levelId == 3) {
      // LEVEL 3: Lava Caverns
      return LevelData(
        levelId: levelId,
        difficulty: 0.7,
        width: 80,
        height: 25,
        spawn: (x: 2, y: 5),
        exit: (x: 75, y: 5),
        tiles: [
          // Starting platform high up
          TileData(type: 'block', x: 0, y: 7, w: 8, h: 1),
          // Giant lava lake at the bottom
          TileData(type: 'lava', x: 0, y: 22, w: 80, h: 2),
          
          // Stepping stones dropping into the cavern
          TileData(type: 'block', x: 10, y: 10, w: 3, h: 1),
          TileData(type: 'block', x: 16, y: 14, w: 4, h: 1),
          TileData(type: 'block', x: 23, y: 18, w: 5, h: 1),
          
          // Lava pillars to hop across
          TileData(type: 'block', x: 32, y: 21, w: 2, h: 1),
          TileData(type: 'block', x: 38, y: 20, w: 2, h: 1),
          TileData(type: 'block', x: 44, y: 21, w: 3, h: 1),
          TileData(type: 'block', x: 52, y: 18, w: 4, h: 1),
          
          // Path back up
          TileData(type: 'block', x: 59, y: 15, w: 4, h: 1),
          TileData(type: 'block', x: 66, y: 11, w: 3, h: 1),
          TileData(type: 'block', x: 73, y: 7, w: 7, h: 1),
          
          // A ceiling to make jumping tight in some spots
          TileData(type: 'block', x: 15, y: 0, w: 50, h: 5),
          
          // Spikes
          TileData(type: 'spike', x: 25, y: 17, w: 2, h: 1),
          TileData(type: 'spike', x: 53, y: 17, w: 2, h: 1),
        ],
        enemies: [
          EnemyData(x: 24, y: 17, health: 80, damage: 15, speed: 0.8, type: 'heavy', patrolRange: 2),
          EnemyData(x: 44, y: 20, health: 30, damage: 10, speed: 0.0, type: 'basic', patrolRange: 0),
          EnemyData(x: 60, y: 14, health: 50, damage: 10, speed: 1.5, type: 'fast', patrolRange: 2),
        ],
        pickups: [
          PickupData(type: 'health', x: 45, y: 19),
          PickupData(type: 'ore', x: 38, y: 17),
        ],
        architectDialogue: "Fire purifies. Let's see what is left of you.",
      );
    } else {
      // LEVEL 4+: The Gauntlet
      return LevelData(
        levelId: levelId,
        difficulty: 0.9,
        width: 50,
        height: 25,
        spawn: (x: 2, y: 20),
        exit: (x: 45, y: 20),
        tiles: [
          // Flat floor, but full of enemies and spikes
          TileData(type: 'block', x: 0, y: 22, w: 50, h: 1),
          
          // Spike pits
          TileData(type: 'spike', x: 8, y: 21, w: 4, h: 1),
          TileData(type: 'spike', x: 22, y: 21, w: 5, h: 1),
          TileData(type: 'spike', x: 35, y: 21, w: 3, h: 1),
          
          // Floating platforms above spikes to jump on
          TileData(type: 'block', x: 9, y: 17, w: 2, h: 1),
          TileData(type: 'block', x: 23, y: 16, w: 3, h: 1),
          TileData(type: 'block', x: 36, y: 17, w: 1, h: 1),
          
          // Upper path (harder, but has ore)
          TileData(type: 'block', x: 12, y: 12, w: 4, h: 1),
          TileData(type: 'block', x: 20, y: 9, w: 4, h: 1),
          TileData(type: 'block', x: 30, y: 11, w: 3, h: 1),
          
          // Obstacles on upper path
          TileData(type: 'spike', x: 21, y: 8, w: 1, h: 1),
        ],
        enemies: [
          EnemyData(x: 14, y: 21, health: 50, damage: 10, speed: 1.2, type: 'basic', patrolRange: 3),
          EnemyData(x: 29, y: 21, health: 80, damage: 15, speed: 0.5, type: 'heavy', patrolRange: 3),
          EnemyData(x: 39, y: 21, health: 50, damage: 10, speed: 2.0, type: 'fast', patrolRange: 2),
          
          // Enemies on upper platforms
          EnemyData(x: 13, y: 11, health: 30, damage: 5, speed: 1.0, type: 'fast', patrolRange: 1),
          EnemyData(x: 31, y: 10, health: 30, damage: 5, speed: 1.0, type: 'fast', patrolRange: 1),
        ],
        pickups: [
          PickupData(type: 'health', x: 10, y: 15),
          PickupData(type: 'health', x: 24, y: 14),
          PickupData(type: 'ore', x: 22, y: 7),
        ],
        architectDialogue: "A gauntlet of my own design. Do not disappoint me.",
      );
    }
  }
}
