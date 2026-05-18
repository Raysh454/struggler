import 'dart:ui';
import 'package:flame/components.dart';

import '../../config.dart';
import '../enemy.dart';
import '../player.dart';
import '../projectile.dart';

// ---------------------------------------------------------------------------
// RangedEnemy — abstract base for Archer and Wizard.
//
// AI: 
//   idle → face player → fire projectile every [fireCooldown] seconds
//   If player closes in within [backoffDist], move away.
//   Jumps when hitting a wall while backing off.
// ---------------------------------------------------------------------------
abstract class RangedEnemy extends BaseEnemy {
  final double speed;
  final double aggroRange;
  final double backoffDist;
  final double fireCooldown;

  double _fireTimer = 0;
  double _jumpCooldown = 0;
  bool _inAggro = false;
  bool get inAggro => _inAggro;

  bool _isMoving = false;
  bool get isMoving => _isMoving;

  RangedEnemy({
    required super.position,
    required super.size,
    super.maxHealth,
    super.contactDamage,
    this.speed       = 60,
    this.aggroRange  = GameConfig.enemyAggroRange,
    this.backoffDist = GameConfig.enemyRangedBackoffDist,
    this.fireCooldown = GameConfig.enemyRangedFireCooldown,
  });

  @override
  void update(double dt) {
    if (game.isCutscenePlaying) {
      super.update(dt);
      _isMoving = false;
      return;
    }
    if (isDead) {
      super.update(dt);
      return;
    }
    if (_fireTimer  > 0) _fireTimer  -= dt;
    if (_jumpCooldown > 0) _jumpCooldown -= dt;
    
    // Freeze AI during hurt stun!
    if (hurtTimer <= 0) {
      _runRangedAI(dt);
    }
    
    super.update(dt);
  }

  void _runRangedAI(double dt) {
    final player = _player();
    if (player == null) {
      _isMoving = false;
      return;
    }

    final dx = player.position.x - position.x;
    final adx = dx.abs();
    final ady = (player.position.y - position.y).abs();

    if (adx > aggroRange || ady > 400) {
      _inAggro = false;
      _isMoving = false;
      return;
    }
    _inAggro = true;
    facingDirection = dx > 0 ? 1 : -1;

    // Smooth movement with hysteresis (deadzone) to prevent back-and-forth jittering
    const double deadzone = 20.0;
    if (adx < backoffDist - deadzone) {
      // Retreat!
      final step = -facingDirection * speed * dt;
      if (!wouldFall(step)) {
        position.x += step;
        _isMoving = true;
      } else {
        _isMoving = false;
      }
    } else if (adx > backoffDist + deadzone) {
      // Chase!
      final step = facingDirection * speed * dt;
      if (!wouldFall(step)) {
        position.x += step;
        _isMoving = true;
      } else {
        _isMoving = false;
      }
    } else {
      // Maintain distance and hold ground
      _isMoving = false;
    }

    // Smart jump to chase player up platforms and ledges
    final playerAbove = player.position.y < position.y - 24.0;
    // Only pursue vertically if the player is supported by solid ground (not mid-air)
    final playerOnHigherPlatform = playerAbove && player.isOnGround;

    if (isOnGround && _jumpCooldown <= 0) {
      // 1. Directly below the player (horizontally close)
      final closeHorizontally = (player.position.x - position.x).abs() < 48.0;
      // 2. Or, trying to chase/flee but blocked horizontally (not moving)
      final wantsToMove = adx < backoffDist - deadzone || adx > backoffDist + deadzone;
      final blocked = wantsToMove && !_isMoving;
      
      // Do not jump if we are at a ledge/pit (jumping forward would plunge us into the void)
      final atLedge = wouldFall(facingDirection * 12.0);
      
      if (playerOnHigherPlatform && (closeHorizontally || blocked) && !atLedge) {
        jump();
        _jumpCooldown = 3.0; // Cooldown of 3.0s
      }
    }

    // Fire
    if (_fireTimer <= 0) {
      _fireTimer = fireCooldown;
      fireProjectile(player);
    }
  }

  /// Subclasses spawn the correct projectile type here.
  void fireProjectile(Player player);

  @override
  void onWallHit() {
    if (_inAggro && isOnGround && _jumpCooldown <= 0) {
      velocityY = GameConfig.playerJumpForce * 0.8;
      isOnGround = false;
      _jumpCooldown = 1.5;
    } else {
      facingDirection *= -1;
    }
  }

  Player? _player() =>
      parent?.children.whereType<Player>().firstOrNull;
}

// ---------------------------------------------------------------------------
// ArcaneArcherEnemy
// ---------------------------------------------------------------------------
enum _ArcherAnim { idle, run, attack, death }

class ArcaneArcherEnemy extends RangedEnemy {
  SpriteAnimationGroupComponent<_ArcherAnim>? _animGroup;
  _ArcherAnim _current = _ArcherAnim.idle;
  bool _spriteLoaded = false;
  bool _arrowFired = false;

  ArcaneArcherEnemy({
    required super.position,
  }) : super(
          size: GameConfig.enemyHitboxArcher,
          maxHealth: GameConfig.enemyHealthArcher,
          contactDamage: GameConfig.enemyDamageArcher,
          speed: GameConfig.enemySpeedArcher,
          aggroRange: GameConfig.enemyAggroRangeArcher,
          fireCooldown: GameConfig.enemyRangedFireCooldown,
        );

  @override
  int get willpowerReward => GameConfig.enemyWillArcher;

  @override
  double get resolveReward => GameConfig.enemyResolveArcher;

  @override
  double get healthBarYOffset => GameConfig.enemyHealthBarYOffsetArcher;

  // Archer sheet: 512×512, 64×64 frames
  static final Vector2 _frame = Vector2(64, 64);
  static final Vector2 _renderSize = GameConfig.enemySizeArcher;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final image = await game.images.load('characters/archer/spritesheet.png');

      // Row 6 (idx 5) = Idle/Ready — 4 frames
      final idle = SpriteAnimation.spriteList(
        List.generate(4, (i) => Sprite(image, srcPosition: Vector2(i * 64.0, 5 * 64.0), srcSize: _frame)),
        stepTime: 0.18,
      );
      // Row 1 (idx 0) = Run — 8 frames
      final run = SpriteAnimation.spriteList(
        List.generate(8, (i) => Sprite(image, srcPosition: Vector2(i * 64.0, 0), srcSize: _frame)),
        stepTime: 0.10,
      );
      // Row 4 (idx 3) = Horizontal Bow Attack — 7 frames
      final attack = SpriteAnimation.spriteList(
        List.generate(7, (i) => Sprite(image, srcPosition: Vector2(i * 64.0, 3 * 64.0), srcSize: _frame)),
        stepTime: 0.08, loop: false,
      );
      // Row 2 (idx 1) = Hurt/Die — first 4 frames = death
      final death = SpriteAnimation.spriteList(
        List.generate(4, (i) => Sprite(image, srcPosition: Vector2(i * 64.0, 1 * 64.0), srcSize: _frame)),
        stepTime: 0.12, loop: false,
      );

      _animGroup = SpriteAnimationGroupComponent<_ArcherAnim>(
        animations: {
          _ArcherAnim.idle:   idle,
          _ArcherAnim.run:    run,
          _ArcherAnim.attack: attack,
          _ArcherAnim.death:  death,
        },
        current: _ArcherAnim.idle,
        size: _renderSize,
        position: Vector2(size.x / 2, size.y + GameConfig.enemyYOffsetArcher),
        anchor: Anchor.bottomCenter,
      );
      add(_animGroup!);
      animComp = _animGroup;
      _spriteLoaded = true;
    } catch (_) {}
  }

  @override
  void fireProjectile(Player player) {
    if (_spriteLoaded) {
      _arrowFired = false; // Reset trigger flag for the new bow draw!
      _current = _ArcherAnim.attack;
      _animGroup!.current = _ArcherAnim.attack;
      _animGroup!.animationTickers?[_ArcherAnim.attack]?.reset();
    }
  }

  void _releaseArrow() {
    final player = _player();
    if (player == null) return;

    final spawnPos = Vector2(
      position.x + (facingDirection == 1 ? size.x : -20),
      position.y + size.y * 0.3,
    );

    final playerCenter = player.position + player.size / 2;
    final targetVector = (playerCenter - spawnPos).normalized();

    parent?.add(ArrowProjectile(
      position: spawnPos,
      direction: facingDirection,
      targetVector: targetVector,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_spriteLoaded || isDead) return;

    final ticker = _animGroup!.animationTickers?[_ArcherAnim.attack];
    if (_current == _ArcherAnim.attack && ticker != null) {
      // Release arrow at the peak pullback frame (index 4 of the 7-frame animation)
      if (ticker.currentIndex >= 4 && !_arrowFired) {
        _releaseArrow();
        _arrowFired = true;
      }
      if (ticker.done()) {
        _current = _ArcherAnim.idle;
        _animGroup!.current = _ArcherAnim.idle;
      }
    }

    if (_current != _ArcherAnim.attack) {
      final newAnim = isMoving ? _ArcherAnim.run : _ArcherAnim.idle;
      if (newAnim != _current) {
        _current = newAnim;
        _animGroup!.current = _current;
        _animGroup!.animationTickers?[_current]?.reset();
      }
    }
  }

  @override
  void interruptAttack() {
    _current = _ArcherAnim.idle;
    if (_animGroup != null) {
      _animGroup!.current = _ArcherAnim.idle;
    }
    _arrowFired = true; // Prevent arrow release!
  }

  @override
  bool takeDamage(double damage, {bool isPlunge = false}) {
    if (isDead) return false;
    final fatal = super.takeDamage(damage, isPlunge: isPlunge);
    if (!fatal) {
      hurtTimer = GameConfig.enemyArcherHurtDuration;

      final player = playerTarget;
      if (player != null) {
        final pushDir = (position.x + size.x / 2) > (player.position.x + player.size.x / 2) ? 1.0 : -1.0;
        stagger(pushDir * GameConfig.enemyArcherStaggerForce);
      }
    }
    return fatal;
  }

  @override
  void onDeath() {
    if (_spriteLoaded) {
      _animGroup!.current = _ArcherAnim.death;
      Future.delayed(const Duration(milliseconds: 500), () => removeFromParent());
    } else {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!_spriteLoaded) renderPlaceholder(canvas, const Color(0xFF2E8B57));
  }
}
