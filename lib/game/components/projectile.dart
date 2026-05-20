import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart' hide Block;

import '../components/block.dart';
import '../config.dart';
import '../struggler_game.dart';
import '../systems/audio_manager.dart';
import 'player.dart';

// ---------------------------------------------------------------------------
// Projectile — base class for all enemy-fired projectiles.
// ---------------------------------------------------------------------------
abstract class Projectile extends PositionComponent
    with CollisionCallbacks, HasGameReference<StruggleGame> {
  double damage;
  final double maxRange;
  double _distanceTravelled = 0;
  bool _hasHit = false;
  final Set<Player> _dodgedPlayers = {};

  Projectile({
    required Vector2 position,
    required Vector2 size,
    required this.damage,
    required this.maxRange,
  }) : super(position: position, size: size);

  void playImpactSound();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());

    // Apply GameConfig multiplier and dynamic Level custom multiplier!
    damage = damage * GameConfig.enemyDamageMultiplier;
    final levelData = game.cachedActiveLevel;
    if (levelData != null) {
      final customDamageMult = levelData.enemyDamageMultiplier ?? 1.0;
      damage *= customDamageMult;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isCutscenePlaying) return;
    if (_hasHit) return;
    final delta = moveStep(dt);
    position += delta;
    _distanceTravelled += delta.length;
    if (_distanceTravelled >= maxRange) {
      removeFromParent();
    }
  }

  /// Subclasses return the displacement vector for this frame.
  Vector2 moveStep(double dt);

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (_hasHit) return;
    if (other is Player) {
      if (!other.isInvincible) {
        other.receiveDamage(damage);
        _hasHit = true;
        playImpactSound();
        removeFromParent();
      } else {
        // Dodge through it — reward resolve if this is the first overlap
        if (!_dodgedPlayers.contains(other)) {
          _dodgedPlayers.add(other);
          game.playerState.perfectDodges++;
          game.playerState.perfectDodgesThisLevel++;
          game.playerState.addResolve(GameConfig.perfectDodgeResolveReward);
        }
        // Do NOT destroy the projectile or stop it! Let it cleanly fly straight through!
      }
    } else if (other is PlatformBlock) {
      _hasHit = true;
      removeFromParent();
    }
  }
}

// ---------------------------------------------------------------------------
// ArrowProjectile — fast horizontal arrow fired by the Arcane Archer.
// ---------------------------------------------------------------------------
class ArrowProjectile extends Projectile {
  final int direction; // 1 = right, -1 = left
  final Vector2? targetVector;
  static const double _speed = GameConfig.arrowSpeed;
  SpriteComponent? _spriteComp;

  ArrowProjectile({
    required super.position,
    required this.direction,
    this.targetVector,
  }) : super(
         size: GameConfig.arrowProjectileSize,
         damage: GameConfig.arrowDamage,
         maxRange: GameConfig.arrowRange,
       ) {
    anchor = Anchor.center;
  }

  @override
  void playImpactSound() {
    AudioManager.playSfx(AudioManager.sfxBowHit);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final img = await game.images.load('characters/archer/projectile.png');
      _spriteComp = SpriteComponent(
        sprite: Sprite(img),
        size: size,
        anchor: Anchor.center,
        position: size / 2,
      );
      if (targetVector != null) {
        angle = atan2(targetVector!.y, targetVector!.x);
      } else if (direction == -1) {
        _spriteComp!
            .flipHorizontallyAroundCenter(); // Point left if arrow moves left!
      }
      add(_spriteComp!);
    } catch (_) {
      // Fallback
    }
  }

  @override
  Vector2 moveStep(double dt) {
    if (targetVector != null) {
      return targetVector! * _speed * dt;
    }
    return Vector2(_speed * direction * dt, 0);
  }

  @override
  void render(Canvas canvas) {
    if (_spriteComp == null) {
      super.render(canvas);
      final paint = Paint()..color = const Color(0xFFFFA500);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
      // Arrow tip
      canvas.drawRect(
        Rect.fromLTWH(direction == 1 ? size.x - 4 : 0, -1, 4, 7),
        Paint()..color = const Color(0xFFFFD700),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// OrbProjectile — slow sinusoidal orb fired by the Wizard.
// ---------------------------------------------------------------------------
class OrbProjectile extends Projectile {
  final int direction;
  final Vector2? targetVector;
  static const double _speed = GameConfig.orbSpeed;
  static const double _amplitude = 10.0; // vertical sine wave amplitude (px)
  static const double _frequency = 2.0; // Hz
  static const double _turnRate = 1.5; // Radians per second
  double _elapsed = 0;
  Vector2? _currentVelocity;

  OrbProjectile({
    required super.position,
    required this.direction,
    this.targetVector,
  }) : super(
         size: GameConfig.orbProjectileSize,
         damage: GameConfig.orbDamage,
         maxRange: GameConfig.orbRange,
       );

  @override
  void playImpactSound() {
    AudioManager.playSfx(AudioManager.sfxSpellHit);
  }

  @override
  Vector2 moveStep(double dt) {
    _elapsed += dt;
    final player = game.player;

    if (_currentVelocity == null) {
      if (targetVector != null) {
        _currentVelocity = targetVector!.normalized() * _speed;
      } else {
        _currentVelocity = Vector2(_speed * direction, 0);
      }
    }

    final toPlayer = (player.position + player.size / 2) - (position + size / 2);

    final targetAngle = atan2(toPlayer.y, toPlayer.x);
    final currentAngle = atan2(_currentVelocity!.y, _currentVelocity!.x);
    
    double angleDiff = targetAngle - currentAngle;
    while (angleDiff > pi) { angleDiff -= 2 * pi; }
    while (angleDiff < -pi) { angleDiff += 2 * pi; }
    
    final maxTurn = _turnRate * dt;
    final turn = angleDiff.clamp(-maxTurn, maxTurn);
    
    final newAngle = currentAngle + turn;
    _currentVelocity = Vector2(cos(newAngle), sin(newAngle)) * _speed;

    final perp = Vector2(-_currentVelocity!.y, _currentVelocity!.x).normalized();
    final dy = perp * sin(_elapsed * _frequency * 2 * pi) * _amplitude * dt;

    return _currentVelocity! * dt + dy;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final pulse = (sin(_elapsed * 4) * 0.15 + 0.85).clamp(0.0, 1.0);
    final paint = Paint()
      ..color =
          Color.fromARGB(
            (255 * pulse).round(),
            166,
            233,
            37,
          ) // Green #a6e925 glow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, paint);
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 3,
      Paint()..color = const Color(0xFFa6e925), // Green core #a6e925
    );
  }
}

// ---------------------------------------------------------------------------
// ThunderHandProjectile — falls straight down from above the player.
// Spawned by BringerEnemy. Uses the Bringer's Spell sprite sequence.
// ---------------------------------------------------------------------------
class ThunderHandProjectile extends Projectile {
  SpriteAnimationComponent? _animComp;
  double _elapsed = 0;
  bool _hasAppliedDamage = false;
  bool _hasPlayedImpactSound = false;

  ThunderHandProjectile({required super.position})
    : super(
        size: GameConfig.thunderHandSize,
        damage: GameConfig.thunderDamage,
        maxRange: GameConfig.thunderHandMaxRange,
      );

  @override
  void playImpactSound() {
    // Handled customly in update() when crashing into ground
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final sprites = <Sprite>[];
      const prefix =
          'characters/bringer/IndividualSprite/Spell/Bringer-of-Death_Spell_';
      for (int i = 1; i <= 16; i++) {
        final img = await game.images.load('$prefix$i.png');
        sprites.add(Sprite(img));
      }
      // Slower, dramatic cast speed (0.25s per frame) and single-play (loop: false)
      final anim = SpriteAnimation.spriteList(
        sprites,
        stepTime: 0.25,
        loop: false,
      );
      _animComp = SpriteAnimationComponent(animation: anim, size: size);
      add(_animComp!);
    } catch (_) {
      // Fallback
    }
  }

  @override
  // ignore: must_call_super
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    // Override base class to prevent immediate removal of the projectile on contact!
  }

  @override
  Vector2 moveStep(double dt) {
    _elapsed += dt;
    return Vector2.zero(); // The hand visual animation itself handles the downward strike!
  }

  @override
  void update(double dt) {
    super.update(dt);
    final ticker = _animComp?.animationTicker;
    if (ticker != null) {
      if (ticker.done()) {
        removeFromParent(); // Auto-remove projectile once the spell animation completes!
        return;
      }

      // Play the crash sound when the hand strikes down (starts at frame index 4)
      if (ticker.currentIndex >= 4 && !_hasPlayedImpactSound) {
        _hasPlayedImpactSound = true;
        AudioManager.playSfx(AudioManager.sfxThunderImpact);
      }

      // Phase 2 Damage Trigger: Apply damage exactly once when the hand strikes down (active only on frame index 4 to 7)
      if (ticker.currentIndex >= 4 &&
          ticker.currentIndex <= 7 &&
          !_hasAppliedDamage) {
        final player = game.player;
        final projectileRect = toRect();

        // Define a narrowed central vertical strike zone (40px wide)
        final strikeZone = Rect.fromLTWH(
          projectileRect.left + (projectileRect.width - 40.0) / 2,
          projectileRect.top,
          40.0,
          projectileRect.height,
        );

        if (strikeZone.overlaps(player.toRect())) {
          if (!player.isInvincible) {
            player.receiveDamage(damage);
          } else {
            player.game.playerState.perfectDodges++;
            player.game.playerState.perfectDodgesThisLevel++;
            player.game.playerState.addResolve(GameConfig.perfectDodgeResolveReward);
          }
          _hasAppliedDamage = true;
        }
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (_animComp == null) {
      super.render(canvas);
      // Drawn fallback: purple downward-pointing hand shape
      final pulse = (sin(_elapsed * 8) * 0.2 + 0.8).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(size.x * 0.2, 0, size.x * 0.6, size.y),
        Paint()
          ..color = Color.fromARGB((200 * pulse).round(), 160, 0, 255)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawRect(
        Rect.fromLTWH(size.x * 0.3, size.y * 0.6, size.x * 0.4, size.y * 0.4),
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }
  }
}
