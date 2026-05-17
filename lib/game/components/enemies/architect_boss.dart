import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';

import '../../config.dart';
import '../effects/teleport_effect.dart';
import '../enemy.dart';

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
  double _alpha  = 1.0;

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

  // architect/idle.png = 3360×240, 15 frames at 224×240
  static const int    _frameCount  = 15;
  static const double _frameWidth  = 224.0;
  static const double _frameHeight = 240.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final image = await game.images.load('characters/architect/idle.png');
      final anim = SpriteAnimation.spriteList(
        List.generate(_frameCount, (i) => Sprite(image,
            srcPosition: Vector2(i * _frameWidth, 0),
            srcSize: Vector2(_frameWidth, _frameHeight))),
        stepTime: 0.07,
      );
      _idleComp = SpriteAnimationComponent(
        animation: anim,
        size: size,
        anchor: Anchor.center,
        position: size / 2,
      );
      add(_idleComp!);
      _spriteLoaded = true;
    } catch (e, stack) {
      print('ERROR LOADING ARCHITECT BOSS: $e');
      print(stack);
    }
  }

  @override
  void update(double dt) {
    // Keep him floating and immune to gravity
    final originalY = position.y;
    super.update(dt);
    position.y = originalY;

    // --- Teleport cooldown ---
    if (_phase == _TeleportPhase.none) {
      _teleportCooldown -= dt;
      if (_teleportCooldown <= 0) {
        _beginTeleport();
      }
    }

    // --- Bob ---
    _bobTimer += dt;
    final bobY = sin(_bobTimer * GameConfig.architectBobSpeed) *
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
        _alpha  = 1.0 - t;
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
        _alpha  = t;
        if (_phaseTimer <= 0) {
          _scaleX = 1.0; _scaleY = 1.0; _alpha = 1.0;
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
      _idleComp!.paint.color = const Color(0xffffffff).withOpacity(_alpha.clamp(0.0, 1.0));
    }
  }

  int facingDir = 1;

  void _beginTeleport() {
    _phase = _TeleportPhase.tell;
    _phaseTimer = 0.30; // Brief pause before shrink

    // Spawn departure particles
    parent?.add(TeleportEffect(center: position + size / 2));

    // Pick random target — 200–450 px away horizontally
    final dir = _rng.nextBool() ? 1 : -1;
    final dist = 200.0 + _rng.nextDouble() * 250;
    _teleportTarget = Vector2(
      (position.x + dir * dist).clamp(32, 5000),
      position.y,
    );
    facingDir = dir == 1 ? 1 : -1;
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

  // The architect isn't attacked by the player in placeholder mode
  @override
  bool takeDamage(double _) => false;
}
