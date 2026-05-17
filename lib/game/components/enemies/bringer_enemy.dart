import 'dart:ui';
import 'package:flame/components.dart';

import '../../asset_registry.dart';
import '../../config.dart';
import '../player.dart';
import '../projectile.dart';
import 'melee_enemy.dart';

enum _BAnim { idle, walk, attack, cast, hurt, death }

/// Strong hybrid fighter — melee sickle + periodic thunder-hand spell.
/// All animations loaded from IndividualSprite numbered PNGs.
class BringerEnemy extends MeleeEnemy {
  SpriteAnimationGroupComponent<_BAnim>? _animGroup;
  _BAnim _current = _BAnim.idle;
  bool _spriteLoaded = false;

  double _spellTimer = GameConfig.bringerSpellInterval;
  bool _casting = false;
  double _castTimer = 0;
  static const double _castDuration = 0.9; // matches 9-frame cast anim

  BringerEnemy({
    required super.position,
  }) : super(
          size: GameConfig.enemyHitboxBringer,
          maxHealth: GameConfig.enemyHealthBringer,
          contactDamage: GameConfig.enemyDamageBringer,
          speed: GameConfig.enemySpeedBringer,
          patrolRange: 80,
          attackCooldown: 1.5,
          damageDelay: 0.30,
          attackRange: GameConfig.enemyAttackRangeBringer,
          maxVerticalDiff: GameConfig.enemyAttackMaxVerticalDiffBringer,
          attackAnimDuration: 0.70,
        );

  @override
  int get willpowerReward => GameConfig.enemyWillBringer;

  @override
  double get resolveReward => GameConfig.enemyResolveBringer;

  @override
  bool get defaultSpriteFacesLeft => true;

  @override
  double get horizontalFlipOffset => GameConfig.bringerFlipOffsetX;

  static const String _pfx = 'characters/bringer/IndividualSprite/';
  static final Vector2 _renderSize = GameConfig.enemySizeBringer;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final idle   = await AssetRegistry.getAnimationFromFrameSequence(game, '${_pfx}Idle/Bringer-of-Death_Idle_',   '.png', 8,  stepTime: 0.12, key: 'bringer/idle');
      final walk   = await AssetRegistry.getAnimationFromFrameSequence(game, '${_pfx}Walk/Bringer-of-Death_Walk_',   '.png', 8,  stepTime: 0.10, key: 'bringer/walk');
      final attack = await AssetRegistry.getAnimationFromFrameSequence(game, '${_pfx}Attack/Bringer-of-Death_Attack_','.png', 10, stepTime: 0.07, loop: false, key: 'bringer/atk');
      final cast   = await AssetRegistry.getAnimationFromFrameSequence(game, '${_pfx}Cast/Bringer-of-Death_Cast_',   '.png', 9,  stepTime: 0.10, loop: false, key: 'bringer/cast');
      final hurt   = await AssetRegistry.getAnimationFromFrameSequence(game, '${_pfx}Hurt/Bringer-of-Death_Hurt_',   '.png', 3,  stepTime: 0.10, loop: false, key: 'bringer/hurt');
      final death  = await AssetRegistry.getAnimationFromFrameSequence(game, '${_pfx}Death/Bringer-of-Death_Death_', '.png', 10, stepTime: 0.10, loop: false, key: 'bringer/death');

      _animGroup = SpriteAnimationGroupComponent<_BAnim>(
        animations: {
          _BAnim.idle:   idle,
          _BAnim.walk:   walk,
          _BAnim.attack: attack,
          _BAnim.cast:   cast,
          _BAnim.hurt:   hurt,
          _BAnim.death:  death,
        },
        current: _BAnim.idle,
        size: _renderSize,
        position: Vector2(size.x / 2, size.y + GameConfig.enemyYOffsetBringer),
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
      _current = _BAnim.attack;
      _animGroup!.current = _BAnim.attack;
      _animGroup!.animationTickers?[_BAnim.attack]?.reset();
    }
  }

  @override
  bool get isAttackingState => _current == _BAnim.attack || _casting;

  @override
  bool takeDamage(double damage) {
    if (isDead) return false;
    final fatal = super.takeDamage(damage);
    if (!fatal && _spriteLoaded && _animGroup != null) {
      if (!isAttackingState) {
        _casting = false; // Interrupted cast!
        _current = _BAnim.hurt;
        _animGroup!.current = _BAnim.hurt;
        _animGroup!.animationTickers?[_BAnim.hurt]?.reset();
      }
      
      // Set Bringer stagger duration to configured duration!
      hurtTimer = GameConfig.enemyBringerHurtDuration;

      final player = playerTarget;
      if (player != null) {
        final pushDir = (position.x + size.x / 2) > (player.position.x + player.size.x / 2) ? 1.0 : -1.0;
        stagger(pushDir * GameConfig.enemyBringerStaggerForce); // Heavy physical pushback
      }
    }
    return fatal;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isDead) return;

    if (!_spriteLoaded) return;

    // Hurt lock: keep Bringer in hurt/stagger pose and lock AI for the full 0.6s hurtTimer!
    if (_current == _BAnim.hurt) {
      if (hurtTimer > 0) {
        return; // Lock AI and hold hurt animation
      } else {
        _current = _BAnim.idle;
        _animGroup!.current = _BAnim.idle;
      }
    }

    // Spell cooldown
    _spellTimer -= dt;
    if (_spellTimer <= 0 && !_casting) {
      _startCast();
    }

    // Cast lockout
    if (_casting) {
      _castTimer -= dt;
      if (_castTimer <= 0) {
        _casting = false;
        _spellTimer = GameConfig.bringerSpellInterval;
      }
      return; // Freeze movement during cast
    }

    final ticker = _animGroup!.animationTickers?[_BAnim.attack];
    if (_current == _BAnim.attack && ticker != null && ticker.done()) {
      _current = _BAnim.idle;
      _animGroup!.current = _BAnim.idle;
    }

    if (_current != _BAnim.attack) {
      final newAnim = switch (currentState) {
        MeleeState.patrol => _BAnim.walk,
        MeleeState.chase  => isStationary ? _BAnim.idle : _BAnim.walk,
        MeleeState.attack => _BAnim.idle,
      };
      if (newAnim != _current && !_casting) {
        _current = newAnim;
        _animGroup!.current = _current;
        _animGroup!.animationTickers?[_current]?.reset();
      }
    }
  }

  void _startCast() {
    // Only cast if player is alive and within spell range!
    final p = game.player;
    if (p.isDead) return;

    final dist = (p.position - position).length;
    if (dist > GameConfig.bringerSpellRange) {
      _spellTimer = 1.0; // Retry check soon instead of waiting full cooldown
      return;
    }

    _casting   = true;
    _castTimer = _castDuration;

    if (_spriteLoaded) {
      _current = _BAnim.cast;
      _animGroup!.current = _BAnim.cast;
      _animGroup!.animationTickers?[_BAnim.cast]?.reset();
    }

    // Spawn thunder hand above player
    try {
      parent?.add(ThunderHandProjectile(
        position: Vector2(
          p.position.x + p.size.x / 2 - GameConfig.thunderHandSize.x / 2, // Centered horizontally
          p.position.y + GameConfig.thunderHandYOffset,                  // Positioned by dynamic config offset!
        ),
      ));
    } catch (_) {}
  }

  @override
  void onDeath() {
    if (_spriteLoaded) {
      _animGroup!.current = _BAnim.death;
      Future.delayed(const Duration(milliseconds: 1000), () => removeFromParent());
    } else {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!_spriteLoaded) renderPlaceholder(canvas, const Color(0xFF8B0000));

    // Show cast warning ring
    if (_casting) {
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x * 0.7,
        Paint()
          ..color = const Color(0x55FF0000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }
}
