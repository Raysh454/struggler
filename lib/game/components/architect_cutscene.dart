import 'package:flame/components.dart';
import 'dart:ui';
import '../struggler_game.dart';
import 'dialogue_bubble.dart';

class ArchitectCutsceneEntity extends PositionComponent with HasGameRef<StruggleGame> {
  final String dialogue;
  SpriteAnimationComponent? _animComp;
  late final Timer _timer;

  ArchitectCutsceneEntity({
    required Vector2 position,
    required this.dialogue,
  }) : super(position: position, size: Vector2(112, 120)) {
    anchor = Anchor.center;
    // 5 seconds cutscene duration
    _timer = Timer(5.0, onTick: _endCutscene, repeat: false);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    try {
      final image = await gameRef.images.load('characters/architect/idle.png');
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

    // Add dialogue bubble
    add(DialogueBubble(
      text: dialogue,
      duration: 4.5,
    )..position = Vector2(size.x / 2 - 20, -10)); // Above head
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timer.update(dt);
  }

  void _endCutscene() {
    gameRef.isCutscenePlaying = false;
    removeFromParent();
  }
}
