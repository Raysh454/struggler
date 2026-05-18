import 'package:flutter_test/flutter_test.dart';
import 'package:struggler/game/level/level_data.dart';

void main() {
  group('LevelData JSON Serialization', () {
    test('TileData fromJson/toJson', () {
      final json = {'type': 'block', 'x': 10.0, 'y': 20.0, 'w': 2.0, 'h': 1.0};
      final tile = TileData.fromJson(json);
      expect(tile.type, 'block');
      expect(tile.x, 10.0);
      expect(tile.toJson(), json);
    });

    test('EnemyData fromJson/toJson', () {
      final json = {
        'x': 5.0,
        'y': 5.0,
        'health': 50.0,
        'damage': 10.0,
        'speed': 1.0,
        'type': 'basic',
        'patrol_range': 3.0
      };
      final enemy = EnemyData.fromJson(json);
      expect(enemy.type, 'basic');
      expect(enemy.toJson(), json);
    });

    test('LevelData fromJson/toJson full roundtrip', () {
      final levelJson = {
        'level_id': 1,
        'difficulty': 0.5,
        'width': 100,
        'height': 50,
        'spawn': {'x': 10.0, 'y': 10.0},
        'exit': {'x': 90.0, 'y': 10.0},
        'tiles': [
          {'type': 'block', 'x': 0.0, 'y': 0.0, 'w': 10.0, 'h': 10.0}
        ],
        'enemies': [
          {
            'x': 20.0,
            'y': 20.0,
            'health': 100.0,
            'damage': 20.0,
            'speed': 1.5,
            'type': 'heavy',
            'patrol_range': 5.0
          }
        ],
        'pickups': [
          {'type': 'health', 'x': 30.0, 'y': 30.0}
        ],
        'architect_dialogue': 'Test dialogue',
        'narrativeEvents': [],
        'enemyDamageMultiplier': null,
        'enemyHealthMultiplier': null
      };

      final levelData = LevelData.fromJson(levelJson);
      expect(levelData.levelId, 1);
      expect(levelData.tiles.first.type, 'block');
      expect(levelData.enemies.first.type, 'heavy');
      expect(levelData.toJson(), levelJson);
    });

    test('LevelData.fromJsonString', () {
      const jsonStr = '{"level_id": 1, "spawn": {"x": 0, "y": 0}, "exit": {"x": 1, "y": 1}, "tiles": []}';
      final levelData = LevelData.fromJsonString(jsonStr);
      expect(levelData.levelId, 1);
    });
  });
}
