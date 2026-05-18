import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart' hide Block;

import '../components/block.dart';
import 'package:struggler/game/components/lava.dart';
import '../config.dart';
import '../struggler_game.dart';
import 'player.dart';

// ---------------------------------------------------------------------------
// BaseEnemy — abstract root for every enemy type.
//
// Provides:
//   • gravity + block collision resolution (incl. jump-through platforms)
//   • takeDamage() / onDeath() / onWallHit() hooks for subclasses
//   • hurt-flash, health-bar helper
//   • sprite-flip utility that reads facingDirection
//
// NOTE: The old concrete Enemy class is gone. Use one of the subclasses in
//       lib/game/components/enemies/. The typedef below keeps old code compiling.
// ---------------------------------------------------------------------------
abstract class BaseEnemy extends PositionComponent
    with CollisionCallbacks, HasGameReference<StruggleGame> {
  // --- Stats ---
  double maxHealth;
  double health;
  double contactDamage;
  bool isDead = false;

  /// Original grid coordinates mapping to prevent respawns
  dynamic spawnData;

  /// The willpower (will) rewarded to the player when this enemy dies.
  int get willpowerReward;

  /// The resolve rewarded to the player when this enemy dies.
  double get resolveReward;

  // --- Physics ---
  double velocityY = 0;
  static const double _gravity = GameConfig.enemyGravity;
  bool isOnGround = false;

  // --- State ---
  double hurtTimer = 0;
  int facingDirection = 1; // 1 = right, -1 = left
  double _ignorePlatformsTimer = 0.0;
  double _staggerVelocityX = 0.0;
  bool get isAttackingState => false;

  // --- Animation slot (set by subclass in onLoad) ---
  PositionComponent? animComp;

  BaseEnemy({
    required Vector2 position,
    required Vector2 size,
    double maxHealth = 50,
    double contactDamage = 10,
  }) : maxHealth = maxHealth * GameConfig.enemyHealthMultiplier,
       contactDamage = contactDamage * GameConfig.enemyDamageMultiplier,
       health = maxHealth * GameConfig.enemyHealthMultiplier,
       super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());

    final levelData = game.cachedActiveLevel;
    if (levelData != null) {
      final customHealthMult = levelData.enemyHealthMultiplier ?? 1.0;
      final customDamageMult = levelData.enemyDamageMultiplier ?? 1.0;

      maxHealth *= customHealthMult;
      contactDamage *= customDamageMult;
      health *= customHealthMult;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (game.isCutscenePlaying) {
      _applyGravity(dt);
      _flipSprite();
      isOnGround = false;
      return;
    }

    if (isDead) {
      _applyGravity(dt);
      return;
    }
    if (hurtTimer > 0) hurtTimer -= dt;
    if (_staggerVelocityX.abs() > 0.01) {
      final step = _staggerVelocityX * dt;
      position.x += step;
      _staggerVelocityX *= 0.82; // Decelerate quickly
    } else {
      _staggerVelocityX = 0.0;
    }
    if (_ignorePlatformsTimer > 0) _ignorePlatformsTimer -= dt;
    _applyGravity(dt);
    _flipSprite();

    // Fall into void = death
    final maxMapHeight = (game.activeGrid?.height ?? 20) * GameConfig.tileSize;
    if (position.y > maxMapHeight + 128) {
      takeDamage(maxHealth * 2.0); // Instantly vaporize in the void!
    }

    isOnGround = false; // reset; collision will set true
  }

  void jump() {
    if (isOnGround) {
      velocityY = GameConfig.playerJumpForce;
      isOnGround = false;
    }
  }

  void stagger(double pushVelocityX) {
    _staggerVelocityX = pushVelocityX;
  }

  // ------------------------------------------------------------------ physics

  void _applyGravity(double dt) {
    if (!isOnGround) {
      velocityY += _gravity * dt;
      velocityY = velocityY.clamp(-1000.0, 600.0);
      position.y += velocityY * dt;
    }
  }

  /// Evaluates if stepping horizontally by [step] would lead to a cliff (void)
  /// or directly into a lava lake. Includes a lookahead buffer.
  bool wouldFall(double step) {
    final gameRef = game;
    final grid = gameRef.activeGrid;
    if (grid == null) return false;

    // Look ahead to where the leading foot will land, adding a lookahead buffer
    // in the direction of movement to detect hazards early.
    final buffer = step > 0 ? 4.0 : (step < 0 ? -4.0 : 0.0);
    final nextX = position.x + step;
    final leadingX = nextX + (step > 0 ? size.x : 0.0) + buffer;
    final footY = position.y + size.y + 4.0; // 4px under foot-level

    final gx = (leadingX ~/ GameConfig.tileSize).toInt();
    final gy = (footY ~/ GameConfig.tileSize).toInt();

    // Out of bounds check
    if (gx < 0 || gx >= grid.width) return true;

    bool hasLava = false;
    bool hasSolid = false;

    for (int y = (gy - 1).clamp(0, grid.height - 1); y < grid.height; y++) {
      if (grid.isLava(gx, y)) {
        hasLava = true;
      }
      if (grid.isSolid(gx, y)) {
        hasSolid = true;
      }
    }

    return hasLava || !hasSolid;
  }

  /// Subclasses can override this to offset horizontal shift when flipping
  /// (e.g. for off-center sprite sheets like Bringer of Death).
  double get horizontalFlipOffset => 0.0;

  /// True if the raw sprite sheet faces left by default.
  bool get defaultSpriteFacesLeft => false;

  void _flipSprite() {
    final anim = animComp;
    if (anim == null) return;

    final isFacingRight = (facingDirection == 1);
    final shouldBeFlipped = defaultSpriteFacesLeft
        ? isFacingRight
        : !isFacingRight;

    if (shouldBeFlipped && anim.scale.x > 0) {
      anim.scale.x *= -1;
    } else if (!shouldBeFlipped && anim.scale.x < 0) {
      anim.scale.x *= -1;
    }

    final offset = horizontalFlipOffset;
    if (offset != 0) {
      if (isFacingRight) {
        anim.position.x = size.x / 2 + offset;
      } else {
        anim.position.x = size.x / 2 - offset;
      }
    }
  }

  // ---------------------------------------------------------------- collision

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is PlatformBlock) {
      _resolveBlockCollision(other);
    } else if (other is Lava) {
      _onLavaContact(other.damage);
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is PlatformBlock) {
      _resolveBlockCollision(other);
    }
    if (other is Lava) {
      _onLavaContact(other.damage);
    }
  }

  void _onLavaContact(double damage) {
    if (isDead) return;
    if (hurtTimer > 0) return; // Brief immunity frame
    takeDamage(damage);
  }

  void _resolveBlockCollision(PlatformBlock block) {
    final myRect = toRect();
    final blockRect = block.toRect();

    final overlapTop = myRect.bottom - blockRect.top;
    final overlapBottom = blockRect.bottom - myRect.top;
    final overlapLeft = myRect.right - blockRect.left;
    final overlapRight = blockRect.right - myRect.left;

    final minOverlap = [
      overlapLeft,
      overlapRight,
      overlapTop,
      overlapBottom,
    ].reduce((a, b) => a < b ? a : b);

    if (block.isJumpThrough) {
      if (_ignorePlatformsTimer > 0) return;
      final player = playerTarget;
      if (player != null && player.position.y > position.y + size.y - 8.0) {
        _ignorePlatformsTimer = 0.25;
        isOnGround = false;
        return;
      }
      if (minOverlap == overlapTop &&
          velocityY >= 0 &&
          overlapTop <= size.y * 0.5) {
        position.y = block.position.y - size.y;
        velocityY = 0;
        isOnGround = true;
      }
      return;
    }

    if (minOverlap == overlapTop && velocityY >= 0) {
      position.y = block.position.y - size.y;
      velocityY = 0;
      isOnGround = true;
    } else if (minOverlap == overlapBottom && velocityY < 0) {
      position.y = block.position.y + block.size.y;
      velocityY = 0;
    } else if (minOverlap == overlapLeft) {
      position.x = block.position.x - size.x;
      if (facingDirection > 0) {
        onWallHit();
      }
    } else if (minOverlap == overlapRight) {
      position.x = block.position.x + block.size.x;
      if (facingDirection < 0) {
        onWallHit();
      }
    }
  }

  Player? get playerTarget => parent?.children.whereType<Player>().firstOrNull;

  // ------------------------------------------------------------------- hooks

  /// Called when the enemy hits a wall. Default: reverse patrol direction.
  void onWallHit() => facingDirection *= -1;

  /// Called when HP reaches zero. Default: remove from parent.
  /// Override to add death effects (explosion, particles, etc.).
  void onDeath() => removeFromParent();

  // ------------------------------------------------------------------ combat

  /// Take [damage] points. Returns true if the hit was fatal.
  bool takeDamage(double damage, {bool isPlunge = false}) {
    if (isDead) return false;
    health -= damage;
    hurtTimer = GameConfig.enemyHurtDuration;
    if (isPlunge) {
      interruptAttack();
    }
    if (health <= 0) {
      isDead = true;
      if (spawnData != null && game.gameState.currentLevel != -1) {
        final key =
            '${game.gameState.currentLevel}_enemy_${spawnData.x}_${spawnData.y}';
        game.removedEntitiesKeys.add(key);
      }
      onDeath();
      return true;
    }
    return false;
  }

  /// Override to define behaviors for interrupting active attacks/casts.
  void interruptAttack() {}

  // ------------------------------------------------------------------ render

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!isDead) {
      renderHealthBar(canvas);
    }
  }

  /// The vertical position of the health bar relative to the top of the hitbox (y = 0).
  /// Subclasses override this to perfectly position their health bars above their visual heads.
  double get healthBarYOffset => -6.0;

  /// Draws the HP bar above the enemy. Subclasses call this from render().
  void renderHealthBar(Canvas canvas) {
    final pct = (health / maxHealth).clamp(0.0, 1.0);
    final barW = (size.x * 0.4).clamp(16.0, 24.0);
    final startX = (size.x - barW) / 2;
    final startY = healthBarYOffset;

    canvas.drawRect(
      Rect.fromLTWH(startX, startY, barW, 2.5),
      Paint()..color = const Color(0xFF333333),
    );
    canvas.drawRect(
      Rect.fromLTWH(startX, startY, barW * pct, 2.5),
      Paint()..color = const Color(0xFFFF3333),
    );
  }

  /// Placeholder body draw used when sprite assets haven't loaded yet.
  void renderPlaceholder(Canvas canvas, Color bodyColor) {
    final paint = Paint()
      ..color = hurtTimer > 0 ? const Color(0xFFFFFFFF) : bodyColor;
    canvas.drawRect(Rect.fromLTWH(2, 6, size.x - 4, size.y - 6), paint);
    canvas.drawRect(Rect.fromLTWH(4, 0, size.x - 8, 10), paint);
    canvas.drawRect(
      Rect.fromLTWH(6, 3, 3, 3),
      Paint()..color = const Color(0xFFFF4444),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x - 10, 3, 3, 3),
      Paint()..color = const Color(0xFFFF4444),
    );
  }
}

// Backward-compat alias — existing code that imports Enemy still compiles.
typedef Enemy = BaseEnemy;
