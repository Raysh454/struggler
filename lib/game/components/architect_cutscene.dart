import 'package:flame/components.dart';
import 'dart:ui';
import 'package:flutter/painting.dart'
    show TextPainter, TextSpan, TextStyle, TextDirection, FontWeight;
import '../struggler_game.dart';
import 'dialogue_bubble.dart';

class ArchitectCutsceneEntity extends PositionComponent
    with HasGameReference<StruggleGame> {
  final String dialogue;
  SpriteAnimationComponent? _animComp;
  double _elapsed = 0;
  static const double _minDisplayTime =
      0.5; // Minimum time before skip is allowed
  bool _canSkip = false;

  // "Press E to skip" prompt
  late final TextPainter _skipPromptPainter;

  ArchitectCutsceneEntity({required Vector2 position, required this.dialogue})
    : super(position: position, size: Vector2(112, 120)) {
    anchor = Anchor.center;

    _skipPromptPainter = TextPainter(
      text: const TextSpan(
        text: 'Interact to Skip',
        style: TextStyle(
          color: Color(0xAAFFFFFF),
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    _skipPromptPainter.layout();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      final image = await game.images.load('characters/architect/idle.png');
      final anim = SpriteAnimation.spriteList(
        List.generate(
          15,
          (i) => Sprite(
            image,
            srcPosition: Vector2(i * 224.0, 0),
            srcSize: Vector2(224.0, 240.0),
          ),
        ),
        stepTime: 0.07,
      );
      _animComp = SpriteAnimationComponent(
        animation: anim,
        size: size,
        anchor: Anchor.center,
        position: size / 2,
      );
      add(_animComp!);
    } catch (e) {
      print('Failed to load architect sprite: $e');
    }

    // Add dialogue bubble (no auto-dismiss duration — stays until skipped)
    add(
      DialogueBubble(
        text: dialogue,
        duration:
            999, // Effectively infinite — removed when cutscene is skipped
        isStatic: true,
      )..position = Vector2(size.x / 2 - 20, -35),
    ); // Above head
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _minDisplayTime) {
      _canSkip = true;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw "Press E to skip" prompt below the entity once skippable
    if (_canSkip) {
      final promptX = size.x / 2 - _skipPromptPainter.width / 2;
      _skipPromptPainter.paint(canvas, Offset(promptX, size.y + 5));
    }
  }

  /// Called externally to end the cutscene.
  void endCutscene() {
    game.isCutscenePlaying = false;
    removeFromParent();
  }
}
