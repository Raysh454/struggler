import "components/architect_cutscene.dart";
import 'dart:math';
import 'systems/audio_manager.dart';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/player_state.dart';
import '../models/game_state.dart';
import 'config.dart';
import 'components/player.dart';
import 'components/cat.dart';
import 'components/block.dart';
import 'components/lava.dart';
import 'components/spike.dart';
import 'level/level_manager.dart';
import 'level/level_theme.dart';
import 'level/tile_grid.dart';
import 'hud/game_hud.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/widgets.dart';
import '../ai/architect_agent.dart';
import 'level/level_data.dart';
import 'level/level_validator.dart';
import 'components/enemy.dart';
import 'components/exit_portal.dart';
import 'components/projectile.dart';

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
  int? _previousAliveEnemiesCount;

  // Controls visibility notifier
  final ValueNotifier<bool> showControlsNotifier = ValueNotifier(false);

  // Track killed/collected entities to prevent farming/respawning on portal return
  final Set<String> removedEntitiesKeys = {};

  // Track permanently collected diamonds across retries
  final Set<String> collectedDiamondsKeys = {};

  // Callback for Flutter overlay management
  final void Function(String)? onOverlayChange;

  late final ArchitectAgent architectAgent;

  // --- Two-phase AI generation state ---
  /// Phase 1: Map layout for the next level (prefetched at level start with N-1 telemetry)
  Future<LevelData?>? nextMapLayoutFuture;
  int _targetPrefetchLevelId = -1;

  /// Phase 2: Difficulty tuning for the next level (triggered mid-level with live N telemetry)
  Future<Map<String, dynamic>?>? nextDifficultyFuture;
  Map<String, dynamic>? nextDifficultyParams;

  /// Prevents re-triggering difficulty generation
  bool _difficultyTriggered = false;

  /// Generation counter — incremented each time a new difficulty request fires.
  /// Stale callbacks check this to avoid applying outdated multipliers.
  int _difficultyGenId = 0;

  /// Prevents onLevelComplete from being called multiple times
  bool _isTransitioning = false;
  bool get isTransitioning => _isTransitioning;

  LevelData? cachedActiveLevel;
  Map<String, dynamic>? lastLevelValidatorFeedback;
  String? currentArchitectDialogue;
  bool isCutscenePlaying = false;
  bool lowHealthTauntTriggered = false;
  LevelTheme? currentTheme;
  int cachedAliveEnemiesCount = 0;

  /// Tracks the last hardcoded fallback level ID used (1-9), for incremental cycling.
  int _lastFallbackLevelId = 0;

  /// Returns the next fallback hardcoded level ID, cycling 1→9 incrementally.
  int _getNextFallbackLevelId() {
    _lastFallbackLevelId++;
    if (_lastFallbackLevelId > 9) {
      _lastFallbackLevelId = 1;
    }
    return _lastFallbackLevelId;
  }

  /// Resets the fallback level tracker (e.g. on full game reset).
  void resetFallbackTracker() {
    _lastFallbackLevelId = 0;
  }

  StruggleGame({this.onOverlayChange});

  @override
  Color backgroundColor() => const Color(0xFF1A1A2E); // Dark blue-black

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    playerState = PlayerState();
    gameState = GameState();
    architectAgent = ArchitectAgent();

    // Preload all audio assets
    await AudioManager.preloadAll();

    // Set up camera
    camera.viewfinder.anchor = Anchor.center;

    await loadLevel(gameState.currentLevel);

    // Pause game on start to display Main Menu
    overlays.add('MainMenu');
    AudioManager.playMenuMusic();
    pauseEngine();
  }

  /// Load a level by ID. Clears existing level and builds new one.
  Future<void> loadLevel(
    int levelId, {
    LevelData? preFetchedLevel,
    bool isDeathRetry = false,
    bool isReturnFromPortal = false,
  }) async {
    // Clear the world
    world.removeAll(world.children);

    if (levelId != -1) {
      playerState.currentLevel = levelId;
    }

    LevelData levelData;
    if (levelId == 10 || levelId == 0) {
      levelData = LevelManager.createHardcodedLevel(levelId);
    } else if (preFetchedLevel != null) {
      levelData = preFetchedLevel;
    } else if (levelId == -1) {
      levelData = LevelManager.createGuardianRealm();
    } else {
      if (nextMapLayoutFuture != null) {
        // We have a pre-fetched map layout!
        final fetched = await nextMapLayoutFuture;
        if (fetched != null) {
          levelData = fetched;
        } else {
          final fallbackId = _getNextFallbackLevelId();
          print(
            '[StruggleGame] API fetch failed in loadLevel. Falling back to hardcoded level $fallbackId.',
          );
          levelData = LevelManager.createHardcodedLevel(fallbackId);
        }
        nextMapLayoutFuture = null; // Consume it
      } else {
        print('[StruggleGame] Dynamically generating AI Level $levelId...');
        final telemetry = _buildMapTelemetry(levelId);
        final fetched = await _generateSolvableMapWithRetries(
          levelId,
          telemetry,
        );
        if (fetched != null) {
          levelData = fetched;
        } else {
          final fallbackId = _getNextFallbackLevelId();
          print(
            '[StruggleGame] AI generation failed in loadLevel. Falling back to hardcoded level $fallbackId.',
          );
          levelData = LevelManager.createHardcodedLevel(fallbackId);
        }
      }
    }

    // Cache the active level so we can restart it or return to it
    if (levelId != -1) {
      cachedActiveLevel = levelData;
      // Reset difficulty trigger for the new level
      _difficultyTriggered = false;
      nextDifficultyFuture = null;
      nextDifficultyParams = null;

      // Phase 1: Prefetch map layout for the NEXT level using N-1 telemetry
      _prefetchNextMapLayout(levelId + 1);

      // Track total enemies in level for live telemetry
      playerState.totalEnemiesInLevel = levelData.enemies.length;
      // NOTE: cachedAliveEnemiesCount is set inside LevelManager.buildLevel()
      // after validation and removedEntitiesKeys filtering, ensuring accuracy.
    }

    // Pick a random theme for the level
    final themeType = _random.nextBool()
        ? ThemeType.lightRocks
        : ThemeType.darkRocks;
    final theme = await LevelTheme.load(this, themeType);
    currentTheme = theme;

    // Build level components
    final components = await LevelManager.buildLevel(this, levelData, theme);
    await world.addAll(components);

    // Add Parallax Background to camera backdrop (stays static on screen)
    camera.backdrop.children.whereType<ParallaxComponent>().forEach(
      (c) => c.removeFromParent(),
    );
    world.children.whereType<ParallaxComponent>().forEach(
      (c) => c.removeFromParent(),
    );

    // We assume background1..3 exist in the folder for RockyLevel
    final bgComponent = await loadParallaxComponent(
      theme.backgroundAssets,
      baseVelocity: Vector2(0, 0),
      velocityMultiplierDelta: Vector2(1.5, 1.0),
      repeat: ImageRepeat.repeatX,
      fill: LayerFill
          .height, // Scale height to fit screen so it doesn't cut off on portrait devices
      alignment: Alignment
          .bottomCenter, // Anchor mountains to the bottom of the screen
    );
    bgComponent.size = canvasSize;
    camera.backdrop.add(bgComponent);

    // Store reference to update its parallax offset based on camera position later
    _bgComponent = bgComponent;


    // Create joystick component
    final joystick = JoystickComponent(
      knob: CircleComponent(
        radius: 30, 
        paint: Paint()..color = Colors.white.withOpacity(0.4), // Semi-transparent white knob
      ),
      background: CircleComponent(
        radius: 60, 
        paint: Paint()..color = Colors.grey.withOpacity(0.1), // Fainter grey background
      ),
      position: Vector2(80, size.y - 80),
      anchor: Anchor.center
    );

    // Spawn player
    final spawnPos = (isReturnFromPortal && _previousPlayerPosition != null)
        ? _previousPlayerPosition!
        : LevelManager.getSpawnPosition(levelData);
    player = Player(position: spawnPos, joystick: joystick);
    await world.add(player);

    // Spawn companion cat "Hope" right next to player
    final catPosition = (isReturnFromPortal && _previousPlayerPosition != null)
        ? _previousPlayerPosition! -
              Vector2(player.facingDirection * GameConfig.catFollowOffset, 0)
        : spawnPos - Vector2(16, 0);
    final cat = CompanionCat(position: catPosition);
    await world.add(cat);

    // Set up camera to follow player instantly at spawn
    camera.viewfinder.position = spawnPos;
    camera.follow(player, maxSpeed: 300, horizontalOnly: false);
    camera.viewfinder.zoom = GameConfig.cameraZoom;

    // HUD (screen-space, added to camera viewport)
    _hud?.removeFromParent();
    _hud = GameHud(playerState: playerState, currentLevel: levelId);
    camera.viewport.add(_hud!);
    camera.viewport.add(joystick);

    // Start level timer
    gameState.startLevel();

    // Switch BGM based on level
    AudioManager.playMusicForLevel(levelId);

    // Reset flags
    lowHealthTauntTriggered = false;

    print('');
    print('┌───────────────────────────────────────────────────────────');
    print('│  🎮  LEVEL $levelId LOADED');
    print('│  💬 Dialogue: "${levelData.architectDialogue ?? 'None'}"');
    print('│  📜 Narrative Events: ${levelData.narrativeEvents.length}');
    print('└───────────────────────────────────────────────────────────');
    print('');

    // Determine the active dialogue, using an immersive default fallback if none was generated yet (e.g. at the start of Level 1)
    String? dialog = levelData.architectDialogue;
    if ((dialog == null || dialog.isEmpty) && levelId != -1) {
      if (levelId == 1) {
        dialog = "So... you've decided to struggle. Let the trial begin!";
      } else if (levelId == 10) {
        dialog = "You've come far... but this ends now.";
      } else {
        dialog = "Another chamber. More futile effort. How entertaining.";
      }
    }

    // Trigger Architect Intro Cutscene if dialogue exists (only in normal levels, NOT on death retry, and NOT when returning from portal)
    if (!isDeathRetry &&
        !isReturnFromPortal &&
        levelId != -1 &&
        dialog != null &&
        dialog.isNotEmpty) {
      currentArchitectDialogue = dialog;
      isCutscenePlaying = true;
      final cutscene = ArchitectCutsceneEntity(
        position: player.position + Vector2(100, -50),
        dialogue: dialog,
      );
      world.add(cutscene);
    } else {
      // Trigger dynamic level start taunt immediately since there is no intro cutscene (skip if death retry or returning from portal)
      if (!isDeathRetry && !isReturnFromPortal) {
        triggerDynamicTaunt('LEVEL_START');
      }
    }
  }

  // ==========================================================================
  // Phase 1: Map Layout Prefetch (uses N-1 telemetry)
  // ==========================================================================

  /// Build the telemetry payload for map layout generation.
  /// Includes game progress and previous-level performance (N-1 data).
  Map<String, dynamic> _buildMapTelemetry(int targetLevelId) {
    final telemetry = playerState.toTelemetry();
    telemetry['requestType'] = 'MAP_LAYOUT';
    telemetry['targetLevel'] = targetLevelId;
    telemetry['gameProgress'] = {
      'currentLevel': gameState.currentLevel,
      'totalDeaths': playerState.deathCount,
      'gamePhase': gameState.narrativeArc,
      'diamondsCollected': playerState.diamondsCollected,
    };
    telemetry['previousLevelPerformance'] = {
      'levelValidatorFeedback': lastLevelValidatorFeedback ?? {},
    };
    telemetry['globalConfig'] = {
      'tileSize': GameConfig.tileSize,
      'maxJumpHeightTiles': GameConfig.validatorMaxJumpHeight,
      'maxHorizontalGapTiles': GameConfig.validatorMaxHorizontalGap,
      'spawnSafeRadiusTiles': GameConfig.validatorSpawnSafeRadius,
      'exitSafeRadiusTiles': GameConfig.validatorExitSafeRadius,
    };
    return telemetry;
  }

  void _prefetchNextMapLayout(int nextLevelId) {
    if (nextLevelId == 10) {
      print('│  ⚔️  Level $nextLevelId is the hardcoded boss fight. Skipping AI prefetch.');
      nextMapLayoutFuture = null;
      return;
    }
    if (nextMapLayoutFuture != null) return;
    print('\n🔄 Prefetching map layout for Level $nextLevelId in background...');

    final telemetry = _buildMapTelemetry(nextLevelId);
    _targetPrefetchLevelId = nextLevelId;
    nextMapLayoutFuture = _generateSolvableMapWithRetries(
      nextLevelId,
      telemetry,
    );
  }

  Future<LevelData?> _generateSolvableMapWithRetries(
    int levelId,
    Map<String, dynamic> telemetry,
  ) async {
    const maxRetries = 3;
    final List<Map<String, dynamic>> failedAttemptsFeedback = [];

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      if (_targetPrefetchLevelId != levelId) {
        print('│  ⚠️  Aborting orphaned generation for Level $levelId (target now $_targetPrefetchLevelId)');
        return null;
      }
      print('\n🔁 Map Generation Attempt $attempt/$maxRetries for Level $levelId...');
      try {
        final currentTelemetry = Map<String, dynamic>.from(telemetry);
        if (failedAttemptsFeedback.isNotEmpty) {
          currentTelemetry['failedAttempts'] = failedAttemptsFeedback;
        }

        final json = await architectAgent.generateMapLayout(currentTelemetry);
        if (json == null) {
          print('│  ⚠️  Attempt $attempt: Agent returned null response.');
          failedAttemptsFeedback.add({
            'attempt': attempt,
            'status': 'Failed: Agent returned empty/null response.',
          });
          continue;
        }
        if (!json.containsKey('levelBlueprint')) {
          print('│  ⚠️  Attempt $attempt: Response missing levelBlueprint.');
          failedAttemptsFeedback.add({
            'attempt': attempt,
            'status': 'Failed: Response missing levelBlueprint.',
          });
          continue;
        }

        final levelData = _parseLevelDataFromAI(levelId, json);

        if (_targetPrefetchLevelId != levelId) {
          print('│  ⚠️  Aborting orphaned generation for Level $levelId (target now $_targetPrefetchLevelId)');
          return null;
        }

        final List<String> feedbackLogs = [];
        final validated = LevelValidator.validate(
          levelData,
          feedbackLogs: feedbackLogs,
        );

        if (LevelValidator.isSolvable(validated)) {
          print('│  ✅  Level $levelId is SOLVABLE after $attempt attempt(s).');

          lastLevelValidatorFeedback = {
            'levelId': levelId,
            'solvable': true,
            'repairLogs': feedbackLogs,
          };

          return validated;
        } else {
          print('│  ❌  Attempt $attempt: Level is unsolvable/unrepairable.');
          failedAttemptsFeedback.add({
            'attempt': attempt,
            'status': 'Failed: Unsolvable level.',
            'validatorLogs': feedbackLogs,
          });
        }
      } catch (e) {
        print('│  ❌  Attempt $attempt exception: $e');
        failedAttemptsFeedback.add({
          'attempt': attempt,
          'status': 'Failed with error: $e',
        });
      }
    }
    print('│  ⚠️  WARNING: All $maxRetries attempts failed for Level $levelId. Using hardcoded fallback.');
    return null;
  }

  // ==========================================================================
  // Phase 2: Difficulty Tuning (uses live N telemetry, triggered mid-level)
  // ==========================================================================

  void _triggerDifficultyGeneration(int nextLevelId) {
    if (nextLevelId == 10) {
      nextDifficultyFuture = null;
      return;
    }
    if (_difficultyTriggered) return;
    _difficultyTriggered = true;

    final aliveEnemies = world.children
        .whereType<BaseEnemy>()
        .where((e) => !e.isDead)
        .length;
    print('\n⚡ Triggering live difficulty tuning for Level $nextLevelId ($aliveEnemies enemies remaining)...');

    final telemetry = <String, dynamic>{
      'requestType': 'DIFFICULTY_TUNING',
      'targetLevel': nextLevelId,
      'gameProgress': {
        'currentLevel': gameState.currentLevel,
        'totalDeaths': playerState.deathCount,
        'gamePhase': gameState.narrativeArc,
        'diamondsCollected': playerState.diamondsCollected,
      },
      'currentLevelPerformance': playerState.toLiveTelemetry(),
    };

    // Bump generation counter so any in-flight callback from a previous request is ignored
    _difficultyGenId++;
    final currentGenId = _difficultyGenId;

    final future = architectAgent.generateDifficulty(telemetry);
    nextDifficultyFuture = future;
    nextDifficultyParams = null; // Reset for new generation

    // Dynamically apply to the CURRENT level as well when resolved!
    future
        .then((difficultyParams) {
          // Discard stale result if a newer request has been fired
          if (_difficultyGenId != currentGenId) {
            print('│  ⏩  Discarding stale difficulty response (gen $currentGenId, current $_difficultyGenId)');
            return;
          }
          nextDifficultyParams = difficultyParams;
          if (difficultyParams != null && gameState.currentLevel != -1) {
            final damageMult =
                (difficultyParams['enemyDamageMultiplier'] as num?)
                    ?.toDouble() ??
                1.0;
            final healthMult =
                (difficultyParams['enemyHealthMultiplier'] as num?)
                    ?.toDouble() ??
                1.0;

            print('\n🔥 Dynamically adjusting CURRENT Level ${gameState.currentLevel} difficulty on-the-fly! (dmg×$damageMult, hp×$healthMult)');

            final oldDamageMult =
                cachedActiveLevel?.enemyDamageMultiplier ?? 1.0;
            final oldHealthMult =
                cachedActiveLevel?.enemyHealthMultiplier ?? 1.0;

            final damageRatio = damageMult / oldDamageMult;
            final healthRatio = healthMult / oldHealthMult;

            // 1. Update the cachedActiveLevel multipliers so any newly spawned enemies/projectiles get these multipliers
            cachedActiveLevel = cachedActiveLevel?.copyWithDifficulty(
              enemyDamageMultiplier: damageMult,
              enemyHealthMultiplier: healthMult,
            );

            // 2. Adjust active enemies in the world
            for (final enemy in world.children.whereType<BaseEnemy>()) {
              enemy.maxHealth *= healthRatio;
              enemy.health *= healthRatio;
              enemy.contactDamage *= damageRatio;
            }

            // 3. Adjust active projectiles in the world
            for (final projectile in world.children.whereType<Projectile>()) {
              projectile.damage *= damageRatio;
            }
          }
        })
        .catchError((e) {
          print('│  ❌  Dynamic difficulty adjustment failed: $e');
        });
  }

  // ==========================================================================
  // Parsing & Merging
  // ==========================================================================

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
        parsedTiles.add(
          TileData(type: type.toLowerCase(), x: x, y: y, w: w, h: h),
        );
      }
    }

    for (final objRaw in objectsJson) {
      final o = objRaw as Map<String, dynamic>;
      final objType = o['type'] as String;
      final x = (o['x'] as num).toDouble();
      final y = (o['y'] as num).toDouble();

      if (objType == 'ENEMY') {
        parsedEnemies.add(
          EnemyData(x: x, y: y, type: (o['enemyType'] as String).toLowerCase()),
        );
      } else if (objType == 'PICKUP') {
        final pickupType = (o['pickupType'] as String).toLowerCase();
        // Enforce diamond cap: skip diamonds beyond the limit
        if (pickupType == 'diamond') {
          final currentDiamonds = parsedPickups
              .where((p) => p.type == 'diamond')
              .length;
          if (currentDiamonds >= GameConfig.maxDiamondsPerLevel) {
            continue; // Skip this diamond
          }
        }
        parsedPickups.add(PickupData(type: pickupType, x: x, y: y));
      }
    }

    // Parse narrative events if present (map prompt may not include them)
    final narrativeJson = json['narrativeEvents'] as List<dynamic>? ?? [];
    final List<NarrativeEvent> parsedEvents = [];
    for (final eRaw in narrativeJson) {
      final e = eRaw as Map<String, dynamic>;
      parsedEvents.add(NarrativeEvent.fromJson(e));
    }

    // Parse difficulty params if present (from combined responses or map-only)
    final enemyDamageMult = (json['enemyDamageMultiplier'] as num?)?.toDouble();
    final enemyHealthMult = (json['enemyHealthMultiplier'] as num?)?.toDouble();

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
      narrativeEvents: parsedEvents,
      enemyDamageMultiplier: enemyDamageMult,
      enemyHealthMultiplier: enemyHealthMult,
    );
  }

  /// Merge difficulty tuning response into an existing LevelData.
  LevelData _mergeDifficulty(
    LevelData level,
    Map<String, dynamic> difficultyJson,
  ) {
    final damageMult = (difficultyJson['enemyDamageMultiplier'] as num?)
        ?.toDouble();
    final healthMult = (difficultyJson['enemyHealthMultiplier'] as num?)
        ?.toDouble();
    final dialogue = difficultyJson['architectDialogue'] as String?;

    final narrativeJson =
        difficultyJson['narrativeEvents'] as List<dynamic>? ?? [];
    final List<NarrativeEvent> events = [];
    for (final eRaw in narrativeJson) {
      final e = eRaw as Map<String, dynamic>;
      events.add(NarrativeEvent.fromJson(e));
    }

    return level.copyWithDifficulty(
      enemyDamageMultiplier: damageMult,
      enemyHealthMultiplier: healthMult,
      architectDialogue: dialogue,
      narrativeEvents: events.isNotEmpty ? events : null,
    );
  }

  // ==========================================================================
  // Game Loop
  // ==========================================================================

  ParallaxComponent? _bgComponent;

  @override
  void update(double dt) {
    super.update(dt);

    // Keep parallax updated with camera position
    if (_bgComponent != null) {
      // Set the base velocity to match camera movement for the parallax effect.
      // Scale down the velocity so the background moves much slower than the foreground
      _bgComponent!.parallax!.baseVelocity = Vector2(
        player.velocity.x * 0.1,
        0,
      );
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

    // --- Mid-level difficulty trigger ---
    // Supports two modes: 'enemies' (original) and 'proximity' (distance to exit portal).
    if (gameState.currentLevel > 0 && gameState.currentLevel != -1) {
      bool inTriggerZone = false;

      if (GameConfig.difficultyTriggerMode == 'proximity') {
        // Proximity mode: trigger when player is near the exit portal
        final exitPortals = world.children.whereType<ExitPortal>();
        if (exitPortals.isNotEmpty) {
          final exitPortal = exitPortals.first;
          final dist = player.position.distanceTo(exitPortal.position);
          if (dist <= GameConfig.difficultyTriggerProximityDistance) {
            inTriggerZone = true;
          }
        }
      } else {
        // Enemy count mode (default)
        final aliveEnemies = world.children
            .whereType<BaseEnemy>()
            .where((e) => !e.isDead)
            .length;
        if (aliveEnemies <= GameConfig.difficultyTriggerEnemiesLeft) {
          inTriggerZone = true;
        }
      }

      if (inTriggerZone) {
        if (!_difficultyTriggered) {
          _triggerDifficultyGeneration(gameState.currentLevel + 1);
        }
      }
    }
  }


  void onLevelComplete() async {
    // Guard against multiple calls (e.g. if player triggers exit portal twice)
    if (_isTransitioning) {
      print(
        '[StruggleGame] Cannot transition to next level: Transition already in progress!',
      );
      return;
    }
    _isTransitioning = true;
    print('');
    print('═══════════════════════════════════════════════════════════');
    print('  🚪  LEVEL COMPLETE — Transitioning to Level ${gameState.currentLevel + 1}...');
    print('═══════════════════════════════════════════════════════════');

    removedEntitiesKeys.clear();
    gameState.completeLevel();
    playerState.resetForNewLevel(); // Reset stats and heals for the new level!

    // Capture and consume the futures locally to avoid race conditions
    final mapFuture = nextMapLayoutFuture;
    final diffFuture = nextDifficultyFuture;
    nextMapLayoutFuture = null;
    nextDifficultyFuture = null;

    // Await both the map layout and difficulty futures
    LevelData? nextLevel;
    if (mapFuture != null) {
      print(
        '│  ⏳ Awaiting pre-fetched map layout from Antigravity Agent...',
      );
      try {
        nextLevel = await mapFuture.timeout(const Duration(seconds: 1));
        print('│  ✅  Map layout resolved successfully.');
      } catch (e) {
        print('│  ⚠️  Map layout generation timed out or failed: $e');
      }
    } else {
      print('│  ⚠️  No pre-fetched map layout found.');
    }

    if (nextLevel == null) {
      final fallbackId = _getNextFallbackLevelId();
      print('│  🔄 Falling back to hardcoded level $fallbackId for Level ${gameState.currentLevel}');
      nextLevel = LevelManager.createHardcodedLevel(fallbackId);
    }

    // Merge difficulty params if available (non-blocking!)
    final difficultyParams = nextDifficultyParams;
    nextDifficultyParams = null; // Reset / consume

    if (difficultyParams != null) {
      print('│  ✅  Difficulty params resolved — merging into Level ${gameState.currentLevel}');
      if (nextLevel != null) {
        nextLevel = _mergeDifficulty(nextLevel, difficultyParams);
      }
    } else {
      print('│  ⏩  Difficulty not ready — carrying forward current multipliers.');
      if (nextLevel != null && cachedActiveLevel != null) {
        var currentDamageMult = cachedActiveLevel!.enemyDamageMultiplier;
        var currentHealthMult = cachedActiveLevel!.enemyHealthMultiplier;

        // First level is generated as easy, but if the agent fails to fetch next level difficulty,
        // we don't want the entire game to be so easy. So, we manually set the difficulty
        // for the next level to be normal.
        // This check is only for level 2 since it's the first level after the tutorial.
        if (currentDamageMult != null &&
            currentDamageMult < 1 &&
            nextLevel.levelId == 2) {
          currentDamageMult = 1;
        }
        if (currentHealthMult != null &&
            currentHealthMult < 1 &&
            nextLevel.levelId == 2) {
          currentHealthMult = 1;
        }
        print('│     Retained: dmg×$currentDamageMult, hp×$currentHealthMult');
        // Only carry forward the old dialogue if the next level doesn't already have its own
        final nextHasOwnDialogue =
            nextLevel.architectDialogue != null &&
            nextLevel.architectDialogue!.isNotEmpty;
        nextLevel = nextLevel.copyWithDifficulty(
          enemyDamageMultiplier: currentDamageMult,
          enemyHealthMultiplier: currentHealthMult,
          architectDialogue: nextHasOwnDialogue
              ? null
              : cachedActiveLevel!.architectDialogue,
        );
      }
    }

    print('│  🎮  Loading Level ${gameState.currentLevel}...');
    print('═══════════════════════════════════════════════════════════');
    print('');
    await loadLevel(gameState.currentLevel, preFetchedLevel: nextLevel);
    _isTransitioning = false;
  }

  /// Called when the player dies.
  void onPlayerDeath() {
    removedEntitiesKeys.clear();

    // Save death location for LostWill spawning before currencies are reset
    playerState.lostWillX = player.lastSafePosition?.x ?? player.position.x;
    playerState.lostWillY = player.lastSafePosition?.y ?? player.position.y;
    playerState.lostWillLevelId = gameState.currentLevel;

    // Reset difficulty trigger so we can calibrate immediately
    _difficultyTriggered = false;

    // Recalibrate difficulty immediately upon player death (using latest live telemetry)
    _triggerDifficultyGeneration(gameState.currentLevel + 1);

    playerState.resetForRetry();

    // Trigger dynamic Architect taunt on death!
    triggerDynamicTaunt('PLAYER_DEATH');

    // Reload current level from cache to prevent generating a new level
    if (GameConfig.generateNewLevelOnDeath) {
      loadLevel(gameState.currentLevel, isDeathRetry: true);
    } else {
      loadLevel(
        gameState.currentLevel,
        preFetchedLevel: cachedActiveLevel,
        isDeathRetry: true,
      );
    }
  }

  /// Trigger screen shake effect.
  void onScreenShake(double intensity) {
    _shakeIntensity = intensity;
    _shakeTimer = GameConfig.screenShakeDuration;
  }

  /// Skip the current architect cutscene (called when player presses E during cutscene)
  void skipCutscene() {
    if (!isCutscenePlaying) return;
    isCutscenePlaying = false;
    // Remove all cutscene entities from the world
    world.children.whereType<ArchitectCutsceneEntity>().toList().forEach(
      (c) => c.removeFromParent(),
    );
    // Trigger level start taunt after cutscene is skipped
    triggerDynamicTaunt('LEVEL_START');
  }

  /// Trigger dynamic Architect taunt overlay based on game conditions
  void triggerDynamicTaunt(String condition) {
    final levelData = cachedActiveLevel;
    if (levelData == null) return;

    final event = levelData.narrativeEvents.firstWhere(
      (e) => e.condition == condition && e.type == 'ARCHITECT_TAUNT',
      orElse: () =>
          NarrativeEvent(type: 'ARCHITECT_TAUNT', dialogue: '', condition: ''),
    );

    if (event.dialogue.isNotEmpty) {
      print(
        '[StruggleGame] Triggered dynamic Architect taunt ($condition): "${event.dialogue}"',
      );
      currentArchitectDialogue = event.dialogue;
      overlays.remove('ArchitectTopRightDialogue');
      overlays.add('ArchitectTopRightDialogue');
    }
  }

  /// Transition the player between the active level and the Guardian's Realm.
  void transitionThroughPortal({required bool isReturn}) {
    AudioManager.playSfx(AudioManager.sfxSelect);
    if (isReturn) {
      // Returning to main level from Guardian Realm
      final targetLevel = _previousLevelId ?? 1;
      final targetPos = _previousPlayerPosition;

      gameState.currentLevel = targetLevel;
      final savedEnemyCount = _previousAliveEnemiesCount;
      loadLevel(
        targetLevel,
        preFetchedLevel: cachedActiveLevel,
        isReturnFromPortal: true,
      ).then((_) {
        // Restore the exact enemy count from before entering the portal
        if (savedEnemyCount != null) {
          cachedAliveEnemiesCount = savedEnemyCount;
        }
        if (targetPos != null) {
          player.position.setFrom(targetPos);
          // Let the cat snap behind the player instantly
          world.children.whereType<CompanionCat>().forEach((c) {
            c.position.setFrom(
              targetPos -
                  Vector2(
                    player.facingDirection * GameConfig.catFollowOffset,
                    0,
                  ),
            );
          });
          // Ensure camera is snapped directly to the player position to avoid pan lag
          camera.viewfinder.position = targetPos;
        }
      });
    } else {
      // Entering Guardian Realm: save main level ID, player entry coordinates, and enemy count
      _previousLevelId = gameState.currentLevel;
      _previousPlayerPosition = player.position.clone();
      _previousAliveEnemiesCount = cachedAliveEnemiesCount;

      gameState.currentLevel = -1;
      loadLevel(-1);
    }
  }

  /// Open the Guardian Upgrades overlay.
  void openGuardianUpgrades() {
    AudioManager.playSfx(AudioManager.sfxSelect);
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
    if (dist < GameConfig.losMinDistance) return true;

    final dir = (end - start).normalized();
    final step = GameConfig.losRaycastStep;

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

  /// Changes the map dynamically for Boss phases
  void changeMapPhase(int phaseIndex) async {
    if (currentTheme == null) return;

    // 1. Remove environment hazards and blocks
    world.children.whereType<PlatformBlock>().forEach(
      (c) => c.removeFromParent(),
    );
    world.children.whereType<PillarComponent>().forEach(
      (c) => c.removeFromParent(),
    );
    world.children.whereType<Lava>().forEach((c) => c.removeFromParent());
    world.children.whereType<Spike>().forEach((c) => c.removeFromParent());

    // 2. Generate new tiles
    final newTiles = LevelManager.getBossPhaseTiles(phaseIndex);

    // 3. Re-validate and rebuild grid
    final mockData = LevelData(
      levelId: 5,
      width: 30,
      height: 20,
      spawn: (x: 2, y: 16),
      exit: (x: 28, y: 16),
      tiles: newTiles,
    );
    final validatedData = LevelValidator.validate(mockData);

    final grid = TileGrid.fromTiles(
      validatedData.tiles,
      validatedData.width,
      validatedData.height,
    );
    activeGrid = grid;

    // 4. Spawn only environment parts
    final components = await LevelManager.buildLevel(
      this,
      validatedData,
      currentTheme!,
    );
    for (final c in components) {
      if (c is PlatformBlock ||
          c is PillarComponent ||
          c is Lava ||
          c is Spike) {
        world.add(c);
      }
    }
  }

  /// Called when Architect dies and animation finishes
  void onBossDefeated() {
    AudioManager.stopBgm();
    AudioManager.playBgm(AudioManager.musicMenu);
    overlays.add('BossChoiceOverlay');
  }
}
