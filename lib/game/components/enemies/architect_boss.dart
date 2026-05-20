import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';

import '../../config.dart';
import '../effects/teleport_effect.dart';
import '../enemy.dart';
import '../dialogue_bubble.dart';
import 'skeleton_enemy.dart';
import 'bringer_enemy.dart';
import 'nightborne_enemy.dart';

// ---------------------------------------------------------------------------
// ArchitectBoss — Placeholder. Floats in idle, teleports every N seconds.
// Indestructible by default (isDamageable = false).
//
// Teleport sequence (pure in-engine, no extra assets):
//   1. Tell      — TeleportEffect particle burst at current position
//   2. Shrink    — scaleX 1→0.05, scaleY 1→1.8, alpha 1→0 over shrinkTime
//   3. Vanish    — isVisible=false, position snaps to target
//   4. Reappear  — isVisible=true, reverse shrink, second TeleportEffect
//   5. Resume idle bob
// ---------------------------------------------------------------------------
enum _TeleportPhase { none, tell, shrink, vanish, grow }

class ArchitectBoss extends BaseEnemy {
  // --- Sprite ---
  SpriteAnimationComponent? _idleComp;
  bool _spriteLoaded = false;

  // --- Boss Phases ---
  int _currentMapPhase = 0;

  // --- Gameplay ---
  // Overridden takeDamage handles indestructibility

  // --- Bob ---
  double _bobTimer = 0;

  // --- Teleport ---
  _TeleportPhase _phase = _TeleportPhase.none;
  double _phaseTimer = 0;
  double _teleportCooldown = GameConfig.architectTeleportInterval;
  static const double _shrinkTime = GameConfig.architectTeleportShrinkTime;

  // Scale/alpha for squash-stretch
  double _scaleX = 1.0;
  double _scaleY = 1.0;
  double _alpha = 1.0;

  // --- Death Sequence ---
  bool _isDying = false;
  bool _isDefeated = false;
  double _deathTimer = 0;
  double _explosionTimer = 0;
  double _flashToggleTimer = 0;
  bool _flashState = false;
  double _enemySpawnTimer = 5.0; // Spawns enemies every 5 seconds
  double _originalY = 0.0;

  // Target position for the snap
  Vector2 _teleportTarget = Vector2.zero();

  final Random _rng = Random();

  ArchitectBoss({required super.position})
    : super(
        size: GameConfig.enemyHitboxArchitect,
        maxHealth: GameConfig.enemyHealthArchitect,
        contactDamage: GameConfig.enemyDamageArchitect,
      );

  @override
  int get willpowerReward => GameConfig.enemyWillArchitect;

  @override
  double get resolveReward => GameConfig.enemyResolveArchitect;

  @override
  double get healthBarYOffset => GameConfig.enemyHealthBarYOffsetArchitect;

  // architect/idle.png = 3360×240, 15 frames at 224×240
  static const int _frameCount = 15;
  static const double _frameWidth = 224.0;
  static const double _frameHeight = 240.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final image = await game.images.load('characters/architect/idle.png');
      final anim = SpriteAnimation.spriteList(
        List.generate(
          _frameCount,
          (i) => Sprite(
            image,
            srcPosition: Vector2(i * _frameWidth, 0),
            srcSize: Vector2(_frameWidth, _frameHeight),
          ),
        ),
        stepTime: 0.07,
      );
      _idleComp = SpriteAnimationComponent(
        animation: anim,
        size: Vector2(112.0, 120.0), // visual size scaling
        anchor: Anchor.center,
        position: size / 2,
      );
      add(_idleComp!);
      _spriteLoaded = true;
      _originalY = position.y;
    } catch (e, stack) {
      print('ERROR LOADING ARCHITECT BOSS: $e');
      print(stack);
    }
  }

  @override
  void update(double dt) {
    if (game.isCutscenePlaying) {
      super.update(dt);
      return;
    }
    if (_isDying) {
      _deathTimer -= dt;
      if (_deathTimer <= 0) {
        // Final massive burst of arrival/teleport effects
        for (int i = 0; i < 8; i++) {
          final offset = Vector2(
            _rng.nextDouble() * size.x - size.x / 2,
            _rng.nextDouble() * size.y - size.y / 2,
          );
          parent?.add(TeleportEffect(center: position + size / 2 + offset));
        }
        removeFromParent();
        game.onBossDefeated();
        return;
      }

      // 1. Violent Screen Shake!
      game.onScreenShake(14.0);

      // 2. Spawn continuous teleport implosion/explosion effects
      _explosionTimer -= dt;
      if (_explosionTimer <= 0) {
        _explosionTimer = 0.12 + _rng.nextDouble() * 0.12;
        final offset = Vector2(
          _rng.nextDouble() * size.x - size.x / 2,
          _rng.nextDouble() * size.y - size.y / 2,
        );
        parent?.add(TeleportEffect(center: position + size / 2 + offset));
      }

      // 3. Rapidly flash between white and red
      _flashToggleTimer -= dt;
      if (_flashToggleTimer <= 0) {
        _flashToggleTimer = 0.04;
        _flashState = !_flashState;
      }

      // 4. Distort the scale (collapse, spin, and shrink violently)
      final progress = (2.0 - _deathTimer) / 2.0; // 0 to 1
      _scaleX = (1.0 - progress) * (1.0 + sin(_deathTimer * 45) * 0.5);
      _scaleY = (1.0 - progress) * (1.0 + cos(_deathTimer * 45) * 0.5);
      _alpha = 1.0 - progress;

      if (_spriteLoaded && _idleComp != null) {
        _idleComp!.scale = Vector2(
          _scaleX * (facingDir == 1 ? 1 : -1),
          _scaleY,
        );
        _idleComp!.angle += 15.0 * dt; // Spin dynamically!
        _idleComp!.paint.colorFilter = ColorFilter.mode(
          _flashState ? const Color(0xFFFFFFFF) : const Color(0xFFFF3333),
          BlendMode.srcATop,
        );
      }
      return; // Skip normal update routines
    }

    // If defeated, just bob and wait for choice
    if (_isDefeated) {
      _bobTimer += dt;
      if (_spriteLoaded && _idleComp != null) {
        _idleComp!.position = Vector2(size.x / 2, size.y / 2 + sin(_bobTimer * GameConfig.architectBobSpeed) * GameConfig.architectBobAmplitude);
        _idleComp!.paint.colorFilter = const ColorFilter.mode(Color(0x88FF0000), BlendMode.srcATop);
      }
      return;
    }

    // Keep him floating and immune to gravity
    super.update(dt);
    position.y = _originalY;

    // --- Enemy Spawning ---
    _enemySpawnTimer -= dt;
    if (_enemySpawnTimer <= 0) {
      _enemySpawnTimer = 8.0 - _currentMapPhase; // Spawns faster in later phases
      _spawnMinion();
    }

    // --- Teleport cooldown ---
    if (_phase == _TeleportPhase.none) {
      _teleportCooldown -= dt;
      if (_teleportCooldown <= 0) {
        _beginTeleport();
      }
    }

    // --- Bob ---
    _bobTimer += dt;
    final bobY =
        sin(_bobTimer * GameConfig.architectBobSpeed) *
        GameConfig.architectBobAmplitude;

    // --- Teleport phases ---
    switch (_phase) {
      case _TeleportPhase.tell:
        _phaseTimer -= dt;
        if (_phaseTimer <= 0) {
          _phase = _TeleportPhase.shrink;
          _phaseTimer = _shrinkTime;
        }
        break;

      case _TeleportPhase.shrink:
        _phaseTimer -= dt;
        final t = 1.0 - (_phaseTimer / _shrinkTime).clamp(0.0, 1.0);
        _scaleX = 1.0 - t * 0.95;
        _scaleY = 1.0 + t * 0.8;
        _alpha = 1.0 - t;
        if (_phaseTimer <= 0) {
          _phase = _TeleportPhase.vanish;
        }
        break;

      case _TeleportPhase.vanish:
        // Snap position, spawn arrival effect, start grow
        position = _teleportTarget;
        parent?.add(TeleportEffect(center: position + size / 2));
        _phase = _TeleportPhase.grow;
        _phaseTimer = _shrinkTime;
        break;

      case _TeleportPhase.grow:
        _phaseTimer -= dt;
        final t = 1.0 - (_phaseTimer / _shrinkTime).clamp(0.0, 1.0);
        _scaleX = t;
        _scaleY = 1.0 + (1.0 - t) * 0.8;
        _alpha = t;
        if (_phaseTimer <= 0) {
          _scaleX = 1.0;
          _scaleY = 1.0;
          _alpha = 1.0;
          _phase = _TeleportPhase.none;
          _teleportCooldown = GameConfig.architectTeleportInterval;
        }
        break;

      case _TeleportPhase.none:
        // Apply idle bob (only when not teleporting)
        if (_spriteLoaded && _idleComp != null) {
          _idleComp!.position = Vector2(size.x / 2, size.y / 2 + bobY);
        }
        break;
    }

    // Apply squash-stretch scale and alpha opacity directly to the sprite component
    if (_spriteLoaded && _idleComp != null) {
      _idleComp!.scale = Vector2(_scaleX * (facingDir == 1 ? 1 : -1), _scaleY);
      if (hurtTimer > 0) {
        _idleComp!.paint.colorFilter = const ColorFilter.mode(
          Color(0xFFFFFFFF),
          BlendMode.srcATop,
        );
      } else {
        _idleComp!.paint.colorFilter = null;
        _idleComp!.paint.color = const Color(
          0xffffffff,
        ).withValues(alpha: _alpha.clamp(0.0, 1.0));
      }
    }
  }

  int facingDir = 1;

  void _spawnMinion() {
    final activeGrid = game.activeGrid;
    if (activeGrid == null) return;
    
    // Pick a safe column
    int tx = 2 + _rng.nextInt(activeGrid.width - 4);
    int floorY = -1;
    for (int y = 0; y < activeGrid.height; y++) {
      if (activeGrid.isSolid(tx, y)) {
        floorY = y;
        break;
      }
    }
    
    if (floorY > 0) {
      final spawnPos = Vector2(tx * GameConfig.tileSize.toDouble(), (floorY - 1) * GameConfig.tileSize.toDouble());
      BaseEnemy minion;
      // Spawn different enemies based on phase
      if (_currentMapPhase >= 4) {
        minion = _rng.nextBool() ? NightborneEnemy(position: spawnPos) : BringerEnemy(position: spawnPos);
      } else if (_currentMapPhase >= 2) {
        minion = _rng.nextBool() ? BringerEnemy(position: spawnPos) : SkeletonEnemy(position: spawnPos);
      } else {
        minion = SkeletonEnemy(position: spawnPos);
      }
      
      parent?.add(minion);
      parent?.add(TeleportEffect(center: spawnPos + Vector2(16, 16)));
    }
  }

  void _beginTeleport() {
    _phase = _TeleportPhase.tell;
    _phaseTimer = 0.30; // Brief pause before shrink

    // Spawn departure particles
    parent?.add(TeleportEffect(center: position + size / 2));

    _teleportTarget = _findSafeTeleportLocation();
    facingDir = _teleportTarget.x > position.x ? 1 : -1;
  }

  Vector2 _findSafeTeleportLocation() {
    final activeGrid = game.activeGrid;
    if (activeGrid == null) return Vector2(position.x, position.y);
    
    // Try to find a valid teleport location
    for (int attempts = 0; attempts < 10; attempts++) {
      int tx = 2 + _rng.nextInt(activeGrid.width - 4);
      
      int floorY = -1;
      for (int y = 0; y < activeGrid.height; y++) {
        if (activeGrid.isSolid(tx, y)) {
          floorY = y;
          break;
        }
      }
      
      if (floorY >= 3) {
        // Check if 3x3 area above floor is empty
        bool isEmpty = true;
        for (int y = floorY - 3; y < floorY; y++) {
          for (int x = tx - 1; x <= tx + 1; x++) {
            if (activeGrid.isSolid(x, y)) {
              isEmpty = false;
              break;
            }
          }
        }
        
        if (isEmpty) {
          // Valid location found! Set new floating Y so he doesn't clip walls
          final newY = (floorY - 2.5) * GameConfig.tileSize;
          _originalY = newY;
          return Vector2(tx * GameConfig.tileSize.toDouble(), newY);
        }
      }
    }
    
    // Fallback if no safe spot found
    final dist = 200.0 + _rng.nextDouble() * 250;
    final dir = _rng.nextBool() ? 1 : -1;
    final maxBounds = (activeGrid.width * GameConfig.tileSize) - 64;
    return Vector2((position.x + dir * dist).clamp(64, maxBounds.toDouble()), position.y);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // If sprite loaded, Flame renders child component automatically with correct opacity.
    // If not, draw high-visibility glowing fallback circles.
    if (!_spriteLoaded || _idleComp == null) {
      final center = Offset(size.x / 2, size.y / 2);
      // Swirling outer ring
      canvas.drawCircle(
        center,
        size.x * 0.45,
        Paint()..color = Color.fromARGB((_alpha * 120).round(), 180, 0, 255),
      );
      // Bright core
      canvas.drawCircle(
        center,
        size.x * 0.25,
        Paint()..color = Color.fromARGB((_alpha * 255).round(), 255, 100, 255),
      );
    }
  }

  @override
  bool takeDamage(double damage, {bool isPlunge = false}) {
    if (isDead || _isDying || _isDefeated) return false;
    
    health -= damage;
    if (health <= 0) {
      health = 0;
      _isDefeated = true;
      _phase = _TeleportPhase.none;
      _teleportCooldown = 999999.0;
      
      // Stop all minions
      parent?.children.whereType<BaseEnemy>().where((e) => e != this).forEach((e) => e.takeDamage(9999));
      
      game.onBossDefeated();
      return true;
    }

    hurtTimer = 0.15; // Brief high-impact white flash
    _checkPhaseTransition();
    return false;
  }

  void _checkPhaseTransition() {
    final pct = health / maxHealth;
    int nextPhase = _currentMapPhase;

    if (pct <= 0.2) {
      nextPhase = 4;
    } else if (pct <= 0.4) {
      nextPhase = 3;
    } else if (pct <= 0.6) {
      nextPhase = 2;
    } else if (pct <= 0.8) {
      nextPhase = 1;
    }

    if (nextPhase > _currentMapPhase) {
      _currentMapPhase = nextPhase;

      // Force an immediate teleport when phase changes
      _beginTeleport();

      game.changeMapPhase(_currentMapPhase);

      // Show dialogue
      if (_currentMapPhase <= GameConfig.architectPhaseDialogues.length) {
        final dialogue =
            GameConfig.architectPhaseDialogues[_currentMapPhase - 1];
        add(DialogueBubble(text: dialogue, duration: 3.0));
      }
    }
  }

  @override
  void onDeath() {
    // Overridden so super.takeDamage() doesn't immediately remove us
  }

  void executeDeath() {
    if (_isDying) return;
    _isDying = true;
    _deathTimer = 2.0; // 2 seconds of glorious final boss collapse!
    _explosionTimer = 0.1;
    _flashToggleTimer = 0.05;
  }
}
