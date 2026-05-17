import 'dart:ui';
import 'dart:math';
import 'package:flame/components.dart';

import '../../asset_registry.dart';
import '../../config.dart';
import '../player.dart';
import 'melee_enemy.dart';

enum _GAnim { idle, run, attack, hurt, death }

/// Fast, erratic melee mob. Randomly reverses direction mid-patrol.
class GoblinEnemy extends MeleeEnemy {
  SpriteAnimationGroupComponent<_GAnim>? _animGroup;
  _GAnim _current = _GAnim.idle;
  bool _spriteLoaded = false;
  final Random _rng = Random();
  double _erraticTimer = 0;

  GoblinEnemy({
    required super.position,
  }) : super(
          size: GameConfig.enemyHitboxGoblin,
          maxHealth: GameConfig.enemyHealthGoblin,
          contactDamage: GameConfig.enemyDamageGoblin,
          speed: GameConfig.enemySpeedGoblin,
          patrolRange: 90,
          attackCooldown: 0.9,
          damageDelay: 0.35,
          attackRange: GameConfig.enemyAttackRangeGoblin,
          maxVerticalDiff: GameConfig.enemyAttackMaxVerticalDiffGoblin,
          attackAnimDuration: 0.56,
        );

  @override
  int get willpowerReward => GameConfig.enemyWillGoblin;

  @override
  double get resolveReward => GameConfig.enemyResolveGoblin;

  static final Vector2 _frame = Vector2(150, 150);
  static final Vector2 _renderSize = GameConfig.enemySizeGoblin;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final idle   = await AssetRegistry.getAnimation(game, 'characters/goblin/Idle.png',
          SpriteAnimationData.sequenced(amount: 4, stepTime: 0.16, textureSize: _frame), key: 'gob/idle');
      final run    = await AssetRegistry.getAnimation(game, 'characters/goblin/Run.png',
          SpriteAnimationData.sequenced(amount: 8, stepTime: 0.09, textureSize: _frame), key: 'gob/run');
      final attack = await AssetRegistry.getAnimation(game, 'characters/goblin/Attack.png',
          SpriteAnimationData.sequenced(amount: 8, stepTime: 0.07, textureSize: _frame, loop: false), key: 'gob/atk');
      final hurt   = await AssetRegistry.getAnimation(game, 'characters/goblin/Hurt.png',
          SpriteAnimationData.sequenced(amount: 4, stepTime: 0.12, textureSize: _frame, loop: false), key: 'gob/hurt');
      final death  = await AssetRegistry.getAnimation(game, 'characters/goblin/Death.png',
          SpriteAnimationData.sequenced(amount: 4, stepTime: 0.13, textureSize: _frame, loop: false), key: 'gob/death');

      _animGroup = SpriteAnimationGroupComponent<_GAnim>(
        animations: {
          _GAnim.idle: idle,
          _GAnim.run: run,
          _GAnim.attack: attack,
          _GAnim.hurt: hurt,
          _GAnim.death: death,
        },
        current: _GAnim.idle,
        size: _renderSize,
        position: Vector2(size.x / 2, size.y + GameConfig.enemyYOffsetGoblin),
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
      _current = _GAnim.attack;
      _animGroup!.current = _GAnim.attack;
      _animGroup!.animationTickers?[_GAnim.attack]?.reset();
    }
  }

  @override
  bool takeDamage(double damage) {
    if (isDead) return false;
    final fatal = super.takeDamage(damage);
    if (!fatal && _spriteLoaded && _animGroup != null) {
      if (!isAttackingState) {
        _current = _GAnim.hurt;
        _animGroup!.current = _GAnim.hurt;
        _animGroup!.animationTickers?[_GAnim.hurt]?.reset();
      }

      hurtTimer = GameConfig.enemyGoblinHurtDuration;

      final player = playerTarget;
      if (player != null) {
        final pushDir = (position.x + size.x / 2) > (player.position.x + player.size.x / 2) ? 1.0 : -1.0;
        stagger(pushDir * GameConfig.enemyGoblinStaggerForce);
      }
    }
    return fatal;
  }

  @override
  bool get isAttackingState => _current == _GAnim.attack;

  @override
  void update(double dt) {
    super.update(dt);
    if (!_spriteLoaded) return;

    if (isDead) {
      final deathTicker = _animGroup!.animationTickers?[_GAnim.death];
      if (deathTicker != null && deathTicker.done()) {
        removeFromParent();
      }
      return;
    }

    // Erratic direction flip every 2–4 s during patrol
    if (currentState == MeleeState.patrol) {
      _erraticTimer -= dt;
      if (_erraticTimer <= 0) {
        if (_rng.nextDouble() < 0.4) facingDirection *= -1;
        _erraticTimer = 2.0 + _rng.nextDouble() * 2.0;
      }
    }

    // Hurt animation state lock: guarantee that the 4-frame hurt animation plays to completion
    final hurtTicker = _animGroup!.animationTickers?[_GAnim.hurt];
    if (_current == _GAnim.hurt && hurtTicker != null && hurtTicker.done()) {
      _current = _GAnim.idle;
      _animGroup!.current = _GAnim.idle;
    }

    final ticker = _animGroup!.animationTickers?[_GAnim.attack];
    if (_current == _GAnim.attack && ticker != null && ticker.done()) {
      _current = _GAnim.idle;
      _animGroup!.current = _GAnim.idle;
    }

    if (_current != _GAnim.attack && _current != _GAnim.hurt) {
      final newAnim = switch (currentState) {
        MeleeState.patrol => _GAnim.run,
        MeleeState.chase  => isStationary ? _GAnim.idle : _GAnim.run,
        MeleeState.attack => _GAnim.idle,
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
      _current = _GAnim.death;
      _animGroup!.current = _GAnim.death;
      _animGroup!.animationTickers?[_GAnim.death]?.reset();
    } else {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!_spriteLoaded) renderPlaceholder(canvas, const Color(0xFF3A7A3A));
  }
}
