import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart' hide Block;
import 'package:flutter/services.dart';
import '../asset_registry.dart';
import '../config.dart';
import '../components/block.dart';
import '../components/lava.dart';
import '../components/spike.dart';
import '../components/health_pickup.dart';
import '../components/diamond_pickup.dart';
import '../components/lost_will_pickup.dart';
import '../components/guardian.dart';
import '../components/guardian_portal.dart';
import '../components/exit_portal.dart';
import '../components/enemy.dart';
import '../struggler_game.dart';
import 'cat.dart';

enum PlayerAnimationState {
  idle,
  run,
  jump,
  attack,
  attack2,
  attack3,
  airAttack,
  dodge,
  hurt,
  death,
}

/// The Struggler — the player character.
class Player extends PositionComponent with CollisionCallbacks, KeyboardHandler, HasGameReference<StruggleGame> {
  SpriteAnimationGroupComponent<PlayerAnimationState>? _animationComponent;
  
  // --- Movement ---
  static const double moveSpeed = GameConfig.playerMoveSpeed;
  static const double jumpForce = GameConfig.playerJumpForce;
  static const double gravity = GameConfig.playerGravity;
  static const double maxFallSpeed = GameConfig.playerMaxFallSpeed;
  Vector2 velocity = Vector2.zero();
  bool isOnGround = false;
  Vector2? lastSafePosition;
  int _facingDirection = 1; // 1 = right, -1 = left
  int get facingDirection => _facingDirection;
  
  // --- Jump State ---
  int _jumpsRemaining = GameConfig.playerMaxJumps;
  static const int _maxJumps = GameConfig.playerMaxJumps;
  double _jumpBufferTimer = 0;
  static const double _jumpBufferDuration = GameConfig.playerJumpBufferDuration;
  double _coyoteTimer = 0;
  static const double _coyoteDuration = GameConfig.playerCoyoteDuration;

  // --- Input state (set by the game/controls) ---
  bool moveLeft = false;
  bool moveRight = false;
  bool downPressed = false;
  bool jumpPressed = false;
  double _attackBufferTimer = 0;
  bool get attackPressed => _attackBufferTimer > 0;
  set attackPressed(bool val) {
    _attackBufferTimer = val ? GameConfig.playerAttackInputBuffer : 0;
  }
  bool dodgePressed = false;
  double _ignorePlatformsTimer = 0.0;

  // --- Combat ---
  bool _isAttacking = false;
  bool _isAirAttacking = false;
  final Set<BaseEnemy> _plungeHitEnemies = {};
  int _comboStep = 0; // 0, 1, or 2
  double _comboWindowTimer = 0;
  bool _comboQueued = false;
  double _airHangTimer = 0;
  
  // --- Guardian Realm and Portals ---
  GuardianPortal? currentPortal;
  ExitPortal? currentExitPortal;
  Guardian? currentGuardian;
  double _attackTimer = 0;
  double _attackDamageDelayTimer = 0; // Delay until active swing frame to sync damage
  double _attackFreezeTimer = 0; // Locks player movement during swing, but allows early exit
  static const double attackDuration = GameConfig.playerAttackDuration;
  static const double attackCooldown = GameConfig.playerAttackCooldown;
  static const double comboWindow = GameConfig.playerComboWindow;
  double _attackCooldownTimer = 0;

  // --- Dodge ---
  bool _isDodging = false;
  double _dodgeTimer = 0;
  static const double dodgeDuration = GameConfig.playerDodgeDuration;
  static const double dodgeSpeed = GameConfig.playerDodgeSpeed;
  static const double dodgeCooldown = GameConfig.playerDodgeCooldown;
  double _dodgeCooldownTimer = 0;
  bool get isInvincible => _isDodging || _hurtTimer > 0;

  // --- Hit-stop ---
  double _hitStopTimer = 0;
  static const double hitStopDuration = GameConfig.playerHitStopDuration;

  // --- Hurt flash ---
  double _hurtTimer = 0;
  
  // --- Death state ---
  bool _isDead = false;
  bool get isDead => _isDead;
  double _respawnTimer = 0;
  static const double respawnDelay = GameConfig.playerRespawnDelay;

  // --- Resolve visual ---
  bool get isIndomitable => game.playerState.isIndomitable;

  Player({required Vector2 position})
      : super(
          position: position,
          size: GameConfig.playerSize,
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    add(RectangleHitbox());
    try {
      final idleAnim = await _loadAnimation('Idle.png', 8, 2);
      final runAnim = await _loadAnimation('Run.png', 8, 2);
      final jumpAnim = await _loadAnimation('Jump.png', 8, 2);
      
      final comboStepTime = GameConfig.playerAttackDuration / 4;
      final attackAnim = await _loadAnimation('Attacks.png', 4, 8, stepTime: comboStepTime, loop: false, startRow: 0, startCol: 0);
      final attack2Anim = await _loadAnimation('Attacks.png', 4, 8, stepTime: comboStepTime, loop: false, startRow: 0, startCol: 4);
      final attack3Anim = await _loadAnimation('Attacks.png', 4, 8, stepTime: comboStepTime, loop: false, startRow: 1, startCol: 0);
      final airAttackAnim = await _loadAnimation('attack_from_air.png', 6, 2, stepTime: 0.05, loop: false);
      final dodgeAnim = await _loadAnimation('Roll.png', 4, 2, stepTime: 0.05, loop: false);
      final hurtAnim = await _loadAnimation('Hurt.png', 3, 2, stepTime: 0.1, loop: false);
      final deathAnim = await _loadAnimation('Death.png', 4, 2, stepTime: 0.1, loop: false);

      _animationComponent = SpriteAnimationGroupComponent<PlayerAnimationState>(
        animations: {
          PlayerAnimationState.idle: idleAnim,
          PlayerAnimationState.run: runAnim,
          PlayerAnimationState.jump: jumpAnim,
          PlayerAnimationState.attack: attackAnim,
          PlayerAnimationState.attack2: attack2Anim,
          PlayerAnimationState.attack3: attack3Anim,
          PlayerAnimationState.airAttack: airAttackAnim,
          PlayerAnimationState.dodge: dodgeAnim,
          PlayerAnimationState.hurt: hurtAnim,
          PlayerAnimationState.death: deathAnim,
        },
        current: PlayerAnimationState.idle,
        size: GameConfig.playerAnimationSize,
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
    int startRow = 0,
    int startCol = 0,
  }) async {
    return AssetRegistry.getAnimationFromAtlas(
      game,
      'assets/images/atlas/spritesheet.json',
      'atlas/spritesheet.png',
      filename,
      amount: amount,
      amountPerRow: amountPerRow,
      stepTime: stepTime,
      textureSize: GameConfig.playerAnimationSize,
      loop: loop,
      startRow: startRow,
      startCol: startCol,
      key: 'characters/player/$filename:$startRow:$startCol',
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (game.isCutscenePlaying) {
      velocity.x = 0;
      _applyGravity(dt);
      _applyVelocity(dt);
      _updateAnimation();
      return;
    }

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
    
    // Regenerate stamina (only when on ground and not performing any attacks)
    if (!_isDead && _hitStopTimer <= 0 && isOnGround && !_isAttacking && !_isAirAttacking) {
      game.playerState.stamina = (game.playerState.stamina + GameConfig.playerStaminaRegenRate * dt)
          .clamp(0.0, game.playerState.maxStamina);
    }
    
    // Tick attack input buffer
    if (_attackBufferTimer > 0) {
      _attackBufferTimer -= dt;
    }
    if (_ignorePlatformsTimer > 0) {
      _ignorePlatformsTimer -= dt;
    }
    // Attack damage delay
    if (_attackDamageDelayTimer > 0) {
      _attackDamageDelayTimer -= dt;
      if (_attackDamageDelayTimer <= 0) {
        _performAttack();
      }
    }
    if (_attackFreezeTimer > 0) {
      _attackFreezeTimer -= dt;
    }

    // Active descent plunge/jump attack collision damage and stagger
    if (_isAirAttacking && _airHangTimer <= 0) {
      final enemies = parent?.children.whereType<BaseEnemy>() ?? [];
      final playerRect = toRect();
      for (final enemy in enemies) {
        if (!_plungeHitEnemies.contains(enemy) && playerRect.overlaps(enemy.toRect())) {
          _plungeHitEnemies.add(enemy);
          final damage = game.playerState.effectiveDamage;
          final killed = enemy.takeDamage(damage, isPlunge: true);
          if (game.playerState.isIndomitable) {
            game.playerState.heal(damage * GameConfig.playerIndomitableLifestealRatio);
          }
          _hitStopTimer = hitStopDuration; // Impact pause
          game.onScreenShake(4.0); // Shake screen
          if (killed) {
            game.playerState.enemiesKilled++;
            game.playerState.addResolve(enemy.resolveReward);
            game.playerState.willpower += enemy.willpowerReward;
          }
        }
      }
    }

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
    } else if (_isDodging) {
      anim.current = PlayerAnimationState.dodge;
    } else if (_isAirAttacking) {
      anim.current = PlayerAnimationState.airAttack;
    } else if (_isAttacking) {
      if (_comboStep == 0) {
        anim.current = PlayerAnimationState.attack;
      } else if (_comboStep == 1) {
        anim.current = PlayerAnimationState.attack2;
      } else {
        anim.current = PlayerAnimationState.attack3;
      }
    } else if (_hurtTimer > 0) {
      anim.current = PlayerAnimationState.hurt;
    } else if (!isOnGround) {
      anim.current = PlayerAnimationState.jump;
    } else if (velocity.x != 0) {
      anim.current = PlayerAnimationState.run;
    } else {
      anim.current = PlayerAnimationState.idle;
    }

    if (isOnGround && !_isDead) {
      final isOverlappingHazard = game.world.children.any((c) => 
        (c is Lava || c is Spike) && toRect().overlaps((c as PositionComponent).toRect())
      );
      if (!isOverlappingHazard) {
        lastSafePosition = position.clone();
      }
    }
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (_isDead) return false;
    moveLeft = keysPressed.contains(LogicalKeyboardKey.keyA);
    moveRight = keysPressed.contains(LogicalKeyboardKey.keyD);
    downPressed = keysPressed.contains(LogicalKeyboardKey.keyS);
    
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyW) {
        jumpPressed = true;
      }
      if (event.logicalKey == LogicalKeyboardKey.space) {
        dodgePressed = true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyR) {
        activateIndomitable();
      }
      if (event.logicalKey == LogicalKeyboardKey.keyH) {
        triggerHopeHeal();
      }
      if (event.logicalKey == LogicalKeyboardKey.keyE) {
        if (currentPortal != null) {
          game.transitionThroughPortal(isReturn: currentPortal!.isReturn);
        } else if (currentExitPortal != null) {
          final enemiesRemaining = game.world.children.whereType<BaseEnemy>().where((e) => !e.isDead).length;
          if (enemiesRemaining == 0) {
            game.onLevelComplete();
          } else {
            game.onScreenShake(2.0); // Mild camera shake to signal portal is locked
          }
        } else if (currentGuardian != null) {
          game.openGuardianUpgrades();
        }
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
    if (_attackFreezeTimer > 0 || _isAirAttacking) {
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

    // Drop-down logic
    if (downPressed && isOnGround && _ignorePlatformsTimer <= 0) {
      _ignorePlatformsTimer = 0.25;
      isOnGround = false;
      velocity.y = 50.0; // Give a slight downward push to break ground-contact immediately
    }

    // Jump logic
    if (_isAirAttacking) {
      if (_airHangTimer > 0) {
        _airHangTimer -= dt;
        velocity.y = 0; // Hover
      } else {
        velocity.y = GameConfig.playerPlungeSpeed;
      }
    } else {
      if (_jumpBufferTimer > 0) {
        final staminaCost = GameConfig.playerStaminaJumpCost;
        if (_coyoteTimer > 0) {
          if (game.playerState.stamina >= staminaCost) {
            // Normal jump or coyote jump
            game.playerState.stamina -= staminaCost;
            velocity.y = jumpForce;
            isOnGround = false;
            _coyoteTimer = 0;
            _jumpBufferTimer = 0;
            _jumpsRemaining = _maxJumps - 1;
          }
        } else if (_jumpsRemaining > 0) {
          // Air jump (double jump)
          velocity.y = jumpForce;
          _jumpsRemaining = 0;
          _jumpBufferTimer = 0;
        }
      }
    }
  }

  void _handleAttack(double dt) {
    if (_comboWindowTimer > 0) {
      _comboWindowTimer -= dt;
      if (_comboWindowTimer <= 0 && !_isAttacking && !_comboQueued) {
        _comboStep = 0;
        _attackCooldownTimer = attackCooldown;
      }
    }

    if (_isAttacking) {
      _attackTimer -= dt;
      
      // Queue next combo hit if attacked during swing
      if (attackPressed && _comboStep < 2 && !_isDodging) {
        _comboQueued = true;
        attackPressed = false;
      }
      
      if (_attackTimer <= 0) {
        _isAttacking = false;
        
        // Reset animations so they play from the first frame next time
        _animationComponent?.animationTickers?[PlayerAnimationState.attack]?.reset();
        _animationComponent?.animationTickers?[PlayerAnimationState.attack2]?.reset();
        _animationComponent?.animationTickers?[PlayerAnimationState.attack3]?.reset();
        
        if (_comboQueued && _comboStep < 2) {
          final cost = GameConfig.playerStaminaAttackCost;
          if (game.playerState.stamina >= cost) {
            game.playerState.stamina -= cost;
            _comboStep++;
            _comboQueued = false;
            _isAttacking = true;
            _attackTimer = attackDuration;
            _attackDamageDelayTimer = attackDuration * GameConfig.playerAttackDamageDelayRatio;
            _attackFreezeTimer = attackDuration * GameConfig.playerAttackFreezeRatio;
          } else {
            // Cancel queued combo because of insufficient stamina
            _comboQueued = false;
            _comboStep = 0;
            _comboWindowTimer = 0;
            _attackCooldownTimer = attackCooldown;
          }
        } else {
          _comboQueued = false;
          if (_comboStep == 2) {
            // Finished 3rd hit, end combo and trigger cooldown
            _comboStep = 0;
            _comboWindowTimer = 0;
            _attackCooldownTimer = attackCooldown;
          } else {
            // Open grace window for next hit
            _comboWindowTimer = comboWindow;
          }
        }
      }
    }
 
    if (attackPressed && !_isDodging) {
      if (!isOnGround && !_isAirAttacking) {
        final cost = GameConfig.playerStaminaPlungeCost;
        if (game.playerState.stamina >= cost) {
          game.playerState.stamina -= cost;
          _isAirAttacking = true;
          _plungeHitEnemies.clear();
          attackPressed = false;
          velocity.x = 0;
          velocity.y = 0;
          _airHangTimer = GameConfig.playerPlungeDelay; // Use plunge delay config
        }
      } else if (isOnGround && !_isAttacking && _attackCooldownTimer <= 0 && _comboWindowTimer <= 0) {
        final cost = GameConfig.playerStaminaAttackCost;
        if (game.playerState.stamina >= cost) {
          game.playerState.stamina -= cost;
          _comboStep = 0;
          _isAttacking = true;
          _attackTimer = attackDuration;
          _attackDamageDelayTimer = attackDuration * GameConfig.playerAttackDamageDelayRatio;
          _attackFreezeTimer = attackDuration * GameConfig.playerAttackFreezeRatio;
          _comboQueued = false;
          attackPressed = false;
        }
      } else if (isOnGround && !_isAttacking && _comboWindowTimer > 0) {
        final cost = GameConfig.playerStaminaAttackCost;
        if (game.playerState.stamina >= cost) {
          game.playerState.stamina -= cost;
          _comboStep++;
          _comboWindowTimer = 0;
          _isAttacking = true;
          _attackTimer = attackDuration;
          _attackDamageDelayTimer = attackDuration * GameConfig.playerAttackDamageDelayRatio;
          _attackFreezeTimer = attackDuration * GameConfig.playerAttackFreezeRatio;
          _comboQueued = false;
          attackPressed = false;
        }
      }
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
    final enemies = parent?.children.whereType<BaseEnemy>() ?? [];
    for (final enemy in enemies) {
      final enemyRect = enemy.toRect();
      if (attackArea.overlaps(enemyRect)) {
        // Line of sight check to avoid hitting through solid walls
        final myCenter = position + size / 2;
        final enemyCenter = enemy.position + enemy.size / 2;
        if (!game.hasLineOfSight(myCenter, enemyCenter)) {
          continue;
        }

        final damage = game.playerState.effectiveDamage;
        final killed = enemy.takeDamage(damage);
        if (game.playerState.isIndomitable) {
          game.playerState.heal(damage * GameConfig.playerIndomitableLifestealRatio);
        }
        _hitStopTimer = hitStopDuration; // Hit-stop for impact feel
        game.onScreenShake(3.0); // Screen shake
        if (killed) {
          game.playerState.enemiesKilled++;
          // Gain resolve on kill
          game.playerState.addResolve(enemy.resolveReward);
          // Reward willpower based on enemy strength
          game.playerState.willpower += enemy.willpowerReward;
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
      final cost = GameConfig.playerStaminaDodgeCost;
      if (game.playerState.stamina >= cost) {
        game.playerState.stamina -= cost;
        _isDodging = true;
        _dodgeTimer = dodgeDuration;
      }
      dodgePressed = false;
    }
  }

  void _applyGravity(double dt) {
    if (!isOnGround) {
      if (_isAirAttacking && _airHangTimer > 0) {
        return; // Suspend gravity during hang-time
      }
      velocity.y += gravity * dt;
      final maxV = _isAirAttacking ? GameConfig.playerPlungeSpeed : maxFallSpeed;
      velocity.y = velocity.y.clamp(-1000, maxV);
    }
  }

  void _applyVelocity(double dt) {
    position += velocity * dt;
    // Fall into void = death
    final mapBottom = (game.activeGrid?.height ?? 25) * GameConfig.tileSize;
    if (position.y > mapBottom + 64) {
      _die();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is PlatformBlock) {
      _resolveBlockCollision(other);
    } else if (other is Lava) {
      receiveDamage(other.damage);
    } else if (other is Spike) {
      receiveDamage(other.damage);
    } else if (other is HealthPickup && !other.collected) {
      other.collected = true;
      other.removeFromParent();
      game.playerState.heal(other.healAmount);
      
      final tileX = (other.initialPosition.x / GameConfig.tileSize).round();
      final tileY = (other.initialPosition.y / GameConfig.tileSize).round();
      final key = '${game.gameState.currentLevel}_pickup_${tileX}_${tileY}';
      game.removedEntitiesKeys.add(key);
    } else if (other is DiamondPickup && !other.collected) {
      other.collected = true;
      other.removeFromParent();
      game.playerState.diamondsCollected++;

      final tileX = (other.initialPosition.x / GameConfig.tileSize).round();
      final tileY = (other.initialPosition.y / GameConfig.tileSize).round();
      final key = '${game.gameState.currentLevel}_pickup_${tileX}_${tileY}';
      game.collectedDiamondsKeys.add(key);
    } else if (other is LostWillPickup && !other.collected) {
      other.collected = true;
      other.removeFromParent();
      
      // Restore lost willpower
      game.playerState.willpower += other.willpowerAmount;
      
      // Erase the bloodstain completely from the player state
      game.playerState.lostWillpower = 0;
      game.playerState.lostWillX = null;
      game.playerState.lostWillY = null;
      game.playerState.lostWillLevelId = null;

    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is PlatformBlock) {
      _resolveBlockCollision(other);
    }
    if (other is Lava) {
      receiveDamage(other.damage);
    } else if (other is Spike) {
      receiveDamage(other.damage);
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
        
    if (block.isJumpThrough) {
      if (_ignorePlatformsTimer > 0) return;
      if (minOverlap == overlapTop && velocity.y >= 0) {
        // Only land if we are falling onto the top surface, not jumping through from below
        if (overlapTop <= size.y * 0.5) {
          position.y = block.position.y - size.y;
          velocity.y = 0;
          isOnGround = true;
          _jumpsRemaining = _maxJumps;
          if (_isAirAttacking) {
            _isAirAttacking = false;
            _performPlungeSplash();
          }
        }
      }
      return; // Ignore other collisions (bottom, sides)
    }
    
    if (minOverlap == overlapTop && velocity.y >= 0) {
      // Landing on top
      position.y = block.position.y - size.y;
      velocity.y = 0;
      isOnGround = true;
      _jumpsRemaining = _maxJumps;
      if (_isAirAttacking) {
        _isAirAttacking = false;
        _performPlungeSplash();
      }
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

  void receiveDamage(double damage) {
    if (isInvincible || _isDead) return;
    final died = game.playerState.takeDamage(damage);
    _hurtTimer = GameConfig.playerHurtDuration;

    // Reset ticker so it plays from the beginning
    _animationComponent?.animationTickers?[PlayerAnimationState.hurt]?.reset();

    game.onScreenShake(5.0);
    if (died) {
      _die();
    } else {
      final hpPct = game.playerState.health / game.playerState.maxHealth;
      if (hpPct <= 0.3 && !game.lowHealthTauntTriggered) {
        game.lowHealthTauntTriggered = true;
        game.triggerDynamicTaunt('LOW_HEALTH');
      }
    }
  }

  void _die() {
    if (_isDead) return;
    
    _isDead = true;
    _respawnTimer = respawnDelay;
    velocity = Vector2.zero();
    game.playerState.health = 0;
    velocity.x = 0; // Stop horizontal movement on death
    
    game.playerState.deathCount++;
  }

  void _performPlungeSplash() {
    final splashArea = Rect.fromCenter(
      center: Offset(position.x + size.x / 2, position.y + size.y), // centered at player feet
      width: GameConfig.playerPlungeSplashRadius * 2,
      height: 60,
    );
    
    final enemies = parent?.children.whereType<BaseEnemy>() ?? [];
    for (final enemy in enemies) {
      if (splashArea.overlaps(enemy.toRect())) {
        final damage = game.playerState.isIndomitable
            ? GameConfig.playerPlungeSplashDamage * GameConfig.playerIndomitableDamageMultiplier
            : GameConfig.playerPlungeSplashDamage;
        final killed = enemy.takeDamage(damage);
        if (game.playerState.isIndomitable) {
          game.playerState.heal(damage * GameConfig.playerIndomitableLifestealRatio);
        }
        if (killed) {
          game.playerState.enemiesKilled++;
          game.playerState.addResolve(enemy.resolveReward);
          game.playerState.willpower += enemy.willpowerReward;
        }
      }
    }
    
    _hitStopTimer = hitStopDuration * 2;
    game.onScreenShake(8.0);
    _attackCooldownTimer = attackCooldown;
  }

  /// Activate the Indomitable state (called when resolve is full).
  void activateIndomitable() {
    if (game.playerState.resolve >= 100.0 && !game.playerState.isIndomitable) {
      game.playerState.isIndomitable = true;
    }
  }

  /// Deactivate the Indomitable state.
  void deactivateIndomitable() {
    game.playerState.isIndomitable = false;
    game.playerState.resolve = 0;
  }

  /// Manually trigger Hope's heal.
  void triggerHopeHeal() {
    final cat = game.world.children.whereType<CompanionCat>().firstOrNull;
    if (cat != null) {
      cat.manualHeal();
    }
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
