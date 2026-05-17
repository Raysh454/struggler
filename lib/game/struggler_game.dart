import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';

import '../models/player_state.dart';
import '../models/game_state.dart';
import 'components/player.dart';
import 'level/level_manager.dart';
import 'level/level_theme.dart';
import 'level/tile_grid.dart';
import 'hud/game_hud.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/widgets.dart';

/// Main game class. Manages the game world, camera, and state.
class StruggleGame extends FlameGame
    with HasCollisionDetection, HasKeyboardHandlerComponents, TapCallbacks {
  late Player player;
  late PlayerState playerState;
  late GameState gameState;
  TileGrid? activeGrid;
  GameHud? _hud;

  // Screen shake
  double _shakeIntensity = 0;
  double _shakeTimer = 0;
  final Random _random = Random();

  // Callback for Flutter overlay management
  final void Function(String)? onOverlayChange;

  StruggleGame({this.onOverlayChange});

  @override
  Color backgroundColor() => const Color(0xFF1A1A2E); // Dark blue-black

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    playerState = PlayerState();
    gameState = GameState();

    // Set up camera
    camera.viewfinder.anchor = Anchor.center;

    await loadLevel(gameState.currentLevel);
  }

  /// Load a level by ID. Clears existing level and builds new one.
  Future<void> loadLevel(int levelId) async {
    // Clear the world
    world.removeAll(world.children);

    // Get level data (test level for now, AI-generated later)
    final levelData = LevelManager.createTestLevel(levelId);

    // Pick a random theme for the level
    final themeType = _random.nextBool() ? ThemeType.lightRocks : ThemeType.darkRocks;
    final theme = await LevelTheme.load(this, themeType);

    // Build level components
    final components = await LevelManager.buildLevel(this, levelData, theme);
    for (final component in components) {
      world.add(component);
    }

    // Add Parallax Background to camera backdrop (stays static on screen)
    camera.backdrop.children.whereType<ParallaxComponent>().forEach((c) => c.removeFromParent());
    world.children.whereType<ParallaxComponent>().forEach((c) => c.removeFromParent());
    
    // We assume background1..3 exist in the folder for RockyLevel
    final bgComponent = await loadParallaxComponent(
      theme.backgroundAssets,
      baseVelocity: Vector2(0, 0),
      velocityMultiplierDelta: Vector2(1.5, 1.0),
      repeat: ImageRepeat.repeatX,
      fill: LayerFill.height, // Scale height to fit screen so it doesn't cut off on portrait devices
      alignment: Alignment.bottomCenter, // Anchor mountains to the bottom of the screen
    );
    bgComponent.size = canvasSize; 
    camera.backdrop.add(bgComponent);
    
    // Store reference to update its parallax offset based on camera position later
    _bgComponent = bgComponent;

    // Spawn player
    final spawnPos = LevelManager.getSpawnPosition(levelData);
    player = Player(position: spawnPos);
    world.add(player);

    // Set up camera to follow player instantly at spawn
    camera.viewfinder.position = spawnPos;
    camera.follow(player, maxSpeed: 300, horizontalOnly: false);
    camera.viewfinder.zoom = 2.0; // Zoom in for better visibility

    // HUD (screen-space, added to camera viewport)
    _hud?.removeFromParent();
    _hud = GameHud(
      playerState: playerState,
      currentLevel: levelId,
    );
    camera.viewport.add(_hud!);

    // Start level timer
    gameState.startLevel();
  }

  ParallaxComponent? _bgComponent;
  
  @override
  void update(double dt) {
    super.update(dt);

    // Keep parallax updated with camera position
    if (_bgComponent != null) {
      // Set the base velocity to match camera movement for the parallax effect.
      // Scale down the velocity so the background moves much slower than the foreground
      _bgComponent!.parallax!.baseVelocity = Vector2(player.velocity.x * 0.1, 0);
    }

    // Screen shake
    if (_shakeTimer > 0) {
      _shakeTimer -= dt;
      final offsetX = (_random.nextDouble() - 0.5) * _shakeIntensity * 2;
      final offsetY = (_random.nextDouble() - 0.5) * _shakeIntensity * 2;
      camera.viewfinder.position = player.position + Vector2(offsetX, offsetY);
    }

    // Drain resolve during Indomitable state
    if (playerState.isIndomitable) {
      playerState.resolve -= 30 * dt; // Drains over ~3.3 seconds
      if (playerState.resolve <= 0) {
        player.deactivateIndomitable();
      }
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    player.attackPressed = true;
  }

  void onLevelComplete() {
    gameState.completeLevel();
    if (gameState.currentLevel > 4) {
      gameState.currentLevel = 1; // Loop back to level 1 for test levels
    }
    // TODO: Show level complete overlay, load next level
    loadLevel(gameState.currentLevel);
  }

  /// Called when the player dies.
  void onPlayerDeath() {
    playerState.resetForRetry();
    // Reload current level
    loadLevel(gameState.currentLevel);
  }

  /// Trigger screen shake effect.
  void onScreenShake(double intensity) {
    _shakeIntensity = intensity;
    _shakeTimer = 0.15;
  }
}
