import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../asset_registry.dart';
import '../config.dart';
import '../struggler_game.dart';
import 'player.dart';
import 'enemy.dart';

enum CatState { idle, run, jump, attack }

enum CatBehaviorMode { following, attacking, healingLeap, healingBounce }

class HealParticle {
  Vector2 position;
  Vector2 velocity;
  double alpha;
  double size;
  bool isPlus;
  Color? color;

  HealParticle({
    required this.position,
    required this.velocity,
    required this.alpha,
    required this.size,
    required this.isPlus,
    this.color,
  });
}

class ScratchSlash {
  Vector2 position;
  double lifeTime;
  double maxLifeTime;
  double angle;

  ScratchSlash({
    required this.position,
    required this.maxLifeTime,
    this.angle = -0.35,
  }) : lifeTime = maxLifeTime;
}

/// Companion Cat "Hope" - follows the player's movements automatically, mirrors jumps,
/// defends the player by scratching nearby enemies, and leaps to heal them at critical health.
class CompanionCat extends PositionComponent
    with HasGameReference<StruggleGame> {
  late final SpriteAnimationGroupComponent<CatState> _animGroup;
  bool _spriteLoaded = false;
  double _animationTimer = 0;
  int _facingDirection = 1;

  // --- Behavior & States ---
  CatBehaviorMode _behaviorMode = CatBehaviorMode.following;
  double _attackCooldownTimer = 0.0;
  // --- Attack Target ---
  BaseEnemy? _attackTarget;
  double _attackDurationTimer = 0.0;
  double _damageDelayTimer = 0.0;

  // --- Heal Lunge Target & Cooldown ---
  double _bounceTimer = 0.0;

  // --- Custom Heal Render Magic Particle System & Visual Slashes ---
  final List<HealParticle> _healParticles = [];
  final List<ScratchSlash> _scratchSlashes = [];
  final Random _rng = Random();

  CompanionCat({required Vector2 position})
    : super(position: position, size: GameConfig.renderSizeCat);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    final frame = Vector2(80, 64);

    try {
      final idle = await AssetRegistry.getAnimation(
        game,
        "characters/hope/Idle.png",
        SpriteAnimationData.sequenced(
          amount: 8,
          stepTime: 0.1,
          textureSize: frame,
        ),
        key: 'cat/idle',
      );

      final run = await AssetRegistry.getAnimation(
        game,
        "characters/hope/Run.png",
        SpriteAnimationData.sequenced(
          amount: 8,
          stepTime: 0.08,
          textureSize: frame,
        ),
        key: 'cat/run',
      );

      final jump = await AssetRegistry.getAnimation(
        game,
        "characters/hope/Jump.png",
        SpriteAnimationData.sequenced(
          amount: 3,
          stepTime: 0.12,
          textureSize: frame,
          loop: false,
        ),
        key: 'cat/jump',
      );

      final attack = await AssetRegistry.getAnimation(
        game,
        "characters/hope/Attack.png",
        SpriteAnimationData.sequenced(
          amount: 8,
          stepTime: 0.12,
          textureSize: frame,
          loop: false,
        ),
        key: 'cat/attack',
      );

      _animGroup = SpriteAnimationGroupComponent<CatState>(
        animations: {
          CatState.idle: idle,
          CatState.run: run,
          CatState.jump: jump,
          CatState.attack: attack,
        },
        current: CatState.idle,
        size: size,
        position: Vector2(size.x / 2, size.y + GameConfig.offsetYCat),
        anchor: Anchor.bottomCenter,
      );

      add(_animGroup);
      _spriteLoaded = true;
    } catch (e) {
      // Keep fallback procedural rendering if load fails
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animationTimer += dt;

    // Tick Attack Cooldown
    if (_attackCooldownTimer > 0) {
      _attackCooldownTimer -= dt;
    }

    // Update particles
    for (final p in _healParticles) {
      p.position += p.velocity * dt;
      p.alpha -= dt * 1.2; // Fade out over ~0.8s
    }
    _healParticles.removeWhere((p) => p.alpha <= 0);

    // Update scratch slashes
    for (final s in _scratchSlashes) {
      s.lifeTime -= dt;
    }
    _scratchSlashes.removeWhere((s) => s.lifeTime <= 0);

    // Locate player to coordinate behavior
    final player = game.world.children.whereType<Player>().firstOrNull;
    if (player == null) return;

    final playerCenter = player.position + player.size / 2;
    final myCenter = position + size / 2;

    switch (_behaviorMode) {
      case CatBehaviorMode.following:
        // 1. Check for Proximity Combat Attacks (if attack cooldown ready)
        if (_attackCooldownTimer <= 0) {
          final enemies = game.world.children.whereType<BaseEnemy>().where(
            (e) => !e.isDead,
          );
          BaseEnemy? closestEnemy;
          double closestDist = GameConfig.catAttackRange;

          for (final enemy in enemies) {
            final enemyCenter = enemy.position + enemy.size / 2;
            final dist = playerCenter.distanceTo(enemyCenter);
            if (dist < closestDist) {
              closestDist = dist;
              closestEnemy = enemy;
            }
          }

          if (closestEnemy != null) {
            _attackTarget = closestEnemy;
            _behaviorMode = CatBehaviorMode.attacking;
            _attackDurationTimer = 0.96; // 8 frames * 0.12 stepTime = 0.96 seconds
            _attackCooldownTimer = GameConfig.catAttackCooldown;

            if (_spriteLoaded) {
              _animGroup.current = CatState.attack;
              _animGroup.animationTickers?[CatState.attack]?.reset();
            }

            // Sync damage delay timer with peak frame index 5 (5 * 0.12s = 0.60s)
            _damageDelayTimer = 0.60;
            break;
          }
        }

        // Standard Smooth Following Logic
        _facingDirection = player.facingDirection;
        final targetX = player.position.x - (_facingDirection * GameConfig.catFollowOffset);
        final targetY = player.position.y + player.size.y - size.y;

        // Smoothly interpolate positions (spring/lerp)
        position.x += (targetX - position.x) * 0.12;
        position.y += (targetY - position.y) * 0.16;

        // Update standard follow animation state
        if (_spriteLoaded) {
          final distHoriz = (targetX - position.x).abs();
          final distVert = (targetY - position.y).abs();

          if (distVert > 12.0) {
            _animGroup.current = CatState.jump;
          } else if (distHoriz > 4.0) {
            _animGroup.current = CatState.run;
          } else {
            _animGroup.current = CatState.idle;
          }
        }
        break;

      case CatBehaviorMode.attacking:
        // Lunge fast towards the enemy, facing them
        if (_attackTarget != null && !_attackTarget!.isDead) {
          final enemyCenter = _attackTarget!.position + _attackTarget!.size / 2;
          _facingDirection = (enemyCenter.x > myCenter.x) ? 1 : -1;

          // Lunge halfway towards enemy center
          final targetLungeX = enemyCenter.x - (_facingDirection * 12.0);
          final targetLungeY = enemyCenter.y;
          position.x += (targetLungeX - position.x) * 0.22;
          position.y += (targetLungeY - position.y) * 0.22;
        }

        // Apply delayed attack damage when timer expires
        if (_damageDelayTimer > 0) {
          _damageDelayTimer -= dt;
          if (_damageDelayTimer <= 0) {
            if (_attackTarget != null && !_attackTarget!.isDead) {
              _attackTarget!.takeDamage(currentDamage);

              // Spawn the gorgeous visual scratch slash effect!
              final enemyCenter = _attackTarget!.position + _attackTarget!.size / 2;
              _scratchSlashes.add(
                ScratchSlash(
                  position: enemyCenter,
                  maxLifeTime: 0.35, // 0.35s to grow and fade
                  angle: _facingDirection == 1 ? -0.35 : 0.35,
                ),
              );

              // Also spawn some orange-red damage spark particles for extra punch!
              for (int i = 0; i < 8; i++) {
                _healParticles.add(
                  HealParticle(
                    position: enemyCenter.clone(),
                    velocity: Vector2(
                      (_rng.nextDouble() * 120 - 60) * _facingDirection,
                      _rng.nextDouble() * -100 - 40,
                    ),
                    alpha: 1.0,
                    size: 2.0 + _rng.nextDouble() * 3.0,
                    isPlus: false, // Sparks
                    color: const Color(0xFFFF5500), // Glowing Neon Orange-Red
                  ),
                );
              }
            }
          }
        }

        _attackDurationTimer -= dt;
        if (_attackDurationTimer <= 0) {
          _behaviorMode = CatBehaviorMode.following;
        }
        break;

      case CatBehaviorMode.healingLeap:
        // Face player and lunge rapidly
        _facingDirection = (playerCenter.x > myCenter.x) ? 1 : -1;

        // Target the cat's center to the player's center to prevent clipping below feet
        final targetLeapX = playerCenter.x - size.x / 2;
        final targetLeapY = playerCenter.y - size.y / 2;
        position.x += (targetLeapX - position.x) * 0.24;
        position.y += (targetLeapY - position.y) * 0.24;

        // Check contact (extremely close to player center)
        if (myCenter.distanceTo(playerCenter) < 14.0) {
          // 1. Perform Heal
          game.playerState.heal(GameConfig.catHealAmount);

          // 2. Generate Render Magic Particles around the player!
          for (int i = 0; i < 15; i++) {
            _healParticles.add(
              HealParticle(
                position: Vector2(
                  playerCenter.x + (_rng.nextDouble() * 24 - 12),
                  playerCenter.y + (_rng.nextDouble() * 16 - 8),
                ),
                velocity: Vector2(
                  _rng.nextDouble() * 30 - 15,
                  -40 - _rng.nextDouble() * 50,
                ), // rising up
                alpha: 1.0,
                size: 2.0 + _rng.nextDouble() * 3.5,
                isPlus: _rng.nextBool(),
              ),
            );
          }

          // 3. Transition to Bounce Back Phase
          _behaviorMode = CatBehaviorMode.healingBounce;
          _bounceTimer = 0.45; // length of bounce

          if (_spriteLoaded) {
            _animGroup.current = CatState.jump;
            _animGroup.animationTickers?[CatState.jump]?.reset();
          }
        }
        break;

      case CatBehaviorMode.healingBounce:
        // Move rapidly to the bounce target in the air relative to the player's live position
        final behindDir = -player.facingDirection;
        final targetBounceX = player.position.x + (behindDir * 40) - size.x / 2;
        final targetBounceY = player.position.y - 16.0;
        position.x += (targetBounceX - position.x) * 0.20;
        position.y += (targetBounceY - position.y) * 0.20;

        _bounceTimer -= dt;
        if (_bounceTimer <= 0) {
          _behaviorMode = CatBehaviorMode.following;
        }
        break;
    }

    // Mirror Sprite Direction Facing & Sync Sizing dynamically
    if (_spriteLoaded) {
      _animGroup.size = size;
      _animGroup.position = Vector2(size.x / 2, size.y + GameConfig.offsetYCat);

      if (_facingDirection == 1) {
        if (_animGroup.scale.x > 0) {
          _animGroup.scale.x = -_animGroup.scale.x.abs();
        }
      } else if (_facingDirection == -1) {
        if (_animGroup.scale.x < 0) {
          _animGroup.scale.x = _animGroup.scale.x.abs();
        }
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // --- Render Custom Particles (Heal and Attack Sparks) ---
    // Since canvas coordinates are local to the Cat's position,
    // we translate the canvas to render the particles in absolute world positions
    if (_healParticles.isNotEmpty) {
      canvas.save();
      // Translate canvas so that (0, 0) matches absolute world coordinates relative to the cat
      canvas.translate(-position.x, -position.y);

      for (final p in _healParticles) {
        final opacityColor = (p.color ?? const Color(0xFF39FF14))
            .withValues(alpha: p.alpha.clamp(0.0, 1.0)); // Neon green or custom color!
        final pPaint = Paint()
          ..color = opacityColor
          ..style = PaintingStyle.fill;

        if (p.isPlus) {
          // Draw nice plus "+" sign
          final w = p.size;
          final t = w / 3;
          canvas.drawRect(
            Rect.fromLTWH(p.position.x - w / 2, p.position.y - t / 2, w, t),
            pPaint,
          );
          canvas.drawRect(
            Rect.fromLTWH(p.position.x - t / 2, p.position.y - w / 2, t, w),
            pPaint,
          );
        } else {
          // Draw sparkling circle
          canvas.drawCircle(
            Offset(p.position.x, p.position.y),
            p.size / 2,
            pPaint,
          );
        }
      }
      canvas.restore();
    }

    // --- Render Gorgeous Neon Claw Slashes ---
    if (_scratchSlashes.isNotEmpty) {
      canvas.save();
      canvas.translate(-position.x, -position.y); // Translate to absolute world coords

      for (final slash in _scratchSlashes) {
        final progress = 1.0 - (slash.lifeTime / slash.maxLifeTime);
        final alpha = (slash.lifeTime / slash.maxLifeTime).clamp(0.0, 1.0);

        // Draw 3 parallel claw marks!
        final strokePaint = Paint()
          ..color = const Color(0xFFFF2E93).withValues(alpha: alpha) // Bright Neon Pink claw
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2 * (1.0 - progress * 0.4)
          ..strokeCap = StrokeCap.round;

        final glowPaint = Paint()
          ..color = const Color(0xFFFFFF00).withValues(alpha: alpha) // Glowing Neon Yellow core
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;

        // Draw 3 slashes side by side
        final slashLength = 26.0;
        final spacing = 5.5;

        canvas.save();
        canvas.translate(slash.position.x, slash.position.y);
        canvas.rotate(slash.angle);

        for (int i = -1; i <= 1; i++) {
          final offsetX = i * spacing;
          final startY = -slashLength / 2 * (1.0 - progress * 0.2);
          final endY = slashLength / 2 * (1.0 + progress * 0.4);

          // Draw the outer slash pink glow
          canvas.drawLine(
            Offset(offsetX, startY),
            Offset(offsetX, endY),
            strokePaint,
          );
          // Draw the inner yellow glow
          canvas.drawLine(
            Offset(offsetX, startY),
            Offset(offsetX, endY),
            glowPaint,
          );
        }
        canvas.restore();
      }
      canvas.restore();
    }

    if (_spriteLoaded) {
      return; // Return early, Flame takes care of the Sprite Group Component
    }

    // Fallback Procedural Drawing
    final cx = size.x / 2;
    final cy = size.y / 2 - 2;

    canvas.save();
    if (_facingDirection == -1) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }

    final catPaint = Paint()
      ..color =
          const Color(0xFFFF8C00) // Deep Orange
      ..style = PaintingStyle.fill;

    final whitePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;

    final detailPaint = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.fill;

    // 1. Draw Tail (wiggling)
    final tailWiggle = sin(_animationTimer * 6) * 0.15;
    canvas.save();
    canvas.translate(cx - 10, cy + 4);
    canvas.rotate(tailWiggle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-2, -12, 4, 12),
        const Radius.circular(2),
      ),
      catPaint,
    );
    canvas.restore();

    // 2. Draw Body (round oval)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 2, cy + 4), width: 18, height: 12),
      catPaint,
    );

    // 3. Draw Head
    canvas.drawCircle(Offset(cx + 4, cy - 2), 6.5, catPaint);

    // 4. Draw Ears (triangles)
    final leftEar = Path()
      ..moveTo(cx + 1, cy - 7)
      ..lineTo(cx + 1, cy - 12)
      ..lineTo(cx + 5, cy - 8)
      ..close();
    canvas.drawPath(leftEar, catPaint);

    final rightEar = Path()
      ..moveTo(cx + 5, cy - 7)
      ..lineTo(cx + 8, cy - 12)
      ..lineTo(cx + 8, cy - 7)
      ..close();
    canvas.drawPath(rightEar, catPaint);

    // 5. Draw Eyes
    canvas.drawCircle(Offset(cx + 6, cy - 3), 1, detailPaint);
    canvas.drawCircle(Offset(cx + 9, cy - 3), 1, detailPaint);

    // 6. Cute white chest fluff
    canvas.drawCircle(Offset(cx + 1, cy + 4), 3, whitePaint);

    canvas.restore();
  }

  /// Calculate the upgraded attack damage based on Hope's Sanctuary Level
  double get currentDamage =>
      GameConfig.catAttackDamage +
      (game.playerState.catHealUpgradeLevel - 1) *
          GameConfig.catAttackDamagePerLevel;

  /// Manually trigger Hope's healing leap.
  bool manualHeal() {
    final player = game.world.children.whereType<Player>().firstOrNull;
    if (player == null || player.isDead) return false;
    if (game.playerState.catHealsRemaining <= 0) return false;
    if (game.playerState.health >= game.playerState.maxHealth) return false; // Already full health
    if (_behaviorMode == CatBehaviorMode.healingLeap || _behaviorMode == CatBehaviorMode.healingBounce) {
      return false; // Already performing a heal sequence
    }

    // Decrement remaining heals
    game.playerState.catHealsRemaining--;

    // Start healing leap sequence
    _behaviorMode = CatBehaviorMode.healingLeap;
    if (_spriteLoaded) {
      _animGroup.current = CatState.jump;
      _animGroup.animationTickers?[CatState.jump]?.reset();
    }
    return true;
  }
}
