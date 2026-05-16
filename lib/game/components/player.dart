import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart' hide Block;
import 'package:flutter/services.dart';
import '../asset_registry.dart';

import '../components/block.dart';
import '../components/lava.dart';
import '../components/spike.dart';
import '../components/health_pickup.dart';
import '../components/ore_pickup.dart';
import '../components/exit_portal.dart';
import '../components/enemy.dart';
import '../struggler_game.dart';

enum PlayerAnimationState {
  idle,
  run,
  jump,
  attack,
  dodge,
  hurt,
  death,
}

/// The Struggler — the player character.
class Player extends PositionComponent with CollisionCallbacks, KeyboardHandler, HasGameReference<StruggleGame> {
  SpriteAnimationGroupComponent<PlayerAnimationState>? _animationComponent;
  // --- Movement ---
  static const double moveSpeed = 200.0;
  static const double jumpForce = -400.0;
  static const double gravity = 900.0;
  static const double maxFallSpeed = 600.0;

  Vector2 velocity = Vector2.zero();
  bool isOnGround = false;
  int _facingDirection = 1; // 1 = right, -1 = left
  
  // --- Jump State ---
  int _jumpsRemaining = 2;
  static const int _maxJumps = 2;
  double _jumpBufferTimer = 0;
  static const double _jumpBufferDuration = 0.15;
  double _coyoteTimer = 0;
  static const double _coyoteDuration = 0.1;

  // --- Input state (set by the game/controls) ---
  bool moveLeft = false;
  bool moveRight = false;
  bool jumpPressed = false;
  bool attackPressed = false;
  bool dodgePressed = false;

  // --- Combat ---
  bool _isAttacking = false;
  double _attackTimer = 0;
  static const double attackDuration = 0.28;
  static const double attackCooldown = 0.35;
  double _attackCooldownTimer = 0;

  // --- Dodge ---
  bool _isDodging = false;
  double _dodgeTimer = 0;
  static const double dodgeDuration = 0.2;
  static const double dodgeSpeed = 450.0;
  static const double dodgeCooldown = 0.5;
  double _dodgeCooldownTimer = 0;
  bool get isInvincible => _isDodging;

  // --- Hit-stop ---
  double _hitStopTimer = 0;
  static const double hitStopDuration = 0.05;

  // --- Hurt flash ---
  double _hurtTimer = 0;
  
  // --- Death state ---
  bool _isDead = false;
  double _respawnTimer = 0;
  static const double respawnDelay = 1.5;

  // --- Resolve visual ---
  bool get isIndomitable => game.playerState.isIndomitable;

  Player({required Vector2 position})
      : super(
          position: position,
          size: Vector2(28, 40),
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    add(RectangleHitbox());

    try {
      final idleAnim = await _loadAnimation('Idle.png', 8, 2);
      final runAnim = await _loadAnimation('Run.png', 8, 2);
      final jumpAnim = await _loadAnimation('Jump.png', 8, 2);
      final attackAnim = await _loadAnimation('Attacks.png', 8, 8, stepTime: 0.035, loop: false);
      final dodgeAnim = await _loadAnimation('Roll.png', 4, 2, stepTime: 0.05, loop: false);
      final hurtAnim = await _loadAnimation('Hurt.png', 3, 2, stepTime: 0.1, loop: false);
      final deathAnim = await _loadAnimation('Death.png', 4, 2, stepTime: 0.1, loop: false);

      _animationComponent = SpriteAnimationGroupComponent<PlayerAnimationState>(
        animations: {
          PlayerAnimationState.idle: idleAnim,
          PlayerAnimationState.run: runAnim,
          PlayerAnimationState.jump: jumpAnim,
          PlayerAnimationState.attack: attackAnim,
          PlayerAnimationState.dodge: dodgeAnim,
          PlayerAnimationState.hurt: hurtAnim,
          PlayerAnimationState.death: deathAnim,
        },
        current: PlayerAnimationState.idle,
        size: Vector2(128, 64),
        position: Vector2(size.x / 2, size.y),
        anchor: Anchor.bottomCenter,
      );

      add(_animationComponent!);
    } catch (e) {
      // Asset loading failed, fallback to hitbox
    }
  }

  Future<SpriteAnimation> _loadAnimation(
    String filename,
    int amount,
    int amountPerRow, {
    double stepTime = 0.1,
    bool loop = true,
  }) async {
    return AssetRegistry.getAnimationFromAtlas(
      game,
      'assets/images/atlas/spritesheet.json',
      'atlas/spritesheet.png',
      filename,
      amount: amount,
      amountPerRow: amountPerRow,
      stepTime: stepTime,
      textureSize: Vector2(128, 64),
      loop: loop,
      key: 'characters/player/$filename',
    );
  }

  @override
  void update(double dt) {
    // Hit-stop: freeze everything during hit-stop
    if (_hitStopTimer > 0) {
      _hitStopTimer -= dt;
      return;
    }

    if (_isDead) {
      _respawnTimer -= dt;
      if (_respawnTimer <= 0) {
        game.onPlayerDeath();
      }
      _updateAnimation();
      _applyGravity(dt);
      _applyVelocity(dt);
      return;
    }

    super.update(dt);

    _updateTimers(dt);
    _handleAttack(dt);
    _handleDodge(dt);
    _handleMovement(dt);
    _applyGravity(dt);
    _applyVelocity(dt);
    _updateAnimation();

    isOnGround = false; // Assume we are in air until collision confirms otherwise
  }

  void _updateAnimation() {
    final anim = _animationComponent;
    if (anim == null) return;

    // Handle flipping based on direction
    if (!_isDead) {
      if (_facingDirection == 1 && anim.scale.x < 0) {
        anim.scale.x *= -1;
      } else if (_facingDirection == -1 && anim.scale.x > 0) {
        anim.scale.x *= -1;
      }
    }

    // Determine current animation state
    if (_isDead) {
      anim.current = PlayerAnimationState.death;
    } else if (_hurtTimer > 0) {
      anim.current = PlayerAnimationState.hurt;
    } else if (_isDodging) {
      anim.current = PlayerAnimationState.dodge;
    } else if (_isAttacking) {
      anim.current = PlayerAnimationState.attack;
    } else if (!isOnGround) {
      anim.current = PlayerAnimationState.jump;
    } else if (velocity.x != 0) {
      anim.current = PlayerAnimationState.run;
    } else {
      anim.current = PlayerAnimationState.idle;
    }
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (_isDead) return false;

    moveLeft = keysPressed.contains(LogicalKeyboardKey.keyA);
    moveRight = keysPressed.contains(LogicalKeyboardKey.keyD);
    
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyW) {
        jumpPressed = true;
      }
      if (event.logicalKey == LogicalKeyboardKey.space) {
        dodgePressed = true;
      }
    }
    
    return true;
  }

  void _updateTimers(double dt) {
    if (_attackCooldownTimer > 0) _attackCooldownTimer -= dt;
    if (_dodgeCooldownTimer > 0) _dodgeCooldownTimer -= dt;
    if (_hurtTimer > 0) _hurtTimer -= dt;
    
    // Coyote time
    if (isOnGround) {
      _coyoteTimer = _coyoteDuration;
    } else if (_coyoteTimer > 0) {
      _coyoteTimer -= dt;
    }

    // Jump buffer
    if (jumpPressed) {
      _jumpBufferTimer = _jumpBufferDuration;
      jumpPressed = false;
    } else if (_jumpBufferTimer > 0) {
      _jumpBufferTimer -= dt;
    }
  }

  void _handleMovement(double dt) {
    if (_isDodging) return; // No manual movement during dodge

    // Horizontal movement
    if (_isAttacking) {
      velocity.x = 0;
    } else {
      if (moveLeft) {
        velocity.x = -moveSpeed;
        _facingDirection = -1;
      } else if (moveRight) {
        velocity.x = moveSpeed;
        _facingDirection = 1;
      } else {
        velocity.x = 0;
      }
    }

    // Jump logic
    if (_jumpBufferTimer > 0) {
      if (_coyoteTimer > 0) {
        // Normal jump or coyote jump
        velocity.y = jumpForce;
        isOnGround = false;
        _coyoteTimer = 0;
        _jumpBufferTimer = 0;
        _jumpsRemaining = _maxJumps - 1;
      } else if (_jumpsRemaining > 0) {
        // Air jump (double jump)
        velocity.y = jumpForce;
        _jumpsRemaining--;
        _jumpBufferTimer = 0;
      }
    }
  }


  void _handleAttack(double dt) {
    if (_isAttacking) {
      _attackTimer -= dt;
      if (_attackTimer <= 0) {
        _isAttacking = false;
        _attackCooldownTimer = attackCooldown;
      }
    }

    if (attackPressed && !_isAttacking && _attackCooldownTimer <= 0 && !_isDodging && isOnGround) {
      _isAttacking = true;
      _attackTimer = attackDuration;
      attackPressed = false;
      _performAttack();
    }
  }

  void _performAttack() {
    // Create a temporary attack hitbox in front of the player
    final attackOffset = _facingDirection == 1 ? size.x : -30.0;
    final attackArea = Rect.fromLTWH(
      position.x + attackOffset,
      position.y + 5,
      30,
      size.y - 10,
    );

    // Check all enemies in the game world
    final enemies = parent?.children.whereType<Enemy>() ?? [];
    for (final enemy in enemies) {
      final enemyRect = enemy.toRect();
      if (attackArea.overlaps(enemyRect)) {
        final damage = game.playerState.effectiveDamage;
        final killed = enemy.takeDamage(damage);
        _hitStopTimer = hitStopDuration; // Hit-stop for impact feel
        game.onScreenShake(3.0); // Screen shake

        if (killed) {
          game.playerState.enemiesKilled++;
          // Gain resolve on kill
          game.playerState.addResolve(15);
        }
      }
    }
  }

  void _handleDodge(double dt) {
    if (_isDodging) {
      _dodgeTimer -= dt;
      velocity.x = dodgeSpeed * _facingDirection;
      if (_dodgeTimer <= 0) {
        _isDodging = false;
        _dodgeCooldownTimer = dodgeCooldown;
      }
      return;
    }

    if (dodgePressed && !_isDodging && _dodgeCooldownTimer <= 0 && !_isAttacking) {
      _isDodging = true;
      _dodgeTimer = dodgeDuration;
      dodgePressed = false;
    }
  }

  void _applyGravity(double dt) {
    if (!isOnGround) {
      velocity.y += gravity * dt;
      velocity.y = velocity.y.clamp(-1000, maxFallSpeed);
    }
  }

  void _applyVelocity(double dt) {
    position += velocity * dt;

    // Fall into void = death
    if (position.y > 4000) {
      _die();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);

    if (other is PlatformBlock) {
      _resolveBlockCollision(other);
    } else if (other is Lava) {
      _onHazardContact(other.damage);
    } else if (other is Spike) {
      _onHazardContact(other.damage);
    } else if (other is HealthPickup && !other.collected) {
      other.collected = true;
      other.removeFromParent();
      game.playerState.heal(other.healAmount);
    } else if (other is OrePickup && !other.collected) {
      other.collected = true;
      other.removeFromParent();
      game.playerState.oreCollected++;
    } else if (other is ExitPortal) {
      game.onLevelComplete();
    } else if (other is Enemy) {
      if (!isInvincible) {
        _onHazardContact(other.contactDamage);
      } else {
        // Perfect dodge — gain extra resolve!
        game.playerState.perfectDodges++;
        game.playerState.addResolve(25);
      }
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is PlatformBlock) {
      _resolveBlockCollision(other);
    }

    if (other is Lava) {
        _onHazardContact(other.damage);
    }
  }

  void _resolveBlockCollision(PlatformBlock block) {
    final playerRect = toRect();
    final blockRect = block.toRect();

    // Calculate overlap on each side
    final overlapLeft = playerRect.right - blockRect.left;
    final overlapRight = blockRect.right - playerRect.left;
    final overlapTop = playerRect.bottom - blockRect.top;
    final overlapBottom = blockRect.bottom - playerRect.top;

    // Find minimum overlap to determine collision direction
    final minOverlap = [overlapLeft, overlapRight, overlapTop, overlapBottom]
        .reduce((a, b) => a < b ? a : b);

    if (minOverlap == overlapTop && velocity.y >= 0) {
      // Landing on top
      position.y = block.position.y - size.y;
      velocity.y = 0;
      isOnGround = true;
      _jumpsRemaining = _maxJumps;
    } else if (minOverlap == overlapBottom && velocity.y < 0) {
      // Hitting head on bottom
      position.y = block.position.y + block.size.y;
      velocity.y = 0;
    } else if (minOverlap == overlapLeft) {
      // Hitting right side
      position.x = block.position.x - size.x;
      velocity.x = 0;
    } else if (minOverlap == overlapRight) {
      // Hitting left side
      position.x = block.position.x + block.size.x;
      velocity.x = 0;
    }
  }

  void _onHazardContact(double damage) {
    if (isInvincible) return;

    final died = game.playerState.takeDamage(damage);
    _hurtTimer = 0.3;
    game.onScreenShake(5.0);

    if (died) {
      _die();
    }
  }

  void _die() {
    if (_isDead) return;
    
    _isDead = true;
    _respawnTimer = respawnDelay;
    velocity.x = 0; // Stop horizontal movement on death
    
    game.playerState.deathCount++;
  }

  /// Activate the Indomitable state (called when resolve is full).
  void activateIndomitable() {
    game.playerState.isIndomitable = true;
    game.playerState.resolve = game.playerState.maxResolve;
  }

  /// Deactivate the Indomitable state.
  void deactivateIndomitable() {
    game.playerState.isIndomitable = false;
    game.playerState.resolve = 0;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Indomitable glow aura
    if (isIndomitable) {
      canvas.drawRect(
        Rect.fromLTWH(-4, -4, size.x + 8, size.y + 8),
        Paint()
          ..color = const Color(0x44FF0000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
  }
}
