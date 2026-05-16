import 'package:flame/components.dart';

/// A purely visual component that has no collisions or logic.
/// Used for grass, small rocks, and background trees on platforms.
class DecorationComponent extends SpriteComponent {
  DecorationComponent({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
    Anchor anchor = Anchor.topLeft,
  }) : super(
          sprite: sprite,
          position: position,
          size: size,
          anchor: anchor,
        );
}
