import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'dart:ui';

import '../models/player_state.dart';
import '../models/game_state.dart';
import 'components/player.dart';
import 'level/level_manager.dart';
import 'hud/game_hud.dart';

/// Main game class. Manages the game world, camera, and state.
class StruggleGame extends FlameGame
    with HasCollisionDetection, HasKeyboardHandlerComponents, TapCallbacks {
  late Player player;
  late PlayerState playerState;
  late GameState gameState;
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

    // Build level components
    final components = LevelManager.buildLevel(levelData);
    for (final component in components) {
      world.add(component);
    }

    // Spawn player
    final spawnPos = LevelManager.getSpawnPosition(levelData);
    player = Player(position: spawnPos);
    world.add(player);

    // Set up camera to follow player
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

  @override
  void update(double dt) {
    super.update(dt);

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

  /// Called when the player reaches the exit portal.
  void onLevelComplete() {
    gameState.completeLevel();
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
