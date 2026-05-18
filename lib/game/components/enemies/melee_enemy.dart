import '../../config.dart';
import '../enemy.dart';
import '../player.dart';

// ---------------------------------------------------------------------------
// MeleeEnemy — abstract base for all sword/contact melee fighters.
//
// AI state machine:
//   patrol ──(player enters aggroRange)──► chase ──(within attackRange)──► attack
//       ▲                                                                    │
//       └────────────────────────────────────────────────────────────────────┘
//
// Jumping: when chasing and onWallHit() fires, the enemy jumps once.
// ---------------------------------------------------------------------------
enum MeleeState { patrol, chase, attack }

abstract class MeleeEnemy extends BaseEnemy {
  final double patrolRange;
  final double speed;
  final double aggroRange;
  final double attackRange;
  final double attackCooldown;

  MeleeState _state = MeleeState.patrol;
  bool _isMovingThisFrame = false;
  late double _patrolOriginX;

  double _attackCooldownTimer = 0;
  double _jumpCooldownTimer = 0;

  // Delayed damage to sync with active attack animation frames
  double _damageDelayTimer = 0;
  double _attackAnimTimer = 0;
  Player? _swingTarget;
  final double damageDelay;
  final double maxVerticalDiff;
  final double attackAnimDuration;

  MeleeEnemy({
    required super.position,
    required super.size,
    super.maxHealth,
    super.contactDamage,
    this.patrolRange = 100.0,
    this.speed = 70.0,
    this.aggroRange = GameConfig.enemyAggroRange,
    this.attackRange = GameConfig.enemyAttackRange,
    this.attackCooldown = GameConfig.enemyMeleeAttackCooldown,
    this.damageDelay = 0.25,
    this.maxVerticalDiff = GameConfig.enemyAttackMaxVerticalDiff,
    this.attackAnimDuration = 0.56,
  });

  @override
  Future<void> onLoad() async {
    _patrolOriginX = position.x;
    await super.onLoad();
  }

  @override
  void update(double dt) {
    final prevX = position.x;

    if (game.isCutscenePlaying) {
      super.update(dt);
      _isMovingThisFrame = false;
      return;
    }
    if (isDead) {
      super.update(dt);
      return;
    }
    if (_attackCooldownTimer > 0) _attackCooldownTimer -= dt;
    if (_jumpCooldownTimer > 0) _jumpCooldownTimer -= dt;
    if (_attackAnimTimer > 0) _attackAnimTimer -= dt;

    if (_damageDelayTimer > 0) {
      _damageDelayTimer -= dt;
      if (_damageDelayTimer <= 0) {
        _applyDelayedDamage();
      }
    }

    // Freeze AI and movement during hurt stun!
    if (hurtTimer <= 0) {
      _runAI(dt);
    }

    super.update(dt);

    // Physical movement check
    _isMovingThisFrame = (position.x - prevX).abs() > 0.01;
  }

  void _runAI(double dt) {
    final player = _player();
    if (player == null) {
      _patrol(dt);
      return;
    }

    final playerCenter = player.position.x + player.size.x / 2;
    final enemyCenter = position.x + size.x / 2;

    final dx = (playerCenter - enemyCenter).abs();
    // Compare foot-level vertical heights to support different hitbox heights (e.g. Skeleton 72px vs Player 48px)
    final dy = ((player.position.y + player.size.y) - (position.y + size.y))
        .abs();

    if (dx < aggroRange && dy < 180) {
      // Face the player when alert (lock direction during the active attack animation to prevent visual jitter,
      // and use an 8px center deadzone to prevent rapid oscillation)
      if (_attackAnimTimer <= 0 && !isAttackingState) {
        final xDiff = playerCenter - enemyCenter;
        if (xDiff.abs() > 8.0) {
          facingDirection = xDiff > 0 ? 1 : -1;
        }
      }

      if (dx < attackRange && dy < maxVerticalDiff) {
        _state = MeleeState.attack;
        _trySwing(player);
      } else {
        // Do not chase/move while locked in the middle of an attack swing!
        if (_attackAnimTimer <= 0 && !isAttackingState) {
          _state = MeleeState.chase;
          _chasePlayer(player, dt);
        } else {
          _state = MeleeState.attack;
        }
      }
    } else {
      _state = MeleeState.patrol;
      _patrol(dt);
    }
  }

  void _patrol(double dt) {
    if (patrolRange == 0) return;
    final step = speed * facingDirection * dt;
    if (isOnGround && wouldFall(step)) {
      // If we would fall in the opposite direction too, we are trapped on a tiny ledge.
      // Stand still and do not flip repeatedly.
      if (wouldFall(-step)) {
        return;
      }
      facingDirection *= -1;
      return;
    }
    position.x += step;
    if (position.x > _patrolOriginX + patrolRange) facingDirection = -1;
    if (position.x < _patrolOriginX - patrolRange) facingDirection = 1;
  }

  void _chasePlayer(Player player, double dt) {
    final playerCenter = player.position.x + player.size.x / 2;
    final enemyCenter = position.x + size.x / 2;
    final xDiff = playerCenter - enemyCenter;
    final wantsToMove = xDiff.abs() > 8.0;

    if (wantsToMove) {
      final dir = xDiff > 0 ? 1 : -1;
      facingDirection = dir;
      // Give a horizontal speed boost in the air so they can clear gaps like the 3-tile wide pit
      final speedMultiplier = isOnGround ? 1.5 : 2.5;
      final step = speed * speedMultiplier * dir * dt;
      if (!isOnGround || !wouldFall(step)) {
        position.x += step;
      }
    }

    // Smart jump to chase player up platforms and ledges
    final playerAbove = player.position.y < position.y - 24.0;
    // Only pursue vertically if the player is supported by solid ground (not mid-air)
    final playerOnHigherPlatform = playerAbove && player.isOnGround;

    if (isOnGround && _jumpCooldownTimer <= 0) {
      // 1. Directly below the player (horizontally close)
      final closeHorizontally = (player.position.x - position.x).abs() < 48.0;
      // 2. Or, trying to chase but blocked horizontally (not moving)
      final blocked = wantsToMove && !_isMovingThisFrame;

      // Do not jump if we are at a ledge/pit (jumping forward would plunge us into the void)
      final atLedge = wouldFall(facingDirection * 12.0);

      if (playerOnHigherPlatform &&
          (closeHorizontally || blocked) &&
          !atLedge) {
        jump();
        _jumpCooldownTimer = 3.0; // Cooldown of 3.0s
      }
    }
  }

  void _trySwing(Player player) {
    if (_attackCooldownTimer > 0) return;
    _attackCooldownTimer = attackCooldown;
    onMeleeSwing(player);

    // Set damage delay timer and full visual attack duration timer
    _damageDelayTimer = damageDelay;
    _attackAnimTimer = attackAnimDuration;
    _swingTarget = player;
  }

  /// Override to customise attack animation tells.
  /// The actual damage impact is resolved dynamically with a delay.
  void onMeleeSwing(Player player) {}

  void _applyDelayedDamage() {
    final player = _swingTarget;
    if (player == null || isDead || player.isDead) return;

    final playerCenter = player.position.x + player.size.x / 2;
    final enemyCenter = position.x + size.x / 2;

    // Check distance using center-to-center logic to solve hitbox size discrepancies
    final dx = (playerCenter - enemyCenter).abs();
    // Compare foot-level vertical heights to support different hitbox heights (e.g. Skeleton 72px vs Player 48px)
    final dy = ((player.position.y + player.size.y) - (position.y + size.y))
        .abs();

    // Ensure the attack only hits targets in front of the enemy,
    // or if they are standing extremely close/inside the enemy's center (dx < 8.0).
    // If the player is clearly behind the enemy, they must not be hit!
    final isBehind = (playerCenter - enemyCenter) * facingDirection < 0.0;
    final isPlayerInFront = !isBehind || dx < 8.0;

    if (dx <= attackRange + GameConfig.enemyAttackReachPadding &&
        dy <= maxVerticalDiff &&
        isPlayerInFront) {
      // Line of sight check to avoid hitting player through solid walls
      final myCenter = position + size / 2;
      final playerCenterPos = player.position + player.size / 2;
      if (game.hasLineOfSight(myCenter, playerCenterPos)) {
        if (!player.isInvincible) {
          player.receiveDamage(contactDamage);
        } else {
          // Reward perfect dodge if invincible during the actual hit frame!
          game.playerState.perfectDodges++;
          game.playerState.addResolve(5);
        }
      }
    }
    _swingTarget = null;
  }

  @override
  void interruptAttack() {
    _damageDelayTimer = 0.0;
    _attackAnimTimer = 0.0;
    _swingTarget = null;
  }

  /// On wall-hit while chasing, attempt a jump. Otherwise reverse direction.
  @override
  void onWallHit() {
    if (_state == MeleeState.chase || _state == MeleeState.attack) {
      // Use velocityY check instead of isOnGround because collision resolution order can flaky-reset isOnGround.
      // If the enemy is vertically stationary, they are standing on solid ground and can safely jump.
      if (velocityY.abs() < 1.0 && _jumpCooldownTimer <= 0) {
        velocityY = GameConfig.playerJumpForce * 0.85;
        isOnGround = false;
        _jumpCooldownTimer = 1.2;
      }
      // Do NOT flip direction when chasing or attacking the player and hitting a wall!
      // We should continue facing our active target.
    } else {
      facingDirection *= -1;
    }
  }

  bool get isStationary {
    return !_isMovingThisFrame;
  }

  Player? _player() {
    // Enemies and player share the same parent (World).
    return parent?.children.whereType<Player>().firstOrNull;
  }

  MeleeState get currentState => _state;
}
