import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';

import '../models/player_state.dart';
import '../models/game_state.dart';
import 'config.dart';
import 'components/player.dart';
import 'components/cat.dart';
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

  // Portal transition variables
  int? _previousLevelId;
  Vector2? _previousPlayerPosition;
  
  // Controls visibility notifier
  final ValueNotifier<bool> showControlsNotifier = ValueNotifier(false);

  // Track killed/collected entities to prevent farming/respawning on portal return
  final Set<String> removedEntitiesKeys = {};
  
  // Track permanently collected diamonds across retries
  final Set<String> collectedDiamondsKeys = {};

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

    // Pause game on start to display Main Menu
    overlays.add('MainMenu');
    pauseEngine();
  }

  /// Load a level by ID. Clears existing level and builds new one.
  Future<void> loadLevel(int levelId) async {
    // Clear the world
    world.removeAll(world.children);

    // Get level data (test level for now, AI-generated later)
    final levelData = levelId == -1
        ? LevelManager.createGuardianRealm()
        : LevelManager.createTestLevel(levelId);

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

    // Spawn companion cat "Hope" right next to player
    final cat = CompanionCat(position: spawnPos - Vector2(16, 0));
    world.add(cat);

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
      playerState.resolve -= GameConfig.playerResolveDrainRate * dt;
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
    removedEntitiesKeys.clear();
    gameState.completeLevel();
    if (gameState.currentLevel > 4) {
      gameState.currentLevel = 1; // Loop back to level 1 for test levels
    }
    // TODO: Show level complete overlay, load next level
    loadLevel(gameState.currentLevel);
  }

  /// Called when the player dies.
  void onPlayerDeath() {
    removedEntitiesKeys.clear();
    
    // Save death location for LostWill spawning before currencies are reset
    playerState.lostWillX = player.lastSafePosition?.x ?? player.position.x;
    playerState.lostWillY = player.lastSafePosition?.y ?? player.position.y;
    playerState.lostWillLevelId = gameState.currentLevel;

    playerState.resetForRetry();
    // Reload current level
    loadLevel(gameState.currentLevel);
  }

  /// Trigger screen shake effect.
  void onScreenShake(double intensity) {
    _shakeIntensity = intensity;
    _shakeTimer = 0.15;
  }

  /// Transition the player between the active level and the Guardian's Realm.
  void transitionThroughPortal({required bool isReturn}) {
    if (isReturn) {
      // Returning to main level from Guardian Realm
      final targetLevel = _previousLevelId ?? 1;
      final targetPos = _previousPlayerPosition;
      
      gameState.currentLevel = targetLevel;
      loadLevel(targetLevel).then((_) {
        if (targetPos != null) {
          player.position.setFrom(targetPos);
          // Let the cat snap behind the player instantly
          world.children.whereType<CompanionCat>().forEach((c) {
            c.position.setFrom(targetPos - Vector2(player.facingDirection * 24.0, 0));
          });
        }
      });
    } else {
      // Entering Guardian Realm: save main level ID and player entry coordinates
      _previousLevelId = gameState.currentLevel;
      _previousPlayerPosition = player.position.clone();
      
      gameState.currentLevel = -1;
      loadLevel(-1);
    }
  }

  /// Open the Guardian Upgrades overlay.
  void openGuardianUpgrades() {
    showControlsNotifier.value = false;
    pauseEngine();
    overlays.add('GuardianUpgrades');
  }

  /// Close the Guardian Upgrades overlay and resume the game loop.
  void closeGuardianUpgrades() {
    showControlsNotifier.value = true;
    resumeEngine();
    overlays.remove('GuardianUpgrades');
  }

  /// Returns true if there are no solid platform blocks between [start] and [end].
  bool hasLineOfSight(Vector2 start, Vector2 end) {
    final grid = activeGrid;
    if (grid == null) return true;

    final dist = start.distanceTo(end);
    if (dist < 4) return true; // Extremely close contact

    final dir = (end - start).normalized();
    const step = 8.0; // Sample every 8px (quarter of a tile)
    
    // Scan step-by-step from start to end
    for (double d = step; d < dist - step; d += step) {
      final point = start + dir * d;
      final tx = (point.x / GameConfig.tileSize).floor();
      final ty = (point.y / GameConfig.tileSize).floor();
      if (grid.isSolid(tx, ty)) {
        return false; // Obstacle found
      }
    }
    return true;
  }
}
