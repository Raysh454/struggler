import 'dart:ui';
import 'package:flame/components.dart';

import '../../config.dart';
import '../../struggler_game.dart';
import '../player.dart';

/// Expanding ring explosion spawned when a NightbornWarrior dies.
/// Deals splash damage once on spawn, then plays out the visual and removes itself.
class ExplosionEffect extends PositionComponent
    with HasGameReference<StruggleGame> {
  static const double _lifetime = 0.5;
  double _elapsed = 0;
  bool _hasDealtDamage = false;
  final double splashRadius;
  final double damage;

  ExplosionEffect({
    required Vector2 center,
    this.splashRadius = GameConfig.nightbornExplosionRadius,
    this.damage = GameConfig.nightbornExplosionDamage,
  }) : super(
          position: center - Vector2.all(splashRadius),
          size: Vector2.all(splashRadius * 2),
        );

  @override
  void update(double dt) {
    _elapsed += dt;

    // Deal damage exactly once on the first frame
    if (!_hasDealtDamage) {
      _hasDealtDamage = true;
      _trySplashPlayer();
    }

    if (_elapsed >= _lifetime) removeFromParent();
  }

  void _trySplashPlayer() {
    try {
      final player = parent?.children.whereType<Player>().firstOrNull;
      if (player == null) return;
      final dist = (player.position + player.size / 2) -
          (position + size / 2);
      if (dist.length <= splashRadius && !player.isInvincible) {
        player.receiveDamage(damage);
      }
    } catch (_) {}
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / _lifetime).clamp(0.0, 1.0);
    final currentRadius = splashRadius * progress;
    final alpha = (1.0 - progress);
    final center = Offset(size.x / 2, size.y / 2);

    // Outer ring
    canvas.drawCircle(
      center,
      currentRadius,
      Paint()
        ..color = Color.fromARGB(
            (200 * alpha).round(), 255, 100, 0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Inner fill flash
    canvas.drawCircle(
      center,
      currentRadius * 0.5,
      Paint()
        ..color = Color.fromARGB(
            (150 * alpha).round(), 255, 200, 50),
    );
  }
}
