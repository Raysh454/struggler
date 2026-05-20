import 'dart:ui';
import 'package:flame/components.dart';

import '../../asset_registry.dart';
import '../../config.dart';
import '../../systems/audio_manager.dart';
import '../player.dart';
import '../projectile.dart';
import 'arcane_archer_enemy.dart'; // reuse RangedEnemy base

enum _WAnim { idle, attack, death, fly }

/// Slow-moving spellcaster that fires sinusoidal orbs.
/// Wizard idle: 800×80 sheet → 10 frames at 80×80
/// Wizard attack: 640×160 sheet → 9 frames at 80×80
/// Wizard death:  800×80 sheet → 10 frames at 80×80
/// Wizard fly:    480×80 sheet → 6 frames at 80×80
class WizardEnemy extends RangedEnemy {
  SpriteAnimationGroupComponent<_WAnim>? _animGroup;
  _WAnim _current = _WAnim.idle;
  bool _spriteLoaded = false;
  bool _orbFired = false;

  WizardEnemy({
    required super.position,
  }) : super(
          size: GameConfig.enemyHitboxWizard,
          maxHealth: GameConfig.enemyHealthWizard,
          contactDamage: GameConfig.enemyDamageWizard,
          speed: GameConfig.enemySpeedWizard,
          aggroRange: GameConfig.enemyAggroRangeWizard,
          fireCooldown: GameConfig.enemyWizardFireCooldown,
        );

  @override
  int get willpowerReward => GameConfig.enemyWillWizard;

  @override
  double get resolveReward => GameConfig.enemyResolveWizard;

  @override
  double get healthBarYOffset => GameConfig.enemyHealthBarYOffsetWizard;

  static final Vector2 _renderSize = GameConfig.enemySizeWizard;

  @override
  bool get defaultSpriteFacesLeft => true;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final idle = await AssetRegistry.getAnimation(
        game,
        'characters/wizard/wizard idle.png',
        SpriteAnimationData.sequenced(amount: 10, stepTime: 0.12, textureSize: Vector2(80, 80)),
        key: 'wiz/idle',
      );

      // Load multi-row attack animation frames from the 640x160 sheet
      // Top row: 7 active frames (0-6). Bottom row: 2 active frames (0-1 of row 2)
      final attackImg = await game.images.load('characters/wizard/wizard attack.png');
      final List<Sprite> attackSprites = [];
      for (int i = 0; i < 7; i++) {
        attackSprites.add(Sprite(attackImg, srcPosition: Vector2(i * 80.0, 0), srcSize: Vector2(80, 80)));
      }
      for (int i = 0; i < 2; i++) {
        attackSprites.add(Sprite(attackImg, srcPosition: Vector2(i * 80.0, 80.0), srcSize: Vector2(80, 80)));
      }
      final attack = SpriteAnimation.spriteList(attackSprites, stepTime: 0.10, loop: false);

      final death = await AssetRegistry.getAnimation(
        game,
        'characters/wizard/wizard death.png',
        SpriteAnimationData.sequenced(amount: 10, stepTime: 0.10, textureSize: Vector2(80, 80), loop: false),
        key: 'wiz/death',
      );

      final fly = await AssetRegistry.getAnimation(
        game,
        'characters/wizard/wizard fly forward.png',
        SpriteAnimationData.sequenced(amount: 6, stepTime: 0.12, textureSize: Vector2(80, 80)),
        key: 'wiz/fly',
      );

      _animGroup = SpriteAnimationGroupComponent<_WAnim>(
        animations: {
          _WAnim.idle: idle,
          _WAnim.attack: attack,
          _WAnim.death: death,
          _WAnim.fly: fly,
        },
        current: _WAnim.idle,
        size: _renderSize, // Perfect, unified 64x64 size
        position: Vector2(size.x / 2, size.y + GameConfig.enemyYOffsetWizard),
        anchor: Anchor.bottomCenter,
      );
      add(_animGroup!);
      animComp = _animGroup;
      _spriteLoaded = true;
    } catch (_) {}
  }

  void _setAnimation(_WAnim anim) {
    if (!_spriteLoaded || _animGroup == null) return;
    _current = anim;
    _animGroup!.current = anim;
    _animGroup!.animationTickers?[anim]?.reset();
  }

  @override
  void fireProjectile(Player player) {
    if (_spriteLoaded) {
      _orbFired = false; // Reset trigger flag for the new cast!
      _setAnimation(_WAnim.attack);
    }
  }

  void _spawnOrb() {
    final player = _player();
    if (player == null) return;

    final spawnPos = Vector2(
      position.x + (facingDirection == 1 ? size.x : -16),
      position.y + size.y * 0.4,
    );

    final playerCenter = player.position + player.size / 2;
    final targetVector = (playerCenter - spawnPos).normalized();

    parent?.add(OrbProjectile(
      position: spawnPos,
      direction: facingDirection,
      targetVector: targetVector,
    ));
    AudioManager.playSfx(AudioManager.sfxFireball);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_spriteLoaded || isDead) return;
    if (game.isCutscenePlaying) return;

    final ticker = _animGroup!.animationTickers?[_WAnim.attack];
    if (_current == _WAnim.attack && ticker != null) {
      // Fire orb right at the end of the spellcasting hand raise (frame index 7 of 9)
      if (ticker.currentIndex >= 7 && !_orbFired) {
        _spawnOrb();
        _orbFired = true;
      }
      if (ticker.done()) {
        _setAnimation(_WAnim.idle);
      }
    }

    if (_current != _WAnim.attack) {
      final newAnim = isMoving ? _WAnim.fly : _WAnim.idle;
      if (newAnim != _current) {
        _setAnimation(newAnim);
      }
    }
  }

  Player? _player() =>
      parent?.children.whereType<Player>().firstOrNull;

  @override
  void interruptAttack() {
    _setAnimation(_WAnim.idle);
    _orbFired = true; // Prevent orb spawning!
  }

  @override
  bool takeDamage(double damage, {bool isPlunge = false}) {
    if (isDead) return false;
    final fatal = super.takeDamage(damage, isPlunge: isPlunge);
    if (!fatal) {
      hurtTimer = GameConfig.enemyWizardHurtDuration;

      final player = playerTarget;
      if (player != null) {
        final pushDir = (position.x + size.x / 2) > (player.position.x + player.size.x / 2) ? 1.0 : -1.0;
        stagger(pushDir * GameConfig.enemyWizardStaggerForce);
      }
    }
    return fatal;
  }

  @override
  void onDeath() {
    _setAnimation(_WAnim.death);
    Future.delayed(const Duration(milliseconds: 1000), () => removeFromParent());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!_spriteLoaded) renderPlaceholder(canvas, const Color(0xFF1A1A8C));
  }
}
