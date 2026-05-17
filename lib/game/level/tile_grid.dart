import 'level_data.dart';

/// Neighbor flags for auto-tiling. Each flag indicates whether
/// a solid block exists in that direction relative to the current cell.
class TileNeighbors {
  final bool above;
  final bool below;
  final bool left;
  final bool right;

  const TileNeighbors({
    this.above = false,
    this.below = false,
    this.left = false,
    this.right = false,
  });

  /// True if this is a top-exposed surface (nothing above).
  bool get isTopSurface => !above;

  /// True if this is a left edge (nothing to the left).
  bool get isLeftEdge => !left;

  /// True if this is a right edge (nothing to the right).
  bool get isRightEdge => !right;

  /// True if this is a bottom edge (nothing below).
  bool get isBottomEdge => !below;

  /// True if this is completely surrounded by blocks.
  bool get isInterior => above && below && left && right;
}

/// Preprocesses LevelData tile rectangles into a 2D grid
/// for O(1) neighbor lookups during rendering.
class TileGrid {
  /// The 2D grid storing the type of tile ('block', 'lava', etc).
  final List<List<String?>> _grid;
  final int width;
  final int height;

  TileGrid._(this._grid, this.width, this.height);

  /// Build a TileGrid from a list of tile rectangles.
  factory TileGrid.fromTiles(List<TileData> tiles, int mapWidth, int mapHeight) {
    // Add some padding for blocks that might extend beyond declared bounds
    final w = mapWidth + 10;
    final h = mapHeight + 10;
    final List<List<String?>> grid = List.generate(h, (_) => List<String?>.filled(w, null));

    for (final tile in tiles) {
      if (tile.type != 'block' && tile.type != 'lava' && tile.type != 'platform') continue;

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

    return TileGrid._(grid, w, h);
  }

  /// Check if a cell is a solid block.
  bool isSolid(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return false;
    return _grid[y][x] == 'block' || _grid[y][x] == 'platform';
  }

  /// Check if a cell contains lava.
  bool isLava(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return false;
    return _grid[y][x] == 'lava';
  }

  /// Check if a pillar exists at this cell.
  /// A pillar exists if there is a solid block up to 6 tiles above it.
  bool hasPillar(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return false;
    if (_grid[y][x] == 'block') return false; // platform doesn't block pillars from above, block does
    
    // Check up to 6 tiles above (maxDepth of pillars is 6)
    for (int i = 1; i <= 6; i++) {
      if (y - i < 0) break;
      if (_grid[y - i][x] == 'block') return true; // only 'block' casts pillars
    }
    return false;
  }

  /// Get the neighbor flags for a given grid cell.
  /// Lava and Pillars count as valid horizontal neighbors to prevent blocks
  /// from drawing cliff faces directly next to them.
  TileNeighbors getNeighbors(int x, int y) {
    return TileNeighbors(
      above: isSolid(x, y - 1),
      below: isSolid(x, y + 1),
      left: isSolid(x - 1, y) || isLava(x - 1, y) || hasPillar(x - 1, y),
      right: isSolid(x + 1, y) || isLava(x + 1, y) || hasPillar(x + 1, y),
    );
  }

  /// Count how many consecutive solid cells exist below (x, startY).
  /// Used for pillar height calculation.
  int solidDepthBelow(int x, int startY) {
    int depth = 0;
    for (int y = startY; y < height; y++) {
      if (isSolid(x, y)) {
        depth++;
      } else {
        break;
      }
    }
    return depth;
  }
}
