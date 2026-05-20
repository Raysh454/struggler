import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';

/// Swirling particle burst used by the Architect's teleport sequence.
/// Spawned at a world position; self-removes after [_lifetime] seconds.
class TeleportEffect extends PositionComponent {
  static const double _lifetime  = 0.45;
  static const int    _numParticles = 10;
  static const double _maxRadius   = 40.0;

  double _elapsed = 0;
  final _rng = Random();

  // Pre-generated per-particle data so each frame is deterministic
  final List<double> _angles  = [];
  final List<double> _speeds  = [];
  final List<double> _sizes   = [];
  final List<Color>  _colors  = [];

  TeleportEffect({required Vector2 center})
      : super(
          position: center - Vector2.all(_maxRadius),
          size: Vector2.all(_maxRadius * 2),
        ) {
    for (int i = 0; i < _numParticles; i++) {
      _angles.add(_rng.nextDouble() * 2 * pi);
      _speeds.add(60 + _rng.nextDouble() * 80);
      _sizes.add(3 + _rng.nextDouble() * 5);
      _colors.add(_rng.nextBool()
          ? const Color(0xFFBB86FC) // purple
          : const Color(0xFFFFFFFF));
    }
  }

  @override
  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= _lifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / _lifetime).clamp(0.0, 1.0);
    final alpha    = (1.0 - progress);
    final origin   = Offset(size.x / 2, size.y / 2);

    for (int i = 0; i < _numParticles; i++) {
      final dist = _speeds[i] * progress;
      final dx = cos(_angles[i]) * dist;
      final dy = sin(_angles[i]) * dist;
      final col = _colors[i];
      final particleColor = col.withValues(alpha: col.a * alpha);

      canvas.drawCircle(
        origin + Offset(dx, dy),
        _sizes[i] * (1 - progress * 0.6),
        Paint()
          ..color = particleColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }
}
