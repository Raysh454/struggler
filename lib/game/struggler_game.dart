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
import '../ai/architect_agent.dart';
import 'level/level_data.dart';
import 'components/enemy.dart';

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

  late final ArchitectAgent architectAgent;
  Future<LevelData?>? nextLevelFuture;
  Map<String, dynamic>? lastLevelValidatorFeedback;
  String? currentArchitectDialogue;

  StruggleGame({this.onOverlayChange});

  @override
  Color backgroundColor() => const Color(0xFF1A1A2E); // Dark blue-black

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    playerState = PlayerState();
    gameState = GameState();
    architectAgent = ArchitectAgent();

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

    LevelData levelData;
    if (levelId == -1) {
      levelData = LevelManager.createGuardianRealm();
    } else {
      if (nextLevelFuture != null) {
        // We have a pre-fetched level!
        // TODO: Wait for it if it's still loading
        final fetched = await nextLevelFuture;
        if (fetched != null) {
          levelData = fetched;
        } else {
          levelData = LevelManager.createTestLevel(levelId);
        }
        nextLevelFuture = null; // Consume it
      } else {
        // Fallback or first level load
        levelData = LevelManager.createTestLevel(levelId);
        // We should start fetching immediately if it's the start
        _prefetchNextLevel(levelId + 1);
      }
    }

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

    // Trigger Architect Intro if dialogue exists
    if (levelData.architectDialogue != null && levelData.architectDialogue!.isNotEmpty) {
      currentArchitectDialogue = levelData.architectDialogue;
      showControlsNotifier.value = false;
      pauseEngine();
      overlays.add('ArchitectIntro');
    }
  }

  void checkEnemiesLeft() {
    if (nextLevelFuture != null || gameState.currentLevel == -1) return; // Already fetching or in Guardian Realm
    
    // Using simple iteration to count enemies.
    int enemiesLeft = 0;
    for (final child in world.children) {
      if (child is BaseEnemy && !child.isDead) {
        enemiesLeft++;
      }
    }
    
    if (enemiesLeft == 1) {
      // 1 enemy left! Start prefetching next level.
      _prefetchNextLevel(gameState.currentLevel + 1);
    }
  }

  void _prefetchNextLevel(int nextLevelId) {
    if (nextLevelFuture != null) return;
    print('[StruggleGame] Prefetching level $nextLevelId...');
    
    final telemetry = playerState.toTelemetry();
    telemetry['previousLevelPerformance'] = {
      'levelValidatorFeedback': lastLevelValidatorFeedback ?? {},
    };
    
    nextLevelFuture = architectAgent.generateNextLevel(telemetry).then((json) {
      if (json != null && json.containsKey('levelBlueprint')) {
        try {
          // Parse the AI's JSON into LevelData
          // We need a helper method to convert it, since the AI returns a custom format.
          return _parseLevelDataFromAI(nextLevelId, json);
        } catch (e) {
          print('Error parsing AI level: $e');
        }
      }
      return null;
    });
  }

  LevelData _parseLevelDataFromAI(int levelId, Map<String, dynamic> json) {
    // This parses the JSON structure defined in prompt.md into our LevelData object.
    final blueprint = json['levelBlueprint'] as Map<String, dynamic>;
    final width = blueprint['width'] as int? ?? 50;
    final height = blueprint['height'] as int? ?? 20;
    
    final tilesJson = blueprint['tiles'] as List<dynamic>? ?? [];
    final objectsJson = blueprint['objects'] as List<dynamic>? ?? [];
    
    final List<TileData> parsedTiles = [];
    final List<EnemyData> parsedEnemies = [];
    final List<PickupData> parsedPickups = [];
    
    ({double x, double y}) spawn = (x: 2, y: 17);
    ({double x, double y}) exit = (x: width - 3, y: 17);
    
    for (final tileRaw in tilesJson) {
      final t = tileRaw as Map<String, dynamic>;
      final type = t['type'] as String;
      final x = (t['x'] as num).toDouble();
      final y = (t['y'] as num).toDouble();
      final w = (t['w'] as num?)?.toDouble() ?? 1;
      final h = (t['h'] as num?)?.toDouble() ?? 1;
      
      if (type == 'PLAYER_SPAWN') {
        spawn = (x: x, y: y);
      } else if (type == 'EXIT_PORTAL') {
        exit = (x: x, y: y);
      } else if (type != 'EMPTY') {
        parsedTiles.add(TileData(type: type.toLowerCase(), x: x, y: y, w: w, h: h));
      }
    }
    
    for (final objRaw in objectsJson) {
      final o = objRaw as Map<String, dynamic>;
      final objType = o['type'] as String;
      final x = (o['x'] as num).toDouble();
      final y = (o['y'] as num).toDouble();
      
      if (objType == 'ENEMY') {
        parsedEnemies.add(EnemyData(
          x: x, y: y, type: (o['enemyType'] as String).toLowerCase()
        ));
      } else if (objType == 'PICKUP') {
        parsedPickups.add(PickupData(
          type: (o['pickupType'] as String).toLowerCase(), x: x, y: y
        ));
      }
    }
    
    return LevelData(
      levelId: levelId,
      width: width,
      height: height,
      spawn: spawn,
      exit: exit,
      tiles: parsedTiles,
      enemies: parsedEnemies,
      pickups: parsedPickups,
      architectDialogue: json['architectDialogue'] as String?,
    );
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
    playerState.resetForNewLevel(); // Reset stats and heals for the new level!
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
