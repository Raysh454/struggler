import 'dart:math';
import 'level_data.dart';
import '../config.dart';

/// Validates and sanitizes AI-generated LevelData to guarantee:
/// 1. No floating lava/spikes (must be anchored to blocks)
/// 2. Level is solvable (spawn → exit reachable via player movement)
/// 3. Spawn/exit zones are safe (no overlapping hazards)
///
/// Uses player physics constants to determine reachability.
class LevelValidator {
  static List<String>? _activeFeedbackLogs;

  static void _log(String message) {
    print(message);
    _activeFeedbackLogs?.add(message);
  }

  // --- Player Physics Constraints (conservative, with safety margins) ---
  // From player.dart: jumpForce=-400, gravity=900, moveSpeed=200,
  // dodgeSpeed=450, dodgeDuration=0.2, maxJumps=2
  //
  // Single jump height: v²/(2g) = 160000/1800 ≈ 2.78 tiles
  // Double jump height: ~5.56 tiles
  // Single jump horizontal: moveSpeed × 0.889s ≈ 5.56 tiles
  // Double jump horizontal: moveSpeed × 1.517s ≈ 9.48 tiles
  // Dodge adds: 450 × 0.2 / 32 ≈ 2.81 tiles
  // Max horizontal (DJ + dodge): ~12.3 tiles
  //
  // We use conservative values so levels are comfortably solvable:
  static const int maxJumpHeight = GameConfig.validatorMaxJumpHeight;      // tiles upward (from 5.56)
  static const int maxHorizontalGap = GameConfig.validatorMaxHorizontalGap;  // tiles across (from 12.3)
  static const int spawnSafeRadius = GameConfig.validatorSpawnSafeRadius;    // tiles around spawn free of hazards
  static const int exitSafeRadius = GameConfig.validatorExitSafeRadius;     // tiles around exit free of hazards
  static const int maxRepairIterations = GameConfig.validatorMaxRepairIterations;

  /// Validate and sanitize the level data.
  /// Returns a new [LevelData] that is guaranteed to be solvable,
  /// or falls back to [fallbackLevel] if repair fails.
  static LevelData validate(LevelData data, {LevelData? fallbackLevel, List<String>? feedbackLogs}) {
    _activeFeedbackLogs = feedbackLogs;
    try {
      var tiles = List<TileData>.from(data.tiles);
      var enemies = List<EnemyData>.from(data.enemies);
      var pickups = List<PickupData>.from(data.pickups);

      // Phase 1: Tile Sanitization
      tiles = _sanitizeTiles(tiles, data.width, data.height);
      
      // Phase 1.5: Lava Containment
      tiles = _ensureLavaContainment(tiles, data.width, data.height);
      
      enemies = _sanitizeEnemies(enemies, tiles, data.width, data.height);
      pickups = _sanitizePickups(pickups, tiles, data.width, data.height);

      // Phase 2: Spawn/Exit Safety
      final spawn = data.spawn;
      final exit = data.exit;
      tiles = _ensureSpawnSafety(tiles, spawn, data.width, data.height);
      tiles = _ensureExitSafety(tiles, exit, data.width, data.height);

      // Phase 3: Reachability — BFS and auto-bridge
      for (int attempt = 0; attempt < maxRepairIterations; attempt++) {
        final grid = _buildGrid(tiles, data.width, data.height);
        final surfaces = _findSurfaces(grid, data.width, data.height);

        if (surfaces.isEmpty) {
          _log('[LevelValidator] Validation error: No solid surfaces found in the map.');
          break;
        }

        final spawnSurface = _findNearestSurface(surfaces, spawn.x.round(), spawn.y.round());
        final exitSurface = _findNearestSurface(surfaces, exit.x.round(), exit.y.round());

        if (spawnSurface == null) {
          _log('[LevelValidator] Validation error: Spawn point is not near any solid surface.');
          break;
        }
        if (exitSurface == null) {
          _log('[LevelValidator] Validation error: Exit portal is not near any solid surface.');
          break;
        }

        final reachable = _bfsReachability(surfaces, spawnSurface, grid);

        if (reachable.contains(exitSurface)) {
          // Level is solvable!
          _log('[LevelValidator] Success: Level is solvable after $attempt repair iterations.');
          return data._copyWith(tiles: tiles, enemies: enemies, pickups: pickups);
        }

        // Try to bridge the gap
        final bridgeTiles = _buildBridges(surfaces, reachable, exitSurface, data.width, data.height);
        if (bridgeTiles.isEmpty) {
          _log('[LevelValidator] Validation error: Gap is too wide to bridge.');
          break; // Can't fix it
        }
        _log('[LevelValidator] Added ${bridgeTiles.length} bridge/assist platforms to connect reachable sections.');
        tiles.addAll(bridgeTiles);
      }

      // Final check after all repairs
      final grid = _buildGrid(tiles, data.width, data.height);
      final surfaces = _findSurfaces(grid, data.width, data.height);
      final spawnSurface = _findNearestSurface(surfaces, data.spawn.x.round(), data.spawn.y.round());
      final exitSurface = _findNearestSurface(surfaces, data.exit.x.round(), data.exit.y.round());

      if (spawnSurface != null && exitSurface != null) {
        final reachable = _bfsReachability(surfaces, spawnSurface, grid);
        if (reachable.contains(exitSurface)) {
          _log('[LevelValidator] Success: Level was repaired successfully and is now solvable.');
          return data._copyWith(tiles: tiles, enemies: enemies, pickups: pickups);
        }
      }

      // Repair failed — use fallback
      _log('[LevelValidator] WARNING: Could not repair level ${data.levelId}, using fallback');
      return fallbackLevel ?? data._copyWith(tiles: tiles, enemies: enemies, pickups: pickups);
    } finally {
      _activeFeedbackLogs = null;
    }
  }

  /// Quick check if the level is solvable/reachable from spawn to exit.
  static bool isSolvable(LevelData data) {
    final tiles = List<TileData>.from(data.tiles);
    final grid = _buildGrid(tiles, data.width, data.height);
    final surfaces = _findSurfaces(grid, data.width, data.height);
    if (surfaces.isEmpty) return false;
    final spawnSurface = _findNearestSurface(surfaces, data.spawn.x.round(), data.spawn.y.round());
    final exitSurface = _findNearestSurface(surfaces, data.exit.x.round(), data.exit.y.round());
    if (spawnSurface == null || exitSurface == null) return false;
    final reachable = _bfsReachability(surfaces, spawnSurface, grid);
    return reachable.contains(exitSurface);
  }

  // ========================================================================
  // PHASE 1: Tile Sanitization
  // ========================================================================

  /// Remove floating lava and spikes that aren't anchored to blocks.
  /// Also converts any solid BLOCK that is floating (no solid tile directly
  /// beneath it) into a PLATFORM so the player can always jump through it.
  static List<TileData> _sanitizeTiles(List<TileData> tiles, int mapWidth, int mapHeight) {
    final grid = _buildGrid(tiles, mapWidth, mapHeight);
    final sanitized = <TileData>[];

    for (final tile in tiles) {
      if (tile.type == 'block' || tile.type == 'platform') {
        // --- Floating-block → platform conversion ---
        // A block is "floating" if ALL cells in its bottom row have no solid
        // tile directly beneath them AND it is not touching the map floor.
        if (tile.type == 'block') {
          final bottomRow = (tile.y + tile.h).round();
          // Floor tile or underground — always keep as solid block.
          if (bottomRow >= mapHeight) {
            sanitized.add(tile);
            continue;
          }
          bool hasSupport = false;
          final startX = tile.x.round();
          final endX = (tile.x + tile.w).round();
          for (int bx = startX; bx < endX && bx < mapWidth; bx++) {
            if (bottomRow < grid.length && bx < grid[0].length &&
                (grid[bottomRow][bx] == 'block' || grid[bottomRow][bx] == 'platform')) {
              hasSupport = true;
              break;
            }
          }
          if (!hasSupport) {
            // Convert to pass-through platform so the player isn't blocked from below
            sanitized.add(TileData(
              type: 'platform',
              x: tile.x, y: tile.y, w: tile.w, h: tile.h,
            ));
            _log('[LevelValidator] Converted floating BLOCK at (${tile.x}, ${tile.y}) to PLATFORM');
            continue;
          }
        }
        sanitized.add(tile);
        continue;
      }

      if (tile.type == 'lava') {
        if (_overlapsWithSolid(tile, grid, mapWidth, mapHeight)) {
          _log('[LevelValidator] Removed overlapping lava at (${tile.x}, ${tile.y})');
          continue;
        }
        if (_isLavaAnchored(tile, grid, mapWidth, mapHeight)) {
          sanitized.add(tile);
        } else {
          _log('[LevelValidator] Removed floating lava at (${tile.x}, ${tile.y})');
        }
        continue;
      }

      if (tile.type == 'spike') {
        // Split wide or tall spikes into individual 1x1 sub-spikes
        // to check overlaps and anchors cell-by-cell!
        final wTiles = tile.w.round();
        final hTiles = tile.h.round();
        for (int dy = 0; dy < hTiles; dy++) {
          for (int dx = 0; dx < wTiles; dx++) {
            final sx = tile.x.round() + dx;
            final sy = tile.y.round() + dy;

            if (sx < 0 || sx >= mapWidth + 10 || sy < 0 || sy >= mapHeight + 10) continue;

            // Check direct overlap with solid block/platform
            if (grid[sy][sx] == 'block' || grid[sy][sx] == 'platform') {
              _log('[LevelValidator] Removed overlapping spike at ($sx, $sy)');
              continue;
            }

            final individualTile = TileData(
              type: 'spike',
              x: sx.toDouble(),
              y: sy.toDouble(),
              w: 1.0,
              h: 1.0,
            );

            bool anchored = _isSpikeAnchored(individualTile, grid, mapWidth, mapHeight);
            TileData processedTile = individualTile;

            if (!anchored) {
              // Check if there is a wall 2 tiles to the left (meaning sx - 2 is solid)
              if (sx - 2 >= 0 && (grid[sy][sx - 2] == 'block' || grid[sy][sx - 2] == 'platform')) {
                processedTile = TileData(
                  type: 'spike',
                  x: (sx - 1).toDouble(),
                  y: sy.toDouble(),
                  w: 1.0,
                  h: 1.0,
                );
                anchored = true;
                _log('[LevelValidator] Healed misplaced left-wall spike by shifting x from $sx to ${processedTile.x}');
              }
              // Check if there is a wall 2 tiles to the right (meaning sx + 2 is solid)
              else if (sx + 2 < mapWidth + 10 && (grid[sy][sx + 2] == 'block' || grid[sy][sx + 2] == 'platform')) {
                processedTile = TileData(
                  type: 'spike',
                  x: (sx + 1).toDouble(),
                  y: sy.toDouble(),
                  w: 1.0,
                  h: 1.0,
                );
                anchored = true;
                _log('[LevelValidator] Healed misplaced right-wall spike by shifting x from $sx to ${processedTile.x}');
              }
              // Check if there is a floor 2 tiles below (meaning sy + 2 is solid)
              else if (sy + 2 < mapHeight + 10 && (grid[sy + 2][sx] == 'block' || grid[sy + 2][sx] == 'platform')) {
                processedTile = TileData(
                  type: 'spike',
                  x: sx.toDouble(),
                  y: (sy + 1).toDouble(),
                  w: 1.0,
                  h: 1.0,
                );
                anchored = true;
                _log('[LevelValidator] Healed misplaced floor spike by shifting y from $sy to ${processedTile.y}');
              }
              // Check if there is a ceiling 2 tiles above (meaning sy - 2 is solid)
              else if (sy - 2 >= 0 && (grid[sy - 2][sx] == 'block' || grid[sy - 2][sx] == 'platform')) {
                processedTile = TileData(
                  type: 'spike',
                  x: sx.toDouble(),
                  y: (sy - 1).toDouble(),
                  w: 1.0,
                  h: 1.0,
                );
                anchored = true;
                _log('[LevelValidator] Healed misplaced ceiling spike by shifting y from $sy to ${processedTile.y}');
              }
            }

            if (anchored || _isSpikeAnchored(processedTile, grid, mapWidth, mapHeight)) {
              // Ensure the healed position does not overlap with any solid either!
              final px = processedTile.x.round();
              final py = processedTile.y.round();
              if (grid[py][px] != 'block' && grid[py][px] != 'platform') {
                sanitized.add(processedTile);
              } else {
                _log('[LevelValidator] Removed healed spike at ($px, $py) because it overlaps with a solid block');
              }
            } else {
              _log('[LevelValidator] Removed floating spike at ($sx, $sy)');
            }
          }
        }
        continue;
      }

      // Unknown type — keep it
      sanitized.add(tile);
    }

    return sanitized;
  }

  /// Ensures all lava tiles are properly contained within a pit by adding a wall
  /// to the left and right if they are exposed.
  static List<TileData> _ensureLavaContainment(List<TileData> tiles, int w, int h) {
    var sanitized = List<TileData>.from(tiles);
    final grid = _buildGrid(sanitized, w, h);

    for (final tile in tiles) {
      if (tile.type == 'lava') {
        final lavaY = tile.y.round();
        final startX = tile.x.round();
        final endX = (tile.x + tile.w).round();

        // Check left edge
        if (startX > 0 && lavaY >= 0 && lavaY < h) {
          for (int dy = 0; dy < tile.h; dy++) {
             final y = lavaY + dy;
             if (y < h && grid[y][startX - 1] != 'block' && grid[y][startX - 1] != 'platform') {
               sanitized.add(TileData(type: 'block', x: (startX - 1).toDouble(), y: y.toDouble(), w: 1.0, h: 1.0));
               grid[y][startX - 1] = 'block';
               _log('[LevelValidator] Built left lava containment wall at (${startX - 1}, $y)');
             }
          }
        }

        // Check right edge
        if (endX < w && lavaY >= 0 && lavaY < h) {
          for (int dy = 0; dy < tile.h; dy++) {
             final y = lavaY + dy;
             if (y < h && grid[y][endX] != 'block' && grid[y][endX] != 'platform') {
               sanitized.add(TileData(type: 'block', x: endX.toDouble(), y: y.toDouble(), w: 1.0, h: 1.0));
               grid[y][endX] = 'block';
               _log('[LevelValidator] Built right lava containment wall at ($endX, $y)');
             }
          }
        }
      }
    }
    return sanitized;
  }

  /// Checks if any cell in the given tile overlaps with a solid block or platform.
  static bool _overlapsWithSolid(TileData tile, List<List<String?>> grid, int w, int h) {
    final startX = tile.x.round();
    final endX = (tile.x + tile.w).round();
    final startY = tile.y.round();
    final endY = (tile.y + tile.h).round();

    for (int y = startY; y < endY; y++) {
      if (y < 0 || y >= grid.length) continue;
      for (int x = startX; x < endX; x++) {
        if (x < 0 || x >= grid[0].length) continue;
        if (grid[y][x] == 'block' || grid[y][x] == 'platform') {
          return true;
        }
      }
    }
    return false;
  }

  /// Lava is anchored if:
  /// - It sits directly on top of a block row, OR
  /// - It's at the bottom of the map (y + h >= mapHeight - 1), OR
  /// - There's a block directly below the lava's full width
  static bool _isLavaAnchored(TileData lava, List<List<String?>> grid, int w, int h) {
    final bottomY = (lava.y + lava.h).round();

    // At the bottom of the map — acts as a void/pit
    if (bottomY >= h - 1) return true;

    // Check if there's solid ground below the entire width of the lava
    final startX = lava.x.round();
    final endX = (lava.x + lava.w).round();

    // Allow lava that sits directly on blocks
    for (int x = startX; x < endX && x < w; x++) {
      if (x < 0) continue;
      if (bottomY >= 0 && bottomY < h && (grid[bottomY][x] == 'block' || grid[bottomY][x] == 'platform')) {
        continue; // This column is supported
      }
      // Also allow if lava is filling a gap between blocks (lava at same Y as blocks)
      final lavaY = lava.y.round();
      bool hasBlockAdjacent = false;
      // Check left and right for blocks at the same Y
      if (startX > 0 && lavaY >= 0 && lavaY < h && (grid[lavaY][startX - 1] == 'block' || grid[lavaY][startX - 1] == 'platform')) {
        hasBlockAdjacent = true;
      }
      if (endX < w && lavaY >= 0 && lavaY < h && (grid[lavaY][endX] == 'block' || grid[lavaY][endX] == 'platform')) {
        hasBlockAdjacent = true;
      }
      if (!hasBlockAdjacent) return false;
    }
    return true;
  }

  /// Spike is anchored if there's a block below, above, left, or right.
  static bool _isSpikeAnchored(TileData spike, List<List<String?>> grid, int w, int h) {
    final startX = spike.x.round();
    final endX = (spike.x + spike.w).round();
    final y = spike.y.round();

    for (int x = startX; x < endX && x < w; x++) {
      if (x < 0) continue;
      
      // Check below
      if (y + 1 < h && (grid[y + 1][x] == 'block' || grid[y + 1][x] == 'platform')) return true;
      // Check above
      if (y - 1 >= 0 && (grid[y - 1][x] == 'block' || grid[y - 1][x] == 'platform')) return true;
      // Check left
      if (x - 1 >= 0 && (grid[y][x - 1] == 'block' || grid[y][x - 1] == 'platform')) return true;
      // Check right
      if (x + 1 < w && (grid[y][x + 1] == 'block' || grid[y][x + 1] == 'platform')) return true;
    }
    
    return false;
  }

  /// Ensure enemies are standing on solid ground, not inside spikes,
  /// and have a minimum patrol range so they can aggro the player.
  static const double _minEnemyPatrolRange = 64.0; // 2 tiles minimum

  static List<EnemyData> _sanitizeEnemies(
      List<EnemyData> enemies, List<TileData> tiles, int w, int h) {
    final grid = _buildGrid(tiles, w, h);
    final sanitized = <EnemyData>[];

    for (final enemy in enemies) {
      final ex = enemy.x.round();
      // Enemy sprite is ~2 tiles tall — check from foot position
      final ey = enemy.y.round() + 1;

      if (ey >= 0 && ey < h + 10 && ex >= 0 && ex < w + 10) {
        // --- Spike overlap check ---
        final enemyTileY = enemy.y.round();
        if (enemyTileY >= 0 && enemyTileY < grid.length && ex < grid[0].length) {
          if (grid[enemyTileY][ex] == 'spike' ||
              (ey < grid.length && ex < grid[0].length && grid[ey][ex] == 'spike')) {
            _log('[LevelValidator] Removed enemy at (${enemy.x}, ${enemy.y}) — spawns inside spike');
            continue;
          }
        }

        // --- Ground check (within 3 tiles below) ---
        bool hasGround = false;
        for (int checkY = ey; checkY < min(ey + 3, h + 10); checkY++) {
          if (checkY >= 0 && checkY < grid.length && ex < grid[0].length &&
              (grid[checkY][ex] == 'block' || grid[checkY][ex] == 'platform')) {
            hasGround = true;
            break;
          }
        }

        if (!hasGround) {
          _log('[LevelValidator] Removed floating enemy at (${enemy.x}, ${enemy.y})');
          continue;
        }

        // --- Enforce minimum patrol range so enemies can always aggro ---
        final safePatrol = max(enemy.patrolRange, _minEnemyPatrolRange);
        if (safePatrol != enemy.patrolRange) {
          _log('[LevelValidator] Expanded patrol range for enemy at (${enemy.x}, ${enemy.y}) from ${enemy.patrolRange} to $safePatrol');
          sanitized.add(EnemyData(
            x: enemy.x, y: enemy.y,
            health: enemy.health, damage: enemy.damage,
            speed: enemy.speed, type: enemy.type,
            patrolRange: safePatrol,
          ));
        } else {
          sanitized.add(enemy);
        }
      } else {
        sanitized.add(enemy); // Out of bounds — keep it, game will handle
      }
    }
    return sanitized;
  }

  /// Ensure pickups aren't inside blocks.
  static List<PickupData> _sanitizePickups(
      List<PickupData> pickups, List<TileData> tiles, int w, int h) {
    final grid = _buildGrid(tiles, w, h);
    final sanitized = <PickupData>[];

    for (final pickup in pickups) {
      final px = pickup.x.round();
      final py = pickup.y.round();

      if (px >= 0 && px < w + 10 && py >= 0 && py < h + 10 &&
          py < grid.length && px < grid[0].length) {
        if (grid[py][px] == 'block' || grid[py][px] == 'platform') {
          // Inside a block — move it up
          int newY = py - 1;
          while (newY >= 0 && newY < grid.length && px < grid[0].length && (grid[newY][px] == 'block' || grid[newY][px] == 'platform')) {
            newY--;
          }
          if (newY >= 0) {
            sanitized.add(PickupData(type: pickup.type, x: pickup.x, y: newY.toDouble()));
            _log('[LevelValidator] Moved pickup from (${pickup.x}, ${pickup.y}) to (${pickup.x}, $newY)');
          }
        } else {
          sanitized.add(pickup);
        }
      } else {
        sanitized.add(pickup);
      }
    }
    return sanitized;
  }

  // ========================================================================
  // PHASE 2: Spawn/Exit Safety
  // ========================================================================

  /// Ensure spawn area is free of hazards and has ground below.
  static List<TileData> _ensureSpawnSafety(
      List<TileData> tiles, ({double x, double y}) spawn, int w, int h) {
    final sx = spawn.x.round();
    final sy = spawn.y.round();
    final result = <TileData>[];

    for (final tile in tiles) {
      if (tile.type == 'lava' || tile.type == 'spike') {
        // Check if this hazard overlaps with spawn safe zone
        final tileEndX = (tile.x + tile.w).round();
        final tileEndY = (tile.y + tile.h).round();
        final tileStartX = tile.x.round();
        final tileStartY = tile.y.round();

        if (tileStartX < sx + spawnSafeRadius &&
            tileEndX > sx - spawnSafeRadius &&
            tileStartY < sy + spawnSafeRadius &&
            tileEndY > sy - spawnSafeRadius) {
          _log('[LevelValidator] Removed ${tile.type} near spawn at (${tile.x}, ${tile.y})');
          continue; // Remove hazard near spawn
        }
      }
      result.add(tile);
    }

    // Ensure there's ground below spawn
    final grid = _buildGrid(result, w, h);
    bool hasSpawnGround = false;
    for (int checkY = sy + 1; checkY < min(sy + 4, h + 10); checkY++) {
      if (checkY >= 0 && checkY < grid.length && sx >= 0 && sx < grid[0].length &&
          (grid[checkY][sx] == 'block' || grid[checkY][sx] == 'platform')) {
        hasSpawnGround = true;
        break;
      }
    }

    if (!hasSpawnGround) {
      // Add a small platform under spawn
      result.add(TileData(type: 'block', x: (sx - 1).toDouble(), y: (sy + 1).toDouble(), w: 4, h: 1));
      _log('[LevelValidator] Added spawn platform at (${sx - 1}, ${sy + 1})');
    }

    return result;
  }

  /// Ensure exit area has ground below.
  static List<TileData> _ensureExitSafety(
      List<TileData> tiles, ({double x, double y}) exit, int w, int h) {
    final ex = exit.x.round();
    final ey = exit.y.round();
    final result = List<TileData>.from(tiles);

    final grid = _buildGrid(result, w, h);
    bool hasExitGround = false;
    for (int checkY = ey + 1; checkY < min(ey + 4, h + 10); checkY++) {
      if (checkY >= 0 && checkY < grid.length && ex >= 0 && ex < grid[0].length &&
          (grid[checkY][ex] == 'block' || grid[checkY][ex] == 'platform')) {
        hasExitGround = true;
        break;
      }
    }

    if (!hasExitGround) {
      result.add(TileData(type: 'block', x: (ex - 1).toDouble(), y: (ey + 1).toDouble(), w: 4, h: 1));
      _log('[LevelValidator] Added exit platform at (${ex - 1}, ${ey + 1})');
    }

    return result;
  }

  // ========================================================================
  // PHASE 3: Reachability BFS
  // ========================================================================

  /// A "surface" is a horizontal run of standable tiles (top of blocks).
  /// Represented as (startX, endX, y) — the player can stand anywhere on it.
  static List<_Surface> _findSurfaces(List<List<String?>> grid, int w, int h) {
    final gridH = grid.length;
    final gridW = grid.isNotEmpty ? grid[0].length : 0;
    final surfaces = <_Surface>[];

    for (int y = 0; y < gridH; y++) {
      int? runStart;
      for (int x = 0; x <= gridW; x++) {
        final isSurface = x < gridW &&
            (grid[y][x] == 'block' || grid[y][x] == 'platform') &&
            (y - 1 >= 0 && grid[y - 1][x] != 'block' && grid[y - 1][x] != 'platform') &&
            (y - 2 >= 0 && grid[y - 2][x] != 'block' && grid[y - 2][x] != 'platform');

        if (isSurface) {
          runStart ??= x;
        } else {
          if (runStart != null) {
            surfaces.add(_Surface(runStart, x - 1, y));
            runStart = null;
          }
        }
      }
    }

    return surfaces;
  }

  /// Find the surface nearest to the given grid coordinate.
  static _Surface? _findNearestSurface(List<_Surface> surfaces, int x, int y) {
    _Surface? best;
    double bestDist = double.infinity;

    for (final s in surfaces) {
      // Clamp x to surface range for distance calculation
      final clampedX = x.clamp(s.startX, s.endX);
      // The player stands ON TOP of the surface, so the walkable Y is s.y - 1
      final dist = sqrt(pow(clampedX - x, 2) + pow(s.y - y, 2).toDouble());
      if (dist < bestDist) {
        bestDist = dist;
        best = s;
      }
    }

    return best;
  }

  /// BFS across surfaces using player movement constraints.
  /// Returns the set of all surfaces reachable from [start].
  static Set<_Surface> _bfsReachability(List<_Surface> surfaces, _Surface start, List<List<String?>> grid) {
    final visited = <_Surface>{start};
    final queue = <_Surface>[start];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);

      for (final other in surfaces) {
        if (visited.contains(other)) continue;
        if (_canReach(current, other, grid)) {
          visited.add(other);
          queue.add(other);
        }
      }
    }

    return visited;
  }

  /// Can the player move from surface A to surface B?
  /// Uses a combined parabolic model: horizontal travel costs airtime,
  /// which reduces available jump height. Also checks for walls blocking the path.
  static bool _canReach(_Surface a, _Surface b, List<List<String?>> grid) {
    // Horizontal distance: gap between the closest edges
    final int horizGap;
    if (b.startX > a.endX) {
      horizGap = b.startX - a.endX - 1;
    } else if (a.startX > b.endX) {
      horizGap = a.startX - b.endX - 1;
    } else {
      horizGap = 0; // Overlapping or adjacent horizontally
    }

    // Vertical difference (positive = B is higher = need to jump up)
    final vertDiff = a.y - b.y; // positive means B is above A

    // --- Combined reachability using parabolic jump model ---
    // Player physics (in tiles, 1 tile = 32px):
    //   moveSpeed = 200px/s = 6.25 tiles/s
    //   jumpForce = 400px/s = 12.5 tiles/s  
    //   gravity = 900px/s² = 28.125 tiles/s²
    //   dodgeSpeed = 450px/s for 0.2s = 2.81 tiles bonus
    //   double jump available
    //
    // For a double jump, max height is reached when the player 
    // uses both jumps optimally. We model the "reachable envelope":
    //   - Time in air with double jump ≈ 1.5s
    //   - At time t, horizontal distance = 6.25*t + 2.81 (with dodge)
    //   - At time t, max height depends on when double jump is used
    //
    // Simplified conservative envelope:
    //   maxHeight(horizGap) = maxJumpHeight - (horizGap * 0.4)
    //   This models the trade-off: bigger gaps = less height available

    if (horizGap > maxHorizontalGap) return false;

    if (vertDiff >= 0) {
      // Going UP — need to jump
      // Combined check: the further the horizontal gap, the less height we can gain
      final effectiveMaxHeight = maxJumpHeight - (horizGap * 0.4);
      if (vertDiff > effectiveMaxHeight) return false;
    }
    // Going DOWN — can fall any distance, just need horizontal reach
    // (already checked horizGap above)

    // --- Wall obstruction check ---
    // Check if there's a solid wall blocking the direct path between surfaces
    if (horizGap > 0 && _isPathBlocked(a, b, grid)) {
      return false;
    }

    return true;
  }

  /// Check if there's a wall blocking the path between two surfaces.
  /// Traces a rough path from A to B and checks for solid columns in between.
  static bool _isPathBlocked(_Surface a, _Surface b, List<List<String?>> grid) {
    final gridH = grid.length;
    final gridW = grid.isNotEmpty ? grid[0].length : 0;

    // Determine the horizontal range to check
    final int leftX, rightX;
    if (a.endX < b.startX) {
      leftX = a.endX + 1;
      rightX = b.startX - 1;
    } else if (b.endX < a.startX) {
      leftX = b.endX + 1;
      rightX = a.startX - 1;
    } else {
      return false; // Overlapping, no gap to block
    }

    // The player's trajectory goes from one surface height to another.
    // Check each column in between for a solid wall that blocks passage.
    final minY = min(a.y, b.y) - maxJumpHeight; // Player can jump this high
    final maxY = max(a.y, b.y);

    for (int x = leftX; x <= rightX && x < gridW; x++) {
      if (x < 0) continue;
      
      // Check if this column is completely blocked (wall from top to bottom of path)
      bool columnBlocked = true;
      for (int y = max(0, minY); y <= min(maxY, gridH - 1); y++) {
        if (grid[y][x] != 'block' && grid[y][x] != 'platform') {
          columnBlocked = false;
          break;
        }
      }
      if (columnBlocked && (maxY - max(0, minY)) >= 2) {
        return true; // Wall blocks the path
      }

      // Check if a passable 2-tile vertical gap exists in this column
      bool hasPassableGap = false;
      for (int y = max(0, minY); y < min(maxY, gridH - 1); y++) {
        if (grid[y][x] != 'block' && grid[y][x] != 'platform' &&
            grid[y + 1][x] != 'block' && grid[y + 1][x] != 'platform') {
          hasPassableGap = true;
          break;
        }
      }
      if (!hasPassableGap) {
        return true; // Path is blocked by ceiling/floor squeezing
      }
    }

    return false;
  }

  /// Try to build bridge platforms to connect unreachable surfaces.
  static List<TileData> _buildBridges(
    List<_Surface> allSurfaces,
    Set<_Surface> reachable,
    _Surface target,
    int mapWidth,
    int mapHeight,
  ) {
    final bridges = <TileData>[];
    final unreachable = allSurfaces.where((s) => !reachable.contains(s)).toList();

    if (unreachable.isEmpty) return bridges;

    // Find the closest unreachable surface to any reachable surface
    _Surface? bestReachable;
    _Surface? bestUnreachable;
    double bestDist = double.infinity;

    for (final r in reachable) {
      for (final u in unreachable) {
        final dx = ((r.endX + r.startX) / 2 - (u.endX + u.startX) / 2).abs();
        final dy = (r.y - u.y).abs();
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < bestDist) {
          bestDist = dist;
          bestReachable = r;
          bestUnreachable = u;
        }
      }
    }

    if (bestReachable == null || bestUnreachable == null) return bridges;

    // Place stepping-stone bridges between them
    final rMidX = (bestReachable.startX + bestReachable.endX) ~/ 2;
    final uMidX = (bestUnreachable.startX + bestUnreachable.endX) ~/ 2;
    final rY = bestReachable.y;
    final uY = bestUnreachable.y;

    // Calculate how many bridges we need
    final totalHorizDist = (uMidX - rMidX).abs();
    final totalVertDist = (rY - uY).abs();
    final numBridges = max(1, max(totalHorizDist ~/ maxHorizontalGap, totalVertDist ~/ maxJumpHeight));

    for (int i = 1; i <= numBridges; i++) {
      final fraction = i / (numBridges + 1);
      final bx = rMidX + ((uMidX - rMidX) * fraction).round();
      final by = rY + ((uY - rY) * fraction).round();

      // Clamp to map bounds
      final clampedX = bx.clamp(0, mapWidth - 3);
      final clampedY = by.clamp(1, mapHeight - 1);

      bridges.add(TileData(
        type: 'block',
        x: clampedX.toDouble(),
        y: clampedY.toDouble(),
        w: 3,
        h: 1,
      ));
      _log('[LevelValidator] Added bridge platform at ($clampedX, $clampedY)');
    }

    return bridges;
  }

  // ========================================================================
  // Utility
  // ========================================================================

  /// Build a 2D grid of tile types for O(1) lookups.
  static List<List<String?>> _buildGrid(List<TileData> tiles, int mapWidth, int mapHeight) {
    final w = mapWidth + 10;
    final h = mapHeight + 10;
    final grid = List.generate(h, (_) => List<String?>.filled(w, null));

    for (final tile in tiles) {
      if (tile.type != 'block' && tile.type != 'platform') continue;
      
      final startX = tile.x.round();
      final startY = tile.y.round();
      final endX = (tile.x + tile.w).round();
      final endY = (tile.y + tile.h).round();

      for (int y = startY; y < endY && y < h; y++) {
        for (int x = startX; x < endX && x < w; x++) {
          if (x >= 0 && y >= 0) {
            grid[y][x] = tile.type;
          }
        }
      }
    }

    return grid;
  }
}

/// Represents a horizontal surface the player can stand on.
/// (startX..endX) at row y — meaning blocks at grid[y][startX..endX]
/// and the player stands at y-1 (on top of the block).
class _Surface {
  final int startX;
  final int endX;
  final int y;

  _Surface(this.startX, this.endX, this.y);

  @override
  bool operator ==(Object other) =>
      other is _Surface && startX == other.startX && endX == other.endX && y == other.y;

  @override
  int get hashCode => Object.hash(startX, endX, y);

  @override
  String toString() => 'Surface($startX..$endX, y=$y)';
}

/// Extension to create modified copies of LevelData.
extension _LevelDataCopy on LevelData {
  LevelData _copyWith({
    List<TileData>? tiles,
    List<EnemyData>? enemies,
    List<PickupData>? pickups,
  }) {
    return LevelData(
      levelId: levelId,
      difficulty: difficulty,
      width: width,
      height: height,
      spawn: spawn,
      exit: exit,
      tiles: tiles ?? this.tiles,
      enemies: enemies ?? this.enemies,
      pickups: pickups ?? this.pickups,
      architectDialogue: architectDialogue,
      narrativeEvents: narrativeEvents,
      enemyDamageMultiplier: enemyDamageMultiplier,
      enemyHealthMultiplier: enemyHealthMultiplier,
    );
  }
}
