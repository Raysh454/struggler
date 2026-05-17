import 'dart:convert';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';


/// Centralized registry for all game assets to ensure efficient reuse and caching.
class AssetRegistry {
  static final Map<String, SpriteAnimation> _animationCache = {};
  static final Map<String, Sprite> _spriteCache = {};
  static final Map<String, Map<String, dynamic>> _atlasData = {};

  /// Loads a TexturePacker JSON atlas data.
  static Future<void> loadAtlas(String jsonPath) async {
    if (_atlasData.containsKey(jsonPath)) return;
    final jsonString = await rootBundle.loadString(jsonPath);
    final data = jsonDecode(jsonString);
    _atlasData[jsonPath] = data['frames'];
  }

  /// Gets a Sprite from a loaded atlas.
  static Future<Sprite> getSpriteFromAtlas(FlameGame game, String atlasJsonPath, String atlasImagePath, String frameName) async {
    final key = '$atlasJsonPath-$frameName';
    if (_spriteCache.containsKey(key)) return _spriteCache[key]!;

    if (!_atlasData.containsKey(atlasJsonPath)) {
      await loadAtlas(atlasJsonPath);
    }

    final frames = _atlasData[atlasJsonPath]!;
    if (!frames.containsKey(frameName)) {
      throw Exception('Frame $frameName not found in atlas $atlasJsonPath');
    }

    final frameData = frames[frameName]['frame'];
    final image = await game.images.load(atlasImagePath);
    
    final sprite = Sprite(
      image,
      srcPosition: Vector2(frameData['x'].toDouble(), frameData['y'].toDouble()),
      srcSize: Vector2(frameData['w'].toDouble(), frameData['h'].toDouble()),
    );
    
    _spriteCache[key] = sprite;
    return sprite;
  }

  /// Gets or loads a SpriteAnimation from an atlas.
  static Future<SpriteAnimation> getAnimationFromAtlas(
    FlameGame game,
    String atlasJsonPath,
    String atlasImagePath,
    String frameName, {
    required int amount,
    required int amountPerRow,
    required Vector2 textureSize,
    required double stepTime,
    bool loop = true,
    int startRow = 0,
    int startCol = 0,
    String? key,
  }) async {
    final cacheKey = key ?? '$atlasJsonPath-$frameName';
    if (_animationCache.containsKey(cacheKey)) return _animationCache[cacheKey]!;

    if (!_atlasData.containsKey(atlasJsonPath)) {
      await loadAtlas(atlasJsonPath);
    }

    final frames = _atlasData[atlasJsonPath]!;
    if (!frames.containsKey(frameName)) {
      throw Exception('Frame $frameName not found in atlas $atlasJsonPath');
    }

    final frameData = frames[frameName]['frame'];
    final image = await game.images.load(atlasImagePath);
    
    final startX = frameData['x'].toDouble();
    final startY = frameData['y'].toDouble();

    final List<Sprite> sprites = [];
    for (int i = 0; i < amount; i++) {
      final int relativeRow = i ~/ amountPerRow;
      final int relativeCol = i % amountPerRow;
      
      final int row = startRow + relativeRow;
      final int col = startCol + relativeCol;
      
      sprites.add(Sprite(
        image,
        srcPosition: Vector2(startX + col * textureSize.x, startY + row * textureSize.y),
        srcSize: textureSize,
      ));
    }
    
    final animation = SpriteAnimation.spriteList(sprites, stepTime: stepTime, loop: loop);
    _animationCache[cacheKey] = animation;
    return animation;
  }

  /// Gets or loads a SpriteAnimation. Ensures only one instance exists in memory.
  static Future<SpriteAnimation> getAnimation(
    FlameGame game,
    String path,
    SpriteAnimationData data, {
    String? key,
  }) async {
    final cacheKey = key ?? path;
    if (_animationCache.containsKey(cacheKey)) return _animationCache[cacheKey]!;

    final image = await game.images.load(path);
    final animation = SpriteAnimation.fromFrameData(image, data);
    _animationCache[cacheKey] = animation;
    return animation;
  }

  /// Gets or loads a Sprite.
  static Future<Sprite> getSprite(FlameGame game, String path, {Vector2? srcPosition, Vector2? srcSize}) async {
    final key = '$path-${srcPosition?.x}-${srcPosition?.y}-${srcSize?.x}-${srcSize?.y}';
    if (_spriteCache.containsKey(key)) return _spriteCache[key]!;

    final image = await game.images.load(path);
    final sprite = Sprite(image, srcPosition: srcPosition, srcSize: srcSize);
    _spriteCache[key] = sprite;
    return sprite;
  }

  /// Loads a [SpriteAnimation] from sequentially-numbered individual PNG files.
  ///
  /// Example: pathPrefix = 'characters/bringer/IndividualSprite/Idle/Bringer-of-Death_Idle_'
  ///          ext = '.png', frameCount = 8  →  loads _1.png … _8.png
  static Future<SpriteAnimation> getAnimationFromFrameSequence(
    FlameGame game,
    String pathPrefix,
    String ext,
    int frameCount, {
    required double stepTime,
    bool loop = true,
    String? key,
  }) async {
    final cacheKey = key ?? '${pathPrefix}seq$frameCount';
    if (_animationCache.containsKey(cacheKey)) return _animationCache[cacheKey]!;

    final sprites = <Sprite>[];
    for (int i = 1; i <= frameCount; i++) {
      final image = await game.images.load('$pathPrefix$i$ext');
      sprites.add(Sprite(image));
    }

    final anim = SpriteAnimation.spriteList(sprites, stepTime: stepTime, loop: loop);
    _animationCache[cacheKey] = anim;
    return anim;
  }

  /// Clears the cache. Call this when switching themes or major game states if memory is tight.
  static void clear() {
    _animationCache.clear();
    _spriteCache.clear();
    _atlasData.clear();
  }
}

