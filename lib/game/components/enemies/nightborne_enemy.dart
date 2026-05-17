import 'dart:ui';
import 'package:flame/components.dart';

import '../../asset_registry.dart';
import '../../config.dart';
import '../effects/explosion_effect.dart';
import '../player.dart';
import 'melee_enemy.dart';

enum _NAnim { idle, run, attack, hurt, death }

/// Fast, aggressive warrior. Explodes on death, dealing area damage.
/// Uses NightBorne.png — a 1840×400 grid sheet.
/// Frame layout (80×80 per frame):
///   Row 0: Idle (9 frames)
///   Row 1: Run (6 frames)
///   Row 2: Attack (12 frames)
///   Row 3: Hurt (5 frames)
///   Row 4: Death (23 frames)
class NightborneEnemy extends MeleeEnemy {
  SpriteAnimationGroupComponent<_NAnim>? _animGroup;
  _NAnim _current = _NAnim.idle;
  bool _spriteLoaded = false;
  bool _exploded = false;

  NightborneEnemy({
    required super.position,
  }) : super(
          size: GameConfig.enemyHitboxNightborne,
          maxHealth: GameConfig.enemyHealthNightborne,
          contactDamage: GameConfig.enemyDamageNightborne,
          speed: GameConfig.enemySpeedNightborne,
          patrolRange: 130,
          attackCooldown: 0.9,
          aggroRange: GameConfig.enemyAggroRange * 1.3,
          damageDelay: 0.56,
          attackRange: GameConfig.enemyAttackRangeNightborne,
          maxVerticalDiff: GameConfig.enemyAttackMaxVerticalDiffNightborne,
          attackAnimDuration: 0.84,
        );

  static final Vector2 _frame      = Vector2(80, 80);
  static final Vector2 _renderSize = GameConfig.enemySizeNightborne;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final idle = await AssetRegistry.getAnimation(
        game,
        'characters/nightborne/NightBorne.png',
        SpriteAnimationData.sequenced(
          amount: 9,
          stepTime: 0.15,
          textureSize: _frame,
          texturePosition: Vector2(0, 0),
          loop: true,
        ),
        key: 'nightborn/idle_v2',
      );

      final run = await AssetRegistry.getAnimation(
        game,
        'characters/nightborne/NightBorne.png',
        SpriteAnimationData.sequenced(
          amount: 6,
          stepTime: 0.10,
          textureSize: _frame,
          texturePosition: Vector2(0, 80),
          loop: true,
        ),
        key: 'nightborn/run_v2',
      );

      final attack = await AssetRegistry.getAnimation(
        game,
        'characters/nightborne/NightBorne.png',
        SpriteAnimationData.sequenced(
          amount: 12,
          stepTime: 0.07,
          textureSize: _frame,
          texturePosition: Vector2(0, 160),
          loop: false,
        ),
        key: 'nightborn/attack_v2',
      );

      final hurt = await AssetRegistry.getAnimation(
        game,
        'characters/nightborne/NightBorne.png',
        SpriteAnimationData.sequenced(
          amount: 5,
          stepTime: 0.10,
          textureSize: _frame,
          texturePosition: Vector2(0, 240),
          loop: false,
        ),
        key: 'nightborn/hurt_v2',
      );

      final death = await AssetRegistry.getAnimation(
        game,
        'characters/nightborne/NightBorne.png',
        SpriteAnimationData.sequenced(
          amount: 23,
          stepTime: 0.06,
          textureSize: _frame,
          texturePosition: Vector2(0, 320),
          loop: false,
        ),
        key: 'nightborn/death_v2',
      );

      _animGroup = SpriteAnimationGroupComponent<_NAnim>(
        animations: {
          _NAnim.idle:   idle,
          _NAnim.run:    run,
          _NAnim.attack: attack,
          _NAnim.hurt:   hurt,
          _NAnim.death:  death,
        },
        current: _NAnim.idle,
        size: _renderSize,
        position: Vector2(size.x / 2, size.y + GameConfig.enemyYOffsetNightborne),
        anchor: Anchor.bottomCenter,
      );
      add(_animGroup!);
      animComp = _animGroup;
      _spriteLoaded = true;
    } catch (_) {}
  }

  @override
  void onMeleeSwing(Player player) {
    super.onMeleeSwing(player);
    if (_spriteLoaded && _animGroup != null) {
      _current = _NAnim.attack;
      _animGroup!.current = _NAnim.attack;
      _animGroup!.animationTickers?[_NAnim.attack]?.reset();
    }
  }

  @override
  bool takeDamage(double damage) {
    if (isDead) return false;
    final fatal = super.takeDamage(damage);
    if (!fatal && _spriteLoaded && _animGroup != null) {
      _current = _NAnim.hurt;
      _animGroup!.current = _NAnim.hurt;
      _animGroup!.animationTickers?[_NAnim.hurt]?.reset();
    }
    return fatal;
  }

  @override
  bool get isAttackingState => _current == _NAnim.attack;

  @override
  void update(double dt) {
    super.update(dt);
    if (!_spriteLoaded) return;

    if (isDead) {
      final deathTicker = _animGroup!.animationTickers?[_NAnim.death];
      if (deathTicker != null) {
        // Track the current frame of the death animation (0-indexed, 12th frame is index 11)
        final currentFrame = deathTicker.currentIndex;
        if (currentFrame >= 11 && !_exploded) {
          _exploded = true;
          // Spawn the explosion exactly on the 12th frame of death!
          parent?.add(ExplosionEffect(
            center: position + size / 2,
          ));
        }

        if (deathTicker.done()) {
          removeFromParent();
        }
      }
      return;
    }

    // Hurt animation state lock: guarantee that the 5-frame hurt animation plays to completion
    final hurtTicker = _animGroup!.animationTickers?[_NAnim.hurt];
    if (_current == _NAnim.hurt && hurtTicker != null && hurtTicker.done()) {
      _current = _NAnim.idle;
      _animGroup!.current = _NAnim.idle;
    }

    final ticker = _animGroup!.animationTickers?[_NAnim.attack];
    if (_current == _NAnim.attack && ticker != null && ticker.done()) {
      _current = _NAnim.idle;
      _animGroup!.current = _NAnim.idle;
    }

    if (_current != _NAnim.attack && _current != _NAnim.hurt) {
      final newAnim = switch (currentState) {
        MeleeState.patrol => _NAnim.run,
        MeleeState.chase  => isStationary ? _NAnim.idle : _NAnim.run,
        MeleeState.attack => _NAnim.idle,
      };
      if (newAnim != _current) {
        _current = newAnim;
        _animGroup!.current = _current;
        _animGroup!.animationTickers?[_current]?.reset();
      }
    }
  }

  @override
  void onDeath() {
    if (_spriteLoaded && _animGroup != null) {
      _current = _NAnim.death;
      _animGroup!.current = _NAnim.death;
      _animGroup!.animationTickers?[_NAnim.death]?.reset();
    } else {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Glow eyes to indicate dangerous elite
    if (!_spriteLoaded) renderPlaceholder(canvas, const Color(0xFF4B0082));
    // Purple glowing outline when health is low
    if (health / maxHealth < 0.3) {
      canvas.drawRect(
        Rect.fromLTWH(-2, -2, size.x + 4, size.y + 4),
        Paint()
          ..color = const Color(0x88EE00FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }
}
