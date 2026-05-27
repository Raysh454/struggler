import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../struggler_game.dart';

/// A custom joystick component that snaps to the user's touch location
/// when touched anywhere in the bottom-left area of the screen,
/// and returns to its default position when released.
class SnappingJoystick extends JoystickComponent {
  final Vector2 defaultPosition;
  final double backgroundRadius;
  final double detectionWidth;
  final double detectionHeight;

  SnappingJoystick({
    required super.knob,
    required super.background,
    required this.defaultPosition,
    this.backgroundRadius = 60.0,
    this.detectionWidth = 500.0,
    this.detectionHeight = 350.0,
  }) : super(position: defaultPosition.clone(), anchor: Anchor.center);

  StruggleGame get struggleGame => game as StruggleGame;

  @override
  bool containsLocalPoint(Vector2 point) {
    // With size=zero and anchor=center, local = parent - position,
    // so parent = local + position. This gives us viewport coordinates.
    final parentPoint = position + point;

    // Check if touch is in the bottom-left zone of the viewport.
    // No strict outer bounds (y <= viewportSize.y) so bezel-edge touches register.
    final viewportSize = struggleGame.size;
    return parentPoint.x <= detectionWidth &&
        parentPoint.y >= viewportSize.y - detectionHeight;
  }

  int? _activePointerId;

  @override
  bool onDragStart(DragStartEvent event) {
    super.onDragStart(event);

    if (_activePointerId != null) return true;
    _activePointerId = event.pointerId;

    // Convert canvas (global) position to parent (viewport) coordinates.
    final touchParentPos =
        (parent as dynamic).globalToLocal(event.canvasPosition) as Vector2;

    // Snap joystick center to touch point, clamped to keep background visible.
    final viewportSize = struggleGame.size;
    position.x = touchParentPos.x.clamp(
      backgroundRadius,
      viewportSize.x - backgroundRadius,
    );
    position.y = touchParentPos.y.clamp(
      backgroundRadius,
      viewportSize.y - backgroundRadius,
    );

    // Reset knob to center
    knob?.position = Vector2.zero();
    relativeDelta.setZero();

    return true;
  }

  @override
  bool onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);

    if (event.pointerId != _activePointerId) return true;

    // Convert current touch to parent (viewport) coordinates.
    final touchParentPos =
        (parent as dynamic).globalToLocal(event.canvasEndPosition) as Vector2;
    final offset = touchParentPos - position;
    final distance = offset.length;

    if (distance <= backgroundRadius) {
      knob?.position = offset;
    } else {
      knob?.position = offset.normalized() * backgroundRadius;
    }

    relativeDelta.setFrom(
      (knob?.position ?? Vector2.zero()) / backgroundRadius,
    );

    return true;
  }

  @override
  bool onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);

    if (event.pointerId != _activePointerId) return true;
    _activePointerId = null;
    _resetToDefault();

    return true;
  }

  @override
  bool onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);

    if (event.pointerId != _activePointerId) return true;
    _activePointerId = null;
    _resetToDefault();

    return true;
  }

  void _resetToDefault() {
    position.setFrom(defaultPosition);
    knob?.position = Vector2.zero();
    relativeDelta.setZero();
  }
}
