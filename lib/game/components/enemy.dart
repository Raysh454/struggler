import 'package:flame/collisions.dart';
import 'package:flame/components.dart' hide Block;
import 'dart:ui';

import '../components/block.dart';

/// Enemy entity with patrol AI and combat stats.
class Enemy extends PositionComponent with CollisionCallbacks {
  final double maxHealth;
  double health;
  final double contactDamage;
  final double speed;
  final String enemyType; // 'basic', 'heavy', 'fast'
  final double patrolRange;

  // --- Patrol ---
  late double _patrolOriginX;
  int _patrolDirection = 1;

  // --- State ---
  double _hurtTimer = 0;
  bool isDead = false;

  // --- Physics ---
  double _velocityY = 0;
  static const double _gravity = 900.0;
  bool _isOnGround = false;

  Enemy({
    required Vector2 position,
    this.maxHealth = 50,
    this.contactDamage = 10,
    this.speed = 60.0,
    this.enemyType = 'basic',
    this.patrolRange = 100.0,
  })  : health = maxHealth,
        super(
          position: position,
          size: _sizeForType(enemyType),
        );

  static Vector2 _sizeForType(String type) {
    switch (type) {
      case 'heavy':
        return Vector2(36, 44);
      case 'fast':
        return Vector2(22, 32);
      default:
        return Vector2(28, 36);
    }
  }

  @override
  Future<void> onLoad() async {
    _patrolOriginX = position.x;
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isDead) return;

    _updateTimers(dt);
    _patrol(dt);
    _applyGravity(dt);
  }

  void _updateTimers(double dt) {
    if (_hurtTimer > 0) _hurtTimer -= dt;
  }

  void _patrol(double dt) {
    // Simple patrol: walk back and forth within range
    position.x += speed * _patrolDirection * dt;

    if (position.x > _patrolOriginX + patrolRange) {
      _patrolDirection = -1;
    } else if (position.x < _patrolOriginX - patrolRange) {
      _patrolDirection = 1;
    }
  }

  void _applyGravity(double dt) {
    if (!_isOnGround) {
      _velocityY += _gravity * dt;
      _velocityY = _velocityY.clamp(-1000, 600);
      position.y += _velocityY * dt;
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is PlatformBlock) {
      _resolveBlockCollision(other);
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is PlatformBlock) {
      _resolveBlockCollision(other);
    }
  }

  void _resolveBlockCollision(PlatformBlock block) {
    final enemyRect = toRect();
    final blockRect = block.toRect();

    final overlapTop = enemyRect.bottom - blockRect.top;
    final overlapBottom = blockRect.bottom - enemyRect.top;
    final overlapLeft = enemyRect.right - blockRect.left;
    final overlapRight = blockRect.right - enemyRect.left;

    final minOverlap = [overlapLeft, overlapRight, overlapTop, overlapBottom]
        .reduce((a, b) => a < b ? a : b);

    if (minOverlap == overlapTop && _velocityY >= 0) {
      position.y = block.position.y - size.y;
      _velocityY = 0;
      _isOnGround = true;
    } else if (minOverlap == overlapLeft || minOverlap == overlapRight) {
      // Hit a wall — reverse patrol direction
      _patrolDirection *= -1;
    }
  }

  /// Take damage. Returns true if the enemy died.
  bool takeDamage(double damage) {
    health -= damage;
    _hurtTimer = 0.15;

    if (health <= 0) {
      isDead = true;
      removeFromParent();
      return true;
    }
    return false;
  }

  @override
  void render(Canvas canvas) {
    if (isDead) return;

    Color bodyColor;
    if (_hurtTimer > 0) {
      bodyColor = const Color(0xFFFFFFFF); // Flash white when hit
    } else {
      switch (enemyType) {
        case 'heavy':
          bodyColor = const Color(0xFF8B0000); // Dark red for heavy
          break;
        case 'fast':
          bodyColor = const Color(0xFF4B0082); // Indigo for fast
          break;
        default:
          bodyColor = const Color(0xFF660066); // Purple for basic
      }
    }

    final paint = Paint()..color = bodyColor;

    // Body
    canvas.drawRect(
      Rect.fromLTWH(2, 6, size.x - 4, size.y - 6),
      paint,
    );

    // Head
    canvas.drawRect(
      Rect.fromLTWH(4, 0, size.x - 8, 10),
      paint,
    );

    // Glowing eyes
    final eyeColor = enemyType == 'heavy'
        ? const Color(0xFFFF4444)
        : const Color(0xFFFF00FF);

    final eyeY = 3.0;
    canvas.drawRect(
      Rect.fromLTWH(6, eyeY, 3, 3),
      Paint()..color = eyeColor,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x - 10, eyeY, 3, 3),
      Paint()..color = eyeColor,
    );

    // Health bar above enemy
    final healthPercent = health / maxHealth;
    final barWidth = size.x - 4;
    // Background
    canvas.drawRect(
      Rect.fromLTWH(2, -8, barWidth, 4),
      Paint()..color = const Color(0xFF333333),
    );
    // Fill
    canvas.drawRect(
      Rect.fromLTWH(2, -8, barWidth * healthPercent, 4),
      Paint()..color = const Color(0xFFFF3333),
    );
  }
}
