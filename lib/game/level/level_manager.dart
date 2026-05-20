import 'package:flame/components.dart' hide Block;
import '../components/tutorial_hint.dart';
import '../config.dart';
import '../struggler_game.dart';

import 'level_data.dart';
import 'level_validator.dart';
import 'tile_grid.dart';
import '../components/block.dart';
import '../components/lava.dart';
import '../components/spike.dart';
import '../components/enemy.dart';
import '../components/enemies/skeleton_enemy.dart';
import '../components/enemies/goblin_enemy.dart';
import '../components/enemies/arcane_archer_enemy.dart';
import '../components/enemies/wizard_enemy.dart';
import '../components/enemies/nightborne_enemy.dart';
import '../components/enemies/bringer_enemy.dart';
import '../components/enemies/architect_boss.dart';
import '../components/health_pickup.dart';
import '../components/diamond_pickup.dart';
import '../components/lost_will_pickup.dart';
import '../components/exit_portal.dart';
import '../components/guardian.dart';
import '../components/guardian_portal.dart';
import 'level_theme.dart';

/// Converts a LevelData JSON blueprint into Flame game components.
class LevelManager {
  /// Tile size in pixels. All grid coordinates multiply by this.
  static const double tileSize = GameConfig.tileSize;

  /// Build all components for a level blueprint.
  static Future<List<Component>> buildLevel(
    StruggleGame game,
    LevelData data,
    LevelTheme theme,
  ) async {
    // Validate and sanitize the level data before building
    final validatedData = LevelValidator.validate(data);

    final components = <Component>[];

    // Preprocess tiles into a grid for O(1) neighbor lookups
    final grid = TileGrid.fromTiles(
      validatedData.tiles,
      validatedData.width,
      validatedData.height,
    );
    game.activeGrid = grid;

    // --- Tiles ---
    for (final tile in validatedData.tiles) {
      final pos = Vector2(tile.x * tileSize, tile.y * tileSize);
      final size = Vector2(tile.w * tileSize, tile.h * tileSize);

      switch (tile.type) {
        case 'block':
          components.add(
            PlatformBlock(position: pos, size: size, theme: theme, grid: grid),
          );
          components.add(
            PillarComponent(
              theme: theme,
              grid: grid,
              position: Vector2(pos.x, pos.y + size.y),
              size: Vector2(size.x, 2000),
            ),
          );
          break;
        case 'platform':
          components.add(
            PlatformBlock(
              position: pos,
              size: size,
              theme: theme,
              grid: grid,
              isJumpThrough: true,
            ),
          );
          break;
        case 'lava':
          components.add(
            Lava(position: pos, size: size, theme: theme, grid: grid),
          );
          break;
        case 'spike':
          // Split wide or tall spike tiles into individual 1x1 spikes
          // so every single spike tile evaluates its own neighbors and orients perfectly!
          final int startX = tile.x.toInt();
          final int startY = tile.y.toInt();
          final int w = tile.w.toInt();
          final int h = tile.h.toInt();

          for (int dy = 0; dy < h; dy++) {
            for (int dx = 0; dx < w; dx++) {
              final currentGx = startX + dx;
              final currentGy = startY + dy;
              final individualPos = Vector2(
                currentGx * tileSize,
                currentGy * tileSize,
              );
              final individualSize = Vector2(tileSize, tileSize);

              components.add(
                Spike(
                  position: individualPos,
                  size: individualSize,
                  theme: theme,
                  grid: grid,
                  tileX: currentGx,
                  tileY: currentGy,
                ),
              );
            }
          }
          break;
      }
    }

    // --- Enemies ---
    for (final enemy in validatedData.enemies) {
      final key = '${validatedData.levelId}_enemy_${enemy.x}_${enemy.y}';
      if (game.removedEntitiesKeys.contains(key)) {
        continue; // Already killed, do not respawn!
      }
      final enemyComp = _buildEnemy(enemy);
      enemyComp.spawnData = enemy;
      components.add(enemyComp);
    }

    // --- Pickups ---
    for (final pickup in validatedData.pickups) {
      final key =
          '${validatedData.levelId}_pickup_${pickup.x.round()}_${pickup.y.round()}';
      if (game.removedEntitiesKeys.contains(key) ||
          game.collectedDiamondsKeys.contains(key)) {
        continue; // Already collected, do not respawn!
      }
      final pos = Vector2(pickup.x * tileSize, pickup.y * tileSize);
      switch (pickup.type) {
        case 'health':
          components.add(HealthPickup(position: pos));
          break;
        case 'diamond':
        case 'ore': // Keep fallback for compatibility
          components.add(DiamondPickup(position: pos));
          break;
      }
    }

    // --- Lost Will Spawn ---
    if (validatedData.levelId == game.playerState.lostWillLevelId &&
        game.playerState.lostWillpower > 0) {
      if (game.playerState.lostWillX != null &&
          game.playerState.lostWillY != null) {
        components.add(
          LostWillPickup(
            position: Vector2(
              game.playerState.lostWillX!,
              game.playerState.lostWillY!,
            ),
            willpowerAmount: game.playerState.lostWillpower,
          ),
        );
      }
    }

    // --- Dynamic Guardian & Portal Spawning ---
    if (validatedData.levelId == -1) {
      // Serene Guardian Realm: Spawn return portal at entrance and Guardian in the center
      components.add(
        GuardianPortal(
          position: Vector2(2 * tileSize, 7.5 * tileSize),
          isReturn: true,
        ),
      );
      components.add(Guardian(position: Vector2(7 * tileSize, 7.0 * tileSize)));
    } else if (validatedData.levelId == 0) {
      // Tutorial Level: Place Guardian Portal at zone 12 (under the portal hint)
      components.add(
        GuardianPortal(
          position: Vector2(
            120 * tileSize,
            (validatedData.spawn.y - 0.5) * tileSize,
          ),
          isReturn: false,
        ),
      );
    } else {
      // Normal Level: Spawn entrance portal close to spawn point
      components.add(
        GuardianPortal(
          position: Vector2(
            (validatedData.spawn.x + 2) * tileSize,
            (validatedData.spawn.y - 0.5) * tileSize,
          ),
          isReturn: false,
        ),
      );
    }

    // --- Exit portal ---
    if (validatedData.levelId != -1) {
      components.add(
        ExitPortal(
          position: Vector2(
            validatedData.exit.x * tileSize,
            validatedData.exit.y * tileSize,
          ),
        ),
      );
    }

    // --- Tutorial hints (only for tutorial level 0) ---
    if (validatedData.levelId == 0) {
      components.addAll(_buildTutorialHints());
    }

    return components;
  }

  /// Get spawn position in pixel coordinates.
  static Vector2 getSpawnPosition(LevelData data) {
    return Vector2(data.spawn.x * tileSize, data.spawn.y * tileSize);
  }

  /// Build in-world tutorial hint signs for the tutorial level.
  static List<TutorialHint> _buildTutorialHints() {
    return [
      // Zone 1: Movement
      TutorialHint(
        position: Vector2(5 * tileSize, 15 * tileSize),
        text:
            'Tap the arrows in the bottom-left\n corner to move left and right.',
      ),
      // Zone 2: Attack
      TutorialHint(
        position: Vector2(16 * tileSize, 15 * tileSize),
        text: 'Use the attack button in the bottom-right\n corner to attack.',
      ),
      // Zone 3: Combo
      TutorialHint(
        position: Vector2(26 * tileSize, 15 * tileSize),
        text: 'Chain 3 hits for a combo!\nTap rapidly during swings',
      ),
      // Zone 4: Double Jump
      TutorialHint(
        position: Vector2(36 * tileSize, 13 * tileSize),
        text:
            'Tap the JUMP button, in the bottom-right corner.\nTap twice to double jump.',
      ),
      // Zone 5: Dodge
      TutorialHint(
        position: Vector2(48 * tileSize, 15 * tileSize),
        text:
            'Tap the dodge button, in the bottom-right corner, to Dodge\nYou are invincible during it!\nTime it against attacks!',
      ),
      // Zone 6: Stamina
      TutorialHint(
        position: Vector2(58 * tileSize, 15 * tileSize),
        text:
            'Jumping, attacking\nand dodging cost Stamina (ST)\nIt regenerates on ground',
      ),
      // Zone 7: Pickups
      TutorialHint(
        position: Vector2(68 * tileSize, 14 * tileSize),
        text:
            'Collect Diamonds and\nHealth Pickups!\nDiamonds can be used to upgrade your sword.',
      ),
      // Zone 8: Will & Death
      TutorialHint(
        position: Vector2(78 * tileSize, 15 * tileSize),
        text:
            'Killing enemies earns Will\nDying drops all your Will!\nReturn to reclaim it',
      ),
      // Zone 9: Resolve
      TutorialHint(
        position: Vector2(88 * tileSize, 15 * tileSize),
        text:
            'Killing enemies builds Resolve\nDodging attacks builds Resolve\nFill the RS bar!',
      ),
      // Zone 10: Indomitable
      TutorialHint(
        position: Vector2(98 * tileSize, 15 * tileSize),
        text:
            'When Resolve is FULL\nTap resolve button on the bottom right corner for INDOMITABLE!\nThis grants you defense, double damage and lifesteal!',
      ),
      // Zone 11: Hope the Cat
      TutorialHint(
        position: Vector2(108 * tileSize, 15 * tileSize),
        text:
            'Hope follows you!\nShe attacks nearby enemies\nTap heal button on the bottom right corner to command a Heal\nRemaining Heals are shown in top-right',
      ),
      // Zone 12: Guardian Portal
      TutorialHint(
        position: Vector2(118 * tileSize, 15 * tileSize),
        text:
            'Blue Portals lead to\nthe Guardian Realm\nInteract to enter\nSpend Will on upgrades!',
      ),
      // Zone 13: Exit
      TutorialHint(
        position: Vector2(128 * tileSize, 15 * tileSize),
        text:
            'Defeat ALL enemies\nto unlock the Exit Portal!\nInteract at the portal to proceed',
      ),
    ];
  }

  /// Hardcoded levels
  static LevelData createHardcodedLevel(int levelId) {
    if (levelId == 0) {
      return createTutorialLevel();
    } else if (levelId == 1) {
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
          TileData(type: 'block', x: 18, y: 19, w: 12, h: 1),
          TileData(type: 'block', x: 33, y: 19, w: 27, h: 1),

          // Lava in the gaps
          TileData(type: 'lava', x: 8, y: 17, w: 3, h: 1),

          // Platforms
          TileData(type: 'platform', x: 8, y: 16, w: 4, h: 1),
          TileData(type: 'platform', x: 20, y: 15, w: 5, h: 1),
          TileData(type: 'platform', x: 28, y: 13, w: 3, h: 1),
          TileData(type: 'platform', x: 35, y: 16, w: 4, h: 1),
          TileData(type: 'platform', x: 42, y: 14, w: 5, h: 1),
          TileData(type: 'platform', x: 50, y: 16, w: 8, h: 1),

          // Spikes on the ground
          TileData(type: 'spike', x: 47, y: 18, w: 2, h: 1),

          // Wall
          TileData(type: 'block', x: 46, y: 15, w: 1, h: 4),

          // High platform for ore (hard to reach)
          TileData(type: 'platform', x: 25, y: 10, w: 3, h: 1),
        ],
        enemies: [
          EnemyData(x: 11, y: 14, type: 'skeleton', patrolRange: 2),
          EnemyData(x: 24, y: 18, type: 'bringer', patrolRange: 3),
          EnemyData(x: 35, y: 18, type: 'goblin', patrolRange: 3),
          EnemyData(x: 44, y: 13, type: 'archer', patrolRange: 2),
          EnemyData(x: 48, y: 18, type: 'skeleton', patrolRange: 1),
        ],
        pickups: [
          PickupData(type: 'health', x: 35, y: 15),
          PickupData(type: 'diamond', x: 26, y: 9),
        ],
        architectDialogue: "So... you've decided to struggle. How quaint.",
      );
    } else if (levelId == 2) {
      // LEVEL 2: Vertical Climb — zigzag ascent
      return LevelData(
        levelId: levelId,
        difficulty: 0.5,
        width: 30,
        height: 40,
        spawn: (x: 2, y: 36),
        exit: (x: 25, y: 4),
        tiles: [
          // Ground floor with lava pit underneath
          TileData(type: 'block', x: 0, y: 38, w: 30, h: 2),
          TileData(type: 'lava', x: 6, y: 37, w: 8, h: 1),

          // === ASCENDING PLATFORMS (zigzag) ===
          // Tier 1: Right
          TileData(type: 'platform', x: 7, y: 35, w: 4, h: 1),
          TileData(type: 'platform', x: 15, y: 33, w: 5, h: 1),

          // Tier 2: Left switchback
          TileData(type: 'platform', x: 22, y: 30, w: 4, h: 1),
          TileData(type: 'platform', x: 14, y: 28, w: 5, h: 1),

          // Tier 3: Right again
          TileData(type: 'platform', x: 6, y: 26, w: 4, h: 1),
          TileData(type: 'platform', x: 13, y: 23, w: 5, h: 1),

          // Tier 4: Left switchback with wall obstacle
          TileData(type: 'platform', x: 21, y: 21, w: 4, h: 1),
          TileData(type: 'platform', x: 14, y: 18, w: 5, h: 1),

          // Tier 5: Right
          TileData(type: 'platform', x: 5, y: 16, w: 5, h: 1),
          TileData(type: 'platform', x: 13, y: 13, w: 4, h: 1),

          // Tier 6: Final approach to exit
          TileData(type: 'platform', x: 20, y: 10, w: 4, h: 1),
          TileData(type: 'platform', x: 14, y: 7, w: 4, h: 1),
          TileData(type: 'block', x: 22, y: 5, w: 6, h: 1),

          // Small wall obstacle mid-level
          TileData(type: 'block', x: 11, y: 24, w: 1, h: 3),

          // Spikes on some platforms
          TileData(type: 'spike', x: 16, y: 32, w: 2, h: 1),
          TileData(type: 'spike', x: 15, y: 17, w: 1, h: 1),
        ],
        enemies: [
          EnemyData(x: 18, y: 32, type: 'nightborne', patrolRange: 1),
          EnemyData(x: 15, y: 27, type: 'goblin', patrolRange: 2),
          EnemyData(x: 14, y: 17, type: 'skeleton', patrolRange: 1),
          EnemyData(x: 17, y: 12, type: 'bringer', patrolRange: 1),
          EnemyData(x: 6, y: 15, type: 'archer', patrolRange: 1),
        ],
        pickups: [
          PickupData(type: 'health', x: 22, y: 20),
          PickupData(type: 'diamond', x: 6, y: 15),
        ],
        architectDialogue:
            "You survived the pit. Let's see how you handle heights.",
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
          EnemyData(x: 44, y: 20, type: 'skeleton', patrolRange: 0),
          EnemyData(x: 60, y: 14, type: 'archer', patrolRange: 0),
        ],
        pickups: [
          PickupData(type: 'health', x: 45, y: 19),
          PickupData(type: 'diamond', x: 38, y: 17),
        ],
        architectDialogue: "Fire purifies. Let's see what is left of you.",
      );
    } else if (levelId == 4) {
      // LEVEL 4: The Gauntlet
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
          TileData(type: 'platform', x: 9, y: 17, w: 2, h: 1),
          TileData(type: 'platform', x: 23, y: 16, w: 3, h: 1),
          TileData(type: 'platform', x: 36, y: 17, w: 1, h: 1),

          // Upper path (harder, but has ore)
          TileData(type: 'platform', x: 12, y: 12, w: 4, h: 1),
          TileData(type: 'platform', x: 20, y: 9, w: 4, h: 1),
          TileData(type: 'platform', x: 30, y: 11, w: 3, h: 1),

          // Obstacles on upper path
          TileData(type: 'spike', x: 21, y: 8, w: 1, h: 1),
        ],
        enemies: [
          EnemyData(x: 14, y: 21, type: 'basic', patrolRange: 3),
          EnemyData(x: 29, y: 21, type: 'heavy', patrolRange: 3),
          EnemyData(x: 39, y: 21, type: 'fast', patrolRange: 2),

          // Enemies on upper platforms
          EnemyData(x: 13, y: 11, type: 'fast', patrolRange: 1),
          EnemyData(x: 31, y: 10, type: 'fast', patrolRange: 1),
        ],
        pickups: [
          PickupData(type: 'health', x: 10, y: 15),
          PickupData(type: 'health', x: 24, y: 14),
          PickupData(type: 'diamond', x: 22, y: 7),
        ],
        architectDialogue: "A gauntlet of my own design. Do not disappoint me.",
      );
    } else if (levelId == 5) {
      // LEVEL 5: Chasm of Choice (Split pathway exploration)
      return LevelData(
        levelId: levelId,
        difficulty: 0.6,
        width: 65,
        height: 22,
        spawn: (x: 2, y: 10),
        exit: (x: 60, y: 10),
        tiles: [
          TileData(
            type: 'block',
            x: 0,
            y: 12,
            w: 10,
            h: 10,
          ), // High start block
          TileData(type: 'block', x: 55, y: 12, w: 10, h: 10), // High end block
          TileData(type: 'lava', x: 10, y: 21, w: 45, h: 1), // Pit floor
          // High route (Tight platforms, high risk)
          TileData(type: 'platform', x: 16, y: 8, w: 4, h: 1),
          TileData(type: 'platform', x: 26, y: 6, w: 3, h: 1),
          TileData(type: 'platform', x: 36, y: 6, w: 3, h: 1),
          TileData(type: 'platform', x: 46, y: 8, w: 4, h: 1),

          // Low route (Solid blocks, heavy enemies)
          TileData(type: 'block', x: 15, y: 17, w: 8, h: 1),
          TileData(type: 'block', x: 28, y: 16, w: 10, h: 1),
          TileData(type: 'block', x: 43, y: 17, w: 8, h: 1),
          TileData(type: 'spike', x: 32, y: 15, w: 2, h: 1),
        ],
        enemies: [
          EnemyData(x: 17, y: 16, type: 'heavy', patrolRange: 2),
          EnemyData(x: 45, y: 16, type: 'bringer', patrolRange: 2),
          EnemyData(x: 27, y: 5, type: 'archer', patrolRange: 0),
        ],
        pickups: [
          PickupData(type: 'diamond', x: 31, y: 4), // Reward on high path
          PickupData(type: 'health', x: 33, y: 14),
        ],
        architectDialogue:
            "Paths forge destinies. Choose wisely, or fail rapidly.",
      );
    } else if (levelId == 6) {
      // LEVEL 6: Shifting Spires (Intermittent high-walled tower jumps)
      return LevelData(
        levelId: levelId,
        difficulty: 0.65,
        width: 70,
        height: 20,
        spawn: (x: 2, y: 17),
        exit: (x: 65, y: 17),
        tiles: [
          TileData(type: 'block', x: 0, y: 19, w: 12, h: 1),
          // Massive spire wall structures requiring pop-ups
          TileData(type: 'block', x: 18, y: 10, w: 4, h: 10),
          TileData(type: 'block', x: 32, y: 7, w: 4, h: 13),
          TileData(type: 'block', x: 46, y: 11, w: 4, h: 9),
          TileData(type: 'block', x: 58, y: 19, w: 12, h: 1),

          // Stepping assistance platforms
          TileData(type: 'platform', x: 14, y: 15, w: 2, h: 1),
          TileData(type: 'platform', x: 25, y: 12, w: 4, h: 1),
          TileData(type: 'platform', x: 40, y: 10, w: 3, h: 1),
          TileData(type: 'platform', x: 53, y: 14, w: 3, h: 1),
        ],
        enemies: [
          EnemyData(x: 19, y: 9, type: 'wizard', patrolRange: 1),
          EnemyData(x: 33, y: 6, type: 'archer', patrolRange: 1),
          EnemyData(x: 47, y: 10, type: 'goblin', patrolRange: 1),
        ],
        pickups: [
          PickupData(type: 'diamond', x: 33, y: 5),
          PickupData(type: 'health', x: 26, y: 11),
        ],
        architectDialogue: "You crawl across my monoliths like an insect.",
      );
    } else if (levelId == 7) {
      // LEVEL 7: The Sky Corridors (Precision drop-down challenge)
      return LevelData(
        levelId: levelId,
        difficulty: 0.75,
        width: 60,
        height: 30,
        spawn: (x: 3, y: 4),
        exit: (x: 55, y: 26),
        tiles: [
          // Top Layer
          TileData(type: 'block', x: 0, y: 6, w: 20, h: 1),
          TileData(type: 'spike', x: 10, y: 5, w: 3, h: 1),

          // Middle Drop Layer
          TileData(type: 'block', x: 15, y: 15, w: 25, h: 1),
          TileData(type: 'spike', x: 20, y: 14, w: 6, h: 1),
          TileData(type: 'platform', x: 45, y: 12, w: 5, h: 1),

          // Bottom Escape Layer
          TileData(type: 'block', x: 0, y: 28, w: 60, h: 2),
          TileData(type: 'lava', x: 10, y: 27, w: 30, h: 1),
          TileData(type: 'platform', x: 20, y: 23, w: 4, h: 1),
          TileData(type: 'platform', x: 30, y: 21, w: 4, h: 1),
        ],
        enemies: [
          EnemyData(x: 4, y: 5, type: 'nightborne', patrolRange: 2),
          EnemyData(x: 28, y: 14, type: 'bringer', patrolRange: 3),
          EnemyData(x: 45, y: 27, type: 'heavy', patrolRange: 4),
        ],
        pickups: [
          PickupData(type: 'diamond', x: 38, y: 13),
          PickupData(type: 'health', x: 31, y: 19),
        ],
        architectDialogue:
            "Gravity is a harsh master. I simply supply the floor.",
      );
    } else if (levelId == 8) {
      // LEVEL 8: Corrupted Mines (Spike corridors and fast dynamic enemies)
      return LevelData(
        levelId: levelId,
        difficulty: 0.8,
        width: 75,
        height: 20,
        spawn: (x: 3, y: 16),
        exit: (x: 70, y: 16),
        tiles: [
          TileData(type: 'block', x: 0, y: 18, w: 75, h: 2), // Floor
          // Low overhead crushing roofs
          TileData(type: 'block', x: 15, y: 0, w: 12, h: 13),
          TileData(type: 'block', x: 35, y: 0, w: 15, h: 12),
          TileData(type: 'block', x: 58, y: 0, w: 10, h: 14),

          // Hazards inside the choke points
          TileData(type: 'spike', x: 18, y: 17, w: 4, h: 1),
          TileData(type: 'spike', x: 40, y: 17, w: 5, h: 1),

          // Safety escape steps up near the roofs
          TileData(type: 'platform', x: 13, y: 11, w: 2, h: 1),
          TileData(type: 'platform', x: 32, y: 10, w: 3, h: 1),
          TileData(type: 'platform', x: 55, y: 11, w: 3, h: 1),
        ],
        enemies: [
          EnemyData(x: 10, y: 17, type: 'fast', patrolRange: 2),
          EnemyData(x: 29, y: 17, type: 'fast', patrolRange: 3),
          EnemyData(x: 52, y: 17, type: 'heavy', patrolRange: 2),
          EnemyData(x: 71, y: 17, type: 'wizard', patrolRange: 0),
        ],
        pickups: [
          PickupData(type: 'health', x: 33, y: 8),
          PickupData(type: 'diamond', x: 42, y: 16),
        ],
        architectDialogue: "The air grows thin. Your time grows short.",
      );
    } else if (levelId == 9) {
      // LEVEL 9: Threshold of Doom (Pre-boss test of all mechanics)
      return LevelData(
        levelId: levelId,
        difficulty: 0.85,
        width: 85,
        height: 24,
        spawn: (x: 2, y: 18),
        exit: (x: 80, y: 12),
        tiles: [
          TileData(type: 'block', x: 0, y: 20, w: 20, h: 4),
          TileData(type: 'lava', x: 20, y: 23, w: 45, h: 1),

          // Broken dynamic bridge layout
          TileData(type: 'platform', x: 23, y: 17, w: 3, h: 1),
          TileData(type: 'spike', x: 24, y: 16, w: 1, h: 1),
          TileData(type: 'platform', x: 32, y: 15, w: 4, h: 1),
          TileData(type: 'block', x: 42, y: 14, w: 6, h: 10), // Solid island
          TileData(type: 'platform', x: 54, y: 16, w: 4, h: 1),
          TileData(type: 'platform', x: 62, y: 18, w: 3, h: 1),

          // Rising ending threshold
          TileData(type: 'block', x: 68, y: 14, w: 17, h: 10),
          TileData(type: 'spike', x: 72, y: 13, w: 3, h: 1),
        ],
        enemies: [
          EnemyData(x: 12, y: 19, type: 'heavy', patrolRange: 3),
          EnemyData(x: 44, y: 13, type: 'wizard', patrolRange: 1),
          EnemyData(x: 70, y: 13, type: 'bringer', patrolRange: 1),
          EnemyData(x: 78, y: 13, type: 'archer', patrolRange: 2),
        ],
        pickups: [
          PickupData(type: 'health', x: 45, y: 12),
          PickupData(type: 'diamond', x: 33, y: 13),
          PickupData(type: 'health', x: 63, y: 16),
        ],
        architectDialogue: "You stand outside my inner sanctum. Turn back.",
      );
    } else {
      // LEVEL 10+: The Final Boss Arena
      return LevelData(
        levelId: levelId,
        difficulty: 1.0,
        width: 30,
        height: 20,
        spawn: (x: 2, y: 16),
        exit: (x: 28, y: 16),
        tiles: [
          // Flat floor across the entire arena
          TileData(type: 'block', x: 0, y: 18, w: 30, h: 2),
          // Two side walls to prevent containment loss
          TileData(type: 'block', x: -1, y: 0, w: 1, h: 20),
          TileData(type: 'block', x: 30, y: 0, w: 1, h: 20),
        ],
        enemies: [EnemyData(x: 22, y: 16, type: 'architect', patrolRange: 0)],
        pickups: [PickupData(type: 'health', x: 15, y: 16)],
        architectDialogue: "You've come far... but this ends now.",
      );
    }
  }

  /// Returns the map layout for a specific phase of the Architect boss fight.
  static List<TileData> getBossPhaseTiles(int phase) {
    // Shared floor and walls
    final baseArena = [
      TileData(type: 'block', x: 0, y: 18, w: 30, h: 2), // Floor
      TileData(type: 'block', x: -1, y: 0, w: 1, h: 20), // Left Wall
      TileData(type: 'block', x: 30, y: 0, w: 1, h: 20), // Right Wall
    ];

    switch (phase) {
      case 1:
        // Phase 1 (80%): Lava pit appears in middle
        return baseArena..addAll([
          TileData(type: 'lava', x: 10, y: 18, w: 10, h: 1),
          TileData(type: 'platform', x: 12, y: 15, w: 6, h: 1),
        ]);
      case 2:
        // Phase 2 (60%): Floating platforms and spikes
        return baseArena..addAll([
          TileData(type: 'lava', x: 5, y: 18, w: 20, h: 1),
          TileData(type: 'platform', x: 5, y: 14, w: 4, h: 1),
          TileData(type: 'platform', x: 21, y: 14, w: 4, h: 1),
          TileData(type: 'platform', x: 13, y: 10, w: 4, h: 1),
          TileData(type: 'spike', x: 14, y: 9, w: 2, h: 1),
        ]);
      case 3:
        // Phase 3 (40%): Moving to a high arena with spikes on the walls
        return baseArena..addAll([
          TileData(type: 'spike', x: 0, y: 10, w: 1, h: 8), // Left wall spikes
          TileData(
            type: 'spike',
            x: 29,
            y: 10,
            w: 1,
            h: 8,
          ), // Right wall spikes
          TileData(type: 'lava', x: 2, y: 18, w: 26, h: 1),
          TileData(type: 'platform', x: 2, y: 14, w: 3, h: 1),
          TileData(type: 'platform', x: 10, y: 11, w: 3, h: 1),
          TileData(type: 'platform', x: 17, y: 11, w: 3, h: 1),
          TileData(type: 'platform', x: 25, y: 14, w: 3, h: 1),
        ]);
      case 4:
        // Phase 4 (20%): Total chaos
        return baseArena..addAll([
          TileData(type: 'lava', x: 1, y: 18, w: 28, h: 1),
          TileData(type: 'platform', x: 1, y: 15, w: 2, h: 1),
          TileData(type: 'platform', x: 7, y: 12, w: 2, h: 1),
          TileData(type: 'platform', x: 14, y: 9, w: 2, h: 1),
          TileData(type: 'platform', x: 21, y: 12, w: 2, h: 1),
          TileData(type: 'platform', x: 27, y: 15, w: 2, h: 1),
          TileData(type: 'spike', x: 14, y: 8, w: 2, h: 1),
        ]);
      default:
        // Phase 0 (100% to 80%)
        return baseArena;
    }
  }

  /// Creates a serene 15x10 sub-level representing the Guardian's Realm.
  static LevelData createGuardianRealm() {
    return LevelData(
      levelId: -1,
      difficulty: 0.0,
      width: 15,
      height: 10,
      spawn: (x: 2, y: 7),
      exit: (x: 13, y: 7), // exit portal is ignored or acts as normal exit
      tiles: [
        // Floor
        TileData(type: 'block', x: 0, y: 9, w: 15, h: 1),
        // Ceiling
        TileData(type: 'block', x: 0, y: 0, w: 15, h: 1),
        // Left wall
        TileData(type: 'block', x: 0, y: 1, w: 1, h: 8),
        // Right wall
        TileData(type: 'block', x: 14, y: 1, w: 1, h: 8),
      ],
      enemies: [],
      pickups: [],
      architectDialogue:
          "You have stepped into the Guardian's sanctuary. Peace and strength await.",
    );
  }

  /// Creates the tutorial level (level 0) — a wide horizontal map with zones
  /// that teach every game mechanic in sequence.
  static LevelData createTutorialLevel() {
    return LevelData(
      levelId: 0,
      difficulty: 0.0,
      width: 140,
      height: 25,
      spawn: (x: 2, y: 18),
      exit: (x: 135, y: 18),
      tiles: [
        // ======= CONTINUOUS GROUND FLOOR =======
        TileData(type: 'block', x: 0, y: 20, w: 140, h: 5),

        // ======= ZONE 4: Double Jump Gap =======
        // Gap in the ground that requires double jump to cross
        // We place platforms above the gap instead
        TileData(type: 'platform', x: 38, y: 16, w: 3, h: 1),
        TileData(type: 'platform', x: 43, y: 14, w: 3, h: 1),
        TileData(type: 'platform', x: 38, y: 12, w: 3, h: 1),

        // ======= ZONE 7: Elevated platform for diamond =======
        TileData(type: 'platform', x: 68, y: 16, w: 4, h: 1),

        // ======= ZONE 9-10: Some cover platforms =======
        TileData(type: 'platform', x: 92, y: 17, w: 3, h: 1),

        // ======= ZONE 5: Spikes to dodge through =======
        TileData(type: 'spike', x: 50, y: 19, w: 2, h: 1),

        // ======= Small walls for zone separation feel =======
        TileData(type: 'block', x: 33, y: 17, w: 1, h: 3),
        TileData(type: 'block', x: 55, y: 17, w: 1, h: 3),
        TileData(type: 'block', x: 75, y: 17, w: 1, h: 3),
        TileData(type: 'block', x: 105, y: 17, w: 1, h: 3),
        TileData(type: 'block', x: 125, y: 17, w: 1, h: 3),
      ],
      enemies: [
        // Zone 2: Single weak skeleton to practice attacking
        EnemyData(x: 20, y: 19, type: 'skeleton', patrolRange: 3),
        // Zone 3: Two goblins for combo practice
        EnemyData(x: 28, y: 19, type: 'goblin', patrolRange: 2),
        EnemyData(x: 30, y: 19, type: 'goblin', patrolRange: 2),
        // Zone 5: Nightborne to practice dodging against
        EnemyData(x: 52, y: 19, type: 'nightborne', patrolRange: 2),
        // Zone 8-9: Enemies for will/resolve building
        EnemyData(x: 82, y: 19, type: 'skeleton', patrolRange: 3),
        EnemyData(x: 85, y: 19, type: 'goblin', patrolRange: 2),
        // Zone 10: Bringer to test indomitable on
        EnemyData(x: 100, y: 19, type: 'bringer', patrolRange: 3),
        // Zone 11: Enemies near Hope to show her attacking
        EnemyData(x: 112, y: 19, type: 'skeleton', patrolRange: 2),
        // Zone 13: Final enemies guarding the exit
        EnemyData(x: 130, y: 19, type: 'goblin', patrolRange: 3),
        EnemyData(x: 133, y: 19, type: 'skeleton', patrolRange: 2),
      ],
      pickups: [
        // Zone 7: Collectibles
        PickupData(type: 'health', x: 65, y: 19),
        PickupData(type: 'diamond', x: 69, y: 15),
        // Zone 8: Health in combat area
        PickupData(type: 'health', x: 80, y: 19),
      ],
      architectDialogue:
          "Welcome, Struggler. This is your first and last lesson.",
      enemyDamageMultiplier: 0.3,
      enemyHealthMultiplier: 0.3,
    );
  }

  /// Factory mapping of JSON EnemyData to concrete dynamic subclasses.
  /// Standardises legacy IDs ("basic", "heavy", "fast") for backward compat.
  static BaseEnemy _buildEnemy(EnemyData data) {
    final pos = Vector2(data.x * tileSize, data.y * tileSize);
    final type = data.type.toLowerCase();
    final BaseEnemy enemy;

    switch (type) {
      case 'skeleton':
      case 'basic': // Legacy alias
        enemy = SkeletonEnemy(position: pos);
        break;

      case 'goblin':
      case 'fast': // Legacy alias
        enemy = GoblinEnemy(position: pos);
        break;

      case 'nightborne':
      case 'nightborn':
      case 'heavy': // Legacy alias
        enemy = NightborneEnemy(position: pos);
        break;

      case 'bringer':
        enemy = BringerEnemy(position: pos);
        break;

      case 'archer':
      case 'arcane_archer':
        enemy = ArcaneArcherEnemy(position: pos);
        break;

      case 'wizard':
        enemy = WizardEnemy(position: pos);
        break;

      case 'architect':
        enemy = ArchitectBoss(position: pos);
        break;

      default:
        // Absolute fallback: skeleton
        enemy = SkeletonEnemy(position: pos);
        break;
    }

    enemy.spawnData = data;
    return enemy;
  }
}
