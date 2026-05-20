import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'dart:ui';
import 'dart:math';

import '../config.dart';
import '../level/level_theme.dart';
import '../level/tile_grid.dart';
import 'decoration.dart';

/// Solid platform block. Uses TileGrid for clean neighbor-based auto-tiling.
class PlatformBlock extends PositionComponent with CollisionCallbacks {
  final LevelTheme theme;
  final TileGrid grid;
  final bool isJumpThrough;
  Picture? _cachedPicture;

  /// Small overlap to eliminate sub-pixel seams between tiles.
  static const double _overlap = GameConfig.blockOverlap;

  PlatformBlock({
    required Vector2 position,
    required Vector2 size,
    required this.theme,
    required this.grid,
    this.isJumpThrough = false,
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    await add(RectangleHitbox());
    _buildCachedPicture();
    _spawnDecorations();
  }

  void _buildCachedPicture() {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final random = Random(position.hashCode); // Deterministic per-block
    const double ts = GameConfig.tileSize;

    for (double y = 0; y < size.y; y += ts) {
      for (double x = 0; x < size.x; x += ts) {
        // Grid coordinates for this cell
        final gx = ((position.x + x) / ts).round();
        final gy = ((position.y + y) / ts).round();
        final n = grid.getNeighbors(gx, gy);

        final sprite = _pickSprite(n, random);

        // Render slightly larger than the cell to overlap neighboring tiles
        sprite.render(
          canvas,
          position: Vector2(x - _overlap, y - _overlap),
          size: Vector2(ts + _overlap * 2, ts + _overlap * 2),
        );
      }
    }
    _cachedPicture = recorder.endRecording();
  }

  Sprite _pickSprite(TileNeighbors n, Random random) {
    // Top surface row
    if (n.isTopSurface) {
      if (n.isLeftEdge && n.isRightEdge) {
        return _randomFrom(theme.blockSprites, random);
      }
      if (n.isLeftEdge && theme.leftEdgeSprites.isNotEmpty) {
        return _randomFrom(theme.leftEdgeSprites, random);
      }
      if (n.isRightEdge && theme.rightEdgeSprites.isNotEmpty) {
        return _randomFrom(theme.rightEdgeSprites, random);
      }
      return _randomFrom(theme.blockSprites, random);
    }

    // Interior / wall rows
    if (n.isLeftEdge && theme.leftWallSprites.isNotEmpty) {
      return _randomFrom(theme.leftWallSprites, random);
    }
    if (n.isRightEdge && theme.rightWallSprites.isNotEmpty) {
      return _randomFrom(theme.rightWallSprites, random);
    }

    // Fully interior
    final allWall = [...theme.leftWallSprites, ...theme.rightWallSprites];
    return allWall.isNotEmpty
        ? _randomFrom(allWall, random)
        : _randomFrom(theme.blockSprites, random);
  }

  Sprite _randomFrom(List<Sprite> sprites, Random random) {
    return sprites[random.nextInt(sprites.length)];
  }

  void _spawnDecorations() {
    final random = Random(position.hashCode + 1);
    const double ts = GameConfig.tileSize;

    for (double x = 0; x < size.x; x += ts) {
      final gx = ((position.x + x) / ts).round();
      final gy = (position.y / ts).round();

      // Only decorate top-exposed cells with nothing above (no blocks, no lava)
      if (grid.isSolid(gx, gy - 1) || grid.isLava(gx, gy - 1)) continue;

      // Grass
      if (theme.grassSprites.isNotEmpty && random.nextDouble() > (1.0 - GameConfig.grassSpawnChance)) {
        final sprite = _randomFrom(theme.grassSprites, random);
        final patchSize = GameConfig.grassPatchSize;
        final xOffset = random.nextDouble() * (GameConfig.grassMaxXOffset * 2) - GameConfig.grassMaxXOffset;
        add(DecorationComponent(
          sprite: sprite,
          position: Vector2(x + xOffset, -patchSize.y + GameConfig.grassYOffset),
          size: patchSize,
        ));
      }

      // Rocks (occasional)
      if (theme.rockSprites.isNotEmpty && random.nextDouble() > (1.0 - GameConfig.rockSpawnChance)) {
        final sprite = _randomFrom(theme.rockSprites, random);
        final scale = GameConfig.rockScaleHeightReference / sprite.srcSize.y;
        final rockSize = sprite.srcSize * scale;
        add(DecorationComponent(
          sprite: sprite,
          position: Vector2(x + GameConfig.rockXOffset, -rockSize.y + (rockSize.y * GameConfig.rockYOffsetRatio)),
          size: rockSize,
        ));
      }

      // Trees (rare)
      if (theme.treeSprites.isNotEmpty && random.nextDouble() > (1.0 - GameConfig.treeSpawnChance)) {
        final sprite = _randomFrom(theme.treeSprites, random);
        final treeSize = sprite.srcSize.clone()..scale(GameConfig.treeScaleRatio);
        add(
          DecorationComponent(
            sprite: sprite,
            position: Vector2(x + GameConfig.treeXOffset, -treeSize.y + GameConfig.treeYOffset),
            size: treeSize,
          )..priority = GameConfig.treePriority,
        );
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (_cachedPicture != null) {
      canvas.drawPicture(_cachedPicture!);
    }
  }
}

/// Renders the underground fill beneath platforms.
/// Capped at a maximum depth and uses bottom sprites to finish cleanly.
class PillarComponent extends PositionComponent {
  final LevelTheme theme;
  final TileGrid grid;
  final bool isJumpThrough;
  Picture? _cachedPicture;

  /// Small overlap to eliminate sub-pixel seams between tiles.
  static const double _overlap = GameConfig.blockOverlap;

  PillarComponent({
    required this.theme,
    required this.grid,
    required Vector2 position,
    required Vector2 size,
    this.isJumpThrough = false,
  }) : super(position: position, size: size) {
    priority = -10;
  }

  @override
  Future<void> onLoad() async {
    _buildCachedPicture();
  }

  @override
  void render(Canvas canvas) {
    if (_cachedPicture != null) {
      canvas.drawPicture(_cachedPicture!);
    }
  }

  void _buildCachedPicture() {
    if (theme.pillarSprites.isEmpty) return;

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    const double ts = GameConfig.tileSize;

    final int columnCount = (size.x / ts).ceil();
    final int startGy = (position.y / ts).round();
    
    int trueStartX = (position.x / ts).round();
    while (trueStartX > 0 && grid.isSolid(trueStartX - 1, startGy - 1)) {
      trueStartX--;
    }
    final random = Random(trueStartX ^ startGy);
    final int targetDepth = random.nextInt(3) + 4; 

    final darkenPaint = Paint()
      ..colorFilter = const ColorFilter.mode(
        Color(0x50000000), // 40% black shadow
        BlendMode.srcATop,
      );

    for (int col = 0; col < columnCount; col++) {
      final x = col * ts;
      final gx = ((position.x + x) / ts).round();

      // Find depth: stop at ground or max depth
      bool hitGround = false;
      int depth = 0;
      for (int gy = startGy; gy < grid.height && depth < targetDepth; gy++) {
        if (grid.isSolid(gx, gy)) {
          hitGround = true;
          break;
        }
        depth++;
      }
      if (depth <= 0) continue;

      for (int row = 0; row < depth; row++) {
        final dy = row * ts;
        final currentGy = startGy + row;
        final isLastRow = (row == depth - 1) && !hitGround;

        // Edge detection per row to seamlessly merge with lower platforms
        final isLeftEdge = !grid.isSolid(gx - 1, currentGy) && 
            !grid.isLava(gx - 1, currentGy) && 
            !grid.hasPillar(gx - 1, currentGy);
            
        final isRightEdge = !grid.isSolid(gx + 1, currentGy) && 
            !grid.isLava(gx + 1, currentGy) && 
            !grid.hasPillar(gx + 1, currentGy);

        Sprite sprite;
        if (isLastRow) {
          // Bottom row: cap with bottom sprites
          if (isLeftEdge && theme.bottomLeftSprites.isNotEmpty) {
            sprite = _randomFrom(theme.bottomLeftSprites, random);
          } else if (isRightEdge && theme.bottomRightSprites.isNotEmpty) {
            sprite = _randomFrom(theme.bottomRightSprites, random);
          } else if (theme.bottomSprites.isNotEmpty) {
            sprite = _randomFrom(theme.bottomSprites, random);
          } else {
            sprite = _randomFrom(theme.pillarSprites, random);
          }
        } else {
          // Interior rows: use wall sprites for edges
          if (isLeftEdge && theme.leftWallSprites.isNotEmpty) {
            sprite = _randomFrom(theme.leftWallSprites, random);
          } else if (isRightEdge && theme.rightWallSprites.isNotEmpty) {
            sprite = _randomFrom(theme.rightWallSprites, random);
          } else {
            sprite = _randomFrom(theme.pillarSprites, random);
          }
        }

        sprite.render(
          canvas,
          position: Vector2(x - _overlap, dy - _overlap),
          size: Vector2(ts + _overlap * 2, ts + _overlap * 2),
          overridePaint: darkenPaint,
        );
      }
    }
    _cachedPicture = recorder.endRecording();
  }

  Sprite _randomFrom(List<Sprite> sprites, Random random) {
    return sprites[random.nextInt(sprites.length)];
  }

}
