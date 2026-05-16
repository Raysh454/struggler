import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:struggler/game/components/block.dart';
import 'dart:ui';
import 'dart:math';

/// Lava hazard. Damages the player on contact and has a pulsing glow.
class Lava extends PositionComponent with CollisionCallbacks {
  final double damage;
  double _glowTimer = 0;
  bool isOnGround = false;
  Vector2 velocity = Vector2.zero();

  static const double gravity = 1200.0;
  static const double maxFallSpeed = 1000.0;

  Lava({
    required Vector2 position,
    required Vector2 size,
    this.damage = 15.0,
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    _glowTimer += dt * 3;

    _applyGravity(dt);
    _applyVelocity(dt);

    isOnGround = false;
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
    if (position.y > 1000) {
      _die();
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
    final playerRect = toRect();
    final blockRect = block.toRect();

    final double overlapTop = playerRect.bottom - blockRect.top;
  
    if (overlapTop > 0 && velocity.y > 0) {
      velocity.y = 0;
      position.y -= overlapTop;
      isOnGround = true;
    }
  }

  void _die() {
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    // Animated lava with pulsing glow
    final pulse = (sin(_glowTimer) * 0.3 + 0.7);
    final r = (255 * pulse).round().clamp(0, 255);

    canvas.drawRect(
      size.toRect(),
      Paint()..color = Color.fromARGB(255, r, 60, 0),
    );

    // Bright top surface
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, 3),
      Paint()..color = Color.fromARGB(200, 255, (150 * pulse).round(), 0),
    );
  }
}
