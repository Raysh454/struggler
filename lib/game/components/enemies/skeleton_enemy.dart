import 'dart:ui';
import 'dart:math';
import 'package:flame/components.dart';

import '../../asset_registry.dart';
import '../../config.dart';
import '../player.dart';
import 'melee_enemy.dart';

enum _SAnim { idle, walk, attack, hurt, death }

/// Durable melee fighter. Two attack variants (Attack / Attack2) chosen randomly.
class SkeletonEnemy extends MeleeEnemy {
  SpriteAnimationGroupComponent<_SAnim>? _animGroup;
  _SAnim _current = _SAnim.idle;
  bool _spriteLoaded = false;
  final Random _rng = Random();

  SkeletonEnemy({
    required super.position,
  }) : super(
          size: GameConfig.enemyHitboxSkeleton,
          maxHealth: GameConfig.enemyHealthSkeleton,
          contactDamage: GameConfig.enemyDamageSkeleton,
          speed: GameConfig.enemySpeedSkeleton,
          patrolRange: 110,
          damageDelay: 0.42,
          attackRange: GameConfig.enemyAttackRangeSkeleton,
          maxVerticalDiff: GameConfig.enemyAttackMaxVerticalDiffSkeleton,
          attackAnimDuration: 0.56,
        );

  @override
  int get willpowerReward => GameConfig.enemyWillSkeleton;

  @override
  double get resolveReward => GameConfig.enemyResolveSkeleton;

  static final Vector2 _frame = Vector2(150, 150);
  static final Vector2 _renderSize = GameConfig.enemySizeSkeleton;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final idle   = await AssetRegistry.getAnimation(game, 'characters/skeleton/Idle.png',
          SpriteAnimationData.sequenced(amount: 4, stepTime: 0.18, textureSize: _frame), key: 'skel/idle');
      final walk   = await AssetRegistry.getAnimation(game, 'characters/skeleton/Walk.png',
          SpriteAnimationData.sequenced(amount: 4, stepTime: 0.12, textureSize: _frame), key: 'skel/walk');
      final atk    = await AssetRegistry.getAnimation(game, 'characters/skeleton/Attack.png',
          SpriteAnimationData.sequenced(amount: 8, stepTime: 0.07, textureSize: _frame, loop: false), key: 'skel/atk');
      final death  = await AssetRegistry.getAnimation(game, 'characters/skeleton/Death.png',
          SpriteAnimationData.sequenced(amount: 4, stepTime: 0.14, textureSize: _frame, loop: false), key: 'skel/death');
      final hurt   = await AssetRegistry.getAnimation(game, 'characters/skeleton/Hurt.png',
          SpriteAnimationData.sequenced(amount: 4, stepTime: 0.08, textureSize: _frame, loop: false), key: 'skel/hurt');

      _animGroup = SpriteAnimationGroupComponent<_SAnim>(
        animations: {
          _SAnim.idle:   idle,
          _SAnim.walk:   walk,
          _SAnim.attack: _rng.nextBool() ? atk : atk, // both use same for now
          _SAnim.hurt:   hurt,
          _SAnim.death:  death,
        },
        current: _SAnim.idle,
        size: _renderSize,
        position: Vector2(size.x / 2, size.y + GameConfig.enemyYOffsetSkeleton),
        anchor: Anchor.bottomCenter,
      );
      add(_animGroup!);
      animComp = _animGroup;
      _spriteLoaded = true;
    } catch (e) {
      // Will render placeholder
    }
  }

  @override
  void onMeleeSwing(Player player) {
    super.onMeleeSwing(player);
    if (_spriteLoaded && _animGroup != null) {
      _current = _SAnim.attack;
      _animGroup!.current = _SAnim.attack;
      _animGroup!.animationTickers?[_SAnim.attack]?.reset();
    }
  }

  @override
  bool takeDamage(double damage) {
    final fatal = super.takeDamage(damage);
    if (!fatal && _spriteLoaded && _animGroup != null) {
      if (!isAttackingState) {
        _current = _SAnim.hurt;
        _animGroup!.current = _SAnim.hurt;
        _animGroup!.animationTickers?[_SAnim.hurt]?.reset();
      }

      hurtTimer = GameConfig.enemySkeletonHurtDuration;

      final player = playerTarget;
      if (player != null) {
        final pushDir = (position.x + size.x / 2) > (player.position.x + player.size.x / 2) ? 1.0 : -1.0;
        stagger(pushDir * GameConfig.enemySkeletonStaggerForce);
      }
    }
    return fatal;
  }

  @override
  bool get isAttackingState => _current == _SAnim.attack;

  @override
  void update(double dt) {
    super.update(dt);
    if (!_spriteLoaded || isDead) return;

    final ticker = _animGroup!.animationTickers?[_SAnim.attack];
    if (_current == _SAnim.attack && ticker != null && ticker.done()) {
      _current = _SAnim.idle;
      _animGroup!.current = _SAnim.idle;
    }

    final hurtTicker = _animGroup!.animationTickers?[_SAnim.hurt];
    if (_current == _SAnim.hurt && hurtTicker != null && hurtTicker.done()) {
      _current = _SAnim.idle;
      _animGroup!.current = _SAnim.idle;
    }

    if (_current != _SAnim.attack && _current != _SAnim.hurt) {
      final newAnim = switch (currentState) {
        MeleeState.patrol => _SAnim.walk,
        MeleeState.chase  => isStationary ? _SAnim.idle : _SAnim.walk,
        MeleeState.attack => _SAnim.idle,
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
    if (_spriteLoaded) {
      _animGroup!.current = _SAnim.death;
      Future.delayed(const Duration(milliseconds: 600), () => removeFromParent());
    } else {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!_spriteLoaded) renderPlaceholder(canvas, const Color(0xFF8B8B6B));
  }
}
