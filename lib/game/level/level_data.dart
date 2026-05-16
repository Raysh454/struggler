import 'dart:convert';

/// Represents a single tile/object in the level blueprint.
class TileData {
  final String type; // 'block', 'lava', 'spike'
  final double x;
  final double y;
  final double w;
  final double h;

  TileData({
    required this.type,
    required this.x,
    required this.y,
    this.w = 1,
    this.h = 1,
  });

  factory TileData.fromJson(Map<String, dynamic> json) {
    return TileData(
      type: json['type'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      w: (json['w'] as num?)?.toDouble() ?? 1,
      h: (json['h'] as num?)?.toDouble() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
      };
}

/// Represents an enemy in the level blueprint.
class EnemyData {
  final double x;
  final double y;
  final double health;
  final double damage;
  final double speed;
  final String type; // 'basic', 'heavy', 'fast'
  final double patrolRange;

  EnemyData({
    required this.x,
    required this.y,
    this.health = 50,
    this.damage = 10,
    this.speed = 1.0,
    this.type = 'basic',
    this.patrolRange = 3.0,
  });

  factory EnemyData.fromJson(Map<String, dynamic> json) {
    return EnemyData(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      health: (json['health'] as num?)?.toDouble() ?? 50,
      damage: (json['damage'] as num?)?.toDouble() ?? 10,
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      type: json['type'] as String? ?? 'basic',
      patrolRange: (json['patrol_range'] as num?)?.toDouble() ?? 3.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'health': health,
        'damage': damage,
        'speed': speed,
        'type': type,
        'patrol_range': patrolRange,
      };
}

/// Represents a pickup item in the level blueprint.
class PickupData {
  final String type; // 'health', 'ore'
  final double x;
  final double y;

  PickupData({
    required this.type,
    required this.x,
    required this.y,
  });

  factory PickupData.fromJson(Map<String, dynamic> json) {
    return PickupData(
      type: json['type'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'x': x,
        'y': y,
      };
}

/// The complete level blueprint — this is what The Architect AI generates.
class LevelData {
  final int levelId;
  final double difficulty; // 0.0 to 1.0
  final int width; // in grid tiles
  final int height; // in grid tiles
  final ({double x, double y}) spawn;
  final ({double x, double y}) exit;
  final List<TileData> tiles;
  final List<EnemyData> enemies;
  final List<PickupData> pickups;
  final String? architectDialogue; // What the Architect says at level start

  LevelData({
    required this.levelId,
    this.difficulty = 0.3,
    this.width = 50,
    this.height = 20,
    required this.spawn,
    required this.exit,
    required this.tiles,
    this.enemies = const [],
    this.pickups = const [],
    this.architectDialogue,
  });

  factory LevelData.fromJson(Map<String, dynamic> json) {
    final spawnJson = json['spawn'] as Map<String, dynamic>;
    final exitJson = json['exit'] as Map<String, dynamic>;

    return LevelData(
      levelId: json['level_id'] as int,
      difficulty: (json['difficulty'] as num?)?.toDouble() ?? 0.3,
      width: json['width'] as int? ?? 50,
      height: json['height'] as int? ?? 20,
      spawn: (
        x: (spawnJson['x'] as num).toDouble(),
        y: (spawnJson['y'] as num).toDouble(),
      ),
      exit: (
        x: (exitJson['x'] as num).toDouble(),
        y: (exitJson['y'] as num).toDouble(),
      ),
      tiles: (json['tiles'] as List<dynamic>)
          .map((t) => TileData.fromJson(t as Map<String, dynamic>))
          .toList(),
      enemies: (json['enemies'] as List<dynamic>?)
              ?.map((e) => EnemyData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pickups: (json['pickups'] as List<dynamic>?)
              ?.map((p) => PickupData.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      architectDialogue: json['architect_dialogue'] as String?,
    );
  }

  factory LevelData.fromJsonString(String jsonString) {
    return LevelData.fromJson(
        json.decode(jsonString) as Map<String, dynamic>);
  }

  Map<String, dynamic> toJson() => {
        'level_id': levelId,
        'difficulty': difficulty,
        'width': width,
        'height': height,
        'spawn': {'x': spawn.x, 'y': spawn.y},
        'exit': {'x': exit.x, 'y': exit.y},
        'tiles': tiles.map((t) => t.toJson()).toList(),
        'enemies': enemies.map((e) => e.toJson()).toList(),
        'pickups': pickups.map((p) => p.toJson()).toList(),
        'architect_dialogue': architectDialogue,
      };
}
