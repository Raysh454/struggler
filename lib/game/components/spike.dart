import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'dart:ui';
import '../level/level_theme.dart';
import '../config.dart';

/// Spike hazard. Damages the player on contact. Can be on floors or walls.
class Spike extends PositionComponent with CollisionCallbacks {
  final double damage;
  final LevelTheme theme;

  Spike({
    required Vector2 position,
    required Vector2 size,
    required this.theme,
    this.damage = GameConfig.spikeDamageDefault,
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    // We assume most spikes are on the floor unless they have a specific flag.
    // For now, we'll use the Y position to guess, or just default to floor spikes.
    final sprite = theme.floorSpikeSprite;
    
    // Tile the spike sprite across the width
    const double spikeTileSize = GameConfig.tileSize;
    for (double x = 0; x < size.x; x += spikeTileSize) {
      sprite.render(
        canvas,
        position: Vector2(x, 0),
        size: Vector2(spikeTileSize, size.y),
      );
    }
  }
}
