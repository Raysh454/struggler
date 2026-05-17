import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/parallax.dart';
import '../asset_registry.dart';

enum ThemeType {
  lightRocks,
  darkRocks,
}

/// Contains all the visual assets required for a specific level theme.
class LevelTheme {
  static final Map<ThemeType, LevelTheme> _cache = {};

  final ThemeType type;
  
  // Background
  final String backgroundPath;

  // Blocks
  final List<Sprite> blockSprites;
  final List<Sprite> leftWallSprites;
  final List<Sprite> rightWallSprites;
  final List<Sprite> pillarSprites;
  final List<Sprite> leftEdgeSprites;
  final List<Sprite> rightEdgeSprites;
  final List<Sprite> bottomSprites;
  final List<Sprite> bottomLeftSprites;
  final List<Sprite> bottomRightSprites;
  
  // Decorations
  final List<Sprite> grassSprites;
  final List<Sprite> treeSprites;
  final List<Sprite> rockSprites;

  // Spikes and Lava
  final Sprite floorSpikeSprite;
  final Sprite ceilingSpikeSprite;
  final List<Sprite> lavaWaveSprites;
  final Sprite lavaFillSprite;

  /// Returns the 3 layers of background for this theme.
  List<ParallaxImageData> get backgroundAssets => [
    ParallaxImageData('blocks/RockyLevel/background1.png'), // Sky (back)
    ParallaxImageData('blocks/RockyLevel/background2.png'), // Far mountains
    ParallaxImageData('blocks/RockyLevel/background3.png'), // Near mountains
  ];

  LevelTheme({
    required this.type,
    required this.backgroundPath,
    required this.blockSprites,
    required this.leftWallSprites,
    required this.rightWallSprites,
    required this.pillarSprites,
    required this.leftEdgeSprites,
    required this.rightEdgeSprites,
    required this.bottomSprites,
    required this.bottomLeftSprites,
    required this.bottomRightSprites,
    required this.grassSprites,
    required this.treeSprites,
    required this.rockSprites,
    required this.floorSpikeSprite,
    required this.ceilingSpikeSprite,
    required this.lavaWaveSprites,
    required this.lavaFillSprite,
  });

  /// Loads and extracts sprites from the sprite sheets for the given theme.
  static Future<LevelTheme> load(FlameGame game, ThemeType type) async {
    if (_cache.containsKey(type)) return _cache[type]!;

    // Determine background
    String bgPath = type == ThemeType.lightRocks 
        ? 'blocks/RockyLevel/background1.png'
        : 'blocks/RockyLevel/background2.png';

    // --- Atlas Info ---
    const String atlasJson = 'assets/images/atlas/spritesheet.json';
    const String atlasImage = 'atlas/spritesheet.png';

    // --- Block Sprites from Atlas ---
    final List<Sprite> blockSprites = [];
    final List<Sprite> leftWallSprites = [];
    final List<Sprite> rightWallSprites = [];
    final List<Sprite> leftEdgeSprites = [];
    final List<Sprite> rightEdgeSprites = [];
    final List<Sprite> bottomSprites = [];
    final List<Sprite> bottomLeftSprites = [];
    final List<Sprite> bottomRightSprites = [];
    
    final int numVariations = type == ThemeType.lightRocks ? 4 : 3;
    final String prefix = type == ThemeType.lightRocks ? 'light_tile' : 'dark_tile';
    final String edgePrefix = type == ThemeType.lightRocks ? 'light_edge_tile' : 'dark_edge_tile';
    final String wallPrefix = type == ThemeType.lightRocks ? 'light_wall' : 'dark_wall';
    
    for (int i = 1; i <= numVariations; i++) {
      blockSprites.add(await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, '${prefix}_$i.png'));
    }

    leftEdgeSprites.add(await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, '${edgePrefix}_left.png'));
    rightEdgeSprites.add(await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, '${edgePrefix}_right.png'));

    leftWallSprites.add(await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, '${wallPrefix}_left_1.png'));
    leftWallSprites.add(await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, '${wallPrefix}_left_2.png'));
    rightWallSprites.add(await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, '${wallPrefix}_right_1.png'));
    rightWallSprites.add(await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, '${wallPrefix}_right_2.png'));

    final String bottomPrefix = type == ThemeType.lightRocks ? 'light_bottom' : 'dark_bottom';
    bottomSprites.add(await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, '${bottomPrefix}_tile.png'));
    bottomLeftSprites.add(await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, '${bottomPrefix}_left_tile.png'));
    bottomRightSprites.add(await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, '${bottomPrefix}_right_tile.png'));

    // --- Pillar Sprites from Atlas ---
    final List<Sprite> pillarSprites = [
      await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, 'deep_ground_1.png'),
      await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, 'deep_ground_2.png'),
      await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, 'deep_ground_3.png'),
    ];

    // --- Decorations from Atlas ---
    final grassSprites = [
      await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, 'dry_grass_top_1.png'),
      await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, 'dry_grass_top_2.png'),
    ];

    final treeSprites = [
      await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, 'cactus_multiple.png'),
      await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, 'cactus_long.png'),
    ];

    final rockSprites = [
      await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, 'rock_small_left.png'),
      await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, 'rock_small_right.png'),
      await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, 'rock_big_left.png'),
      await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, 'rock_big_right.png'),
    ];

    // --- Spikes & Lava ---
    final spikeSprite = await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, 'spikes.png');
    final List<Sprite> lavaWaveSprites = [];
    for (int i = 1; i <= 4; i++) {
      lavaWaveSprites.add(await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, 'lava_wave_$i.png'));
    }
    final lavaFill = await AssetRegistry.getSpriteFromAtlas(game, atlasJson, atlasImage, 'lava_fill02.png');

    final theme = LevelTheme(
      type: type,
      backgroundPath: bgPath,
      blockSprites: blockSprites,
      leftWallSprites: leftWallSprites,
      rightWallSprites: rightWallSprites,
      pillarSprites: pillarSprites,
      leftEdgeSprites: leftEdgeSprites,
      rightEdgeSprites: rightEdgeSprites,
      bottomSprites: bottomSprites,
      bottomLeftSprites: bottomLeftSprites,
      bottomRightSprites: bottomRightSprites,
      grassSprites: grassSprites,
      treeSprites: treeSprites,
      rockSprites: rockSprites,
      floorSpikeSprite: spikeSprite,
      ceilingSpikeSprite: spikeSprite,
      lavaWaveSprites: lavaWaveSprites,
      lavaFillSprite: lavaFill,
    );
    _cache[type] = theme;
    return theme;
  }
}
