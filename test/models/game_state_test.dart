import 'package:flutter_test/flutter_test.dart';
import 'package:struggler/models/game_state.dart';

void main() {
  group('GameState', () {
    late GameState state;

    setUp(() {
      state = GameState();
    });

    group('initialization', () {
      test('starts at level 1 with 20 max levels', () {
        expect(state.currentLevel, 1);
        expect(state.maxLevels, 20);
        expect(state.isPaused, false);
      });

      test('starts with empty completion times', () {
        expect(state.levelCompletionTimes, isEmpty);
      });

      test('accepts custom initial values', () {
        final custom = GameState(currentLevel: 5, maxLevels: 10);
        expect(custom.currentLevel, 5);
        expect(custom.maxLevels, 10);
      });
    });

    group('narrativeArc', () {
      test('levels 1-5 are awakening', () {
        for (int i = 1; i <= 5; i++) {
          state.currentLevel = i;
          expect(state.narrativeArc, 'awakening',
              reason: 'Level $i should be awakening');
        }
      });

      test('levels 6-14 are realization', () {
        for (int i = 6; i <= 14; i++) {
          state.currentLevel = i;
          expect(state.narrativeArc, 'realization',
              reason: 'Level $i should be realization');
        }
      });

      test('levels 15-20 are confrontation', () {
        for (int i = 15; i <= 20; i++) {
          state.currentLevel = i;
          expect(state.narrativeArc, 'confrontation',
              reason: 'Level $i should be confrontation');
        }
      });

      test('levels beyond 20 are endless', () {
        state.currentLevel = 21;
        expect(state.narrativeArc, 'endless');
        state.currentLevel = 50;
        expect(state.narrativeArc, 'endless');
      });
    });

    group('hasFixedDialogue', () {
      test('fixed dialogues at levels 1, 5, 10, 15, 20', () {
        for (final level in [1, 5, 10, 15, 20]) {
          state.currentLevel = level;
          expect(state.hasFixedDialogue, true,
              reason: 'Level $level should have fixed dialogue');
        }
      });

      test('no fixed dialogue at other levels', () {
        for (final level in [2, 3, 4, 6, 7, 8, 9, 11, 12, 13, 14, 16, 17, 18, 19]) {
          state.currentLevel = level;
          expect(state.hasFixedDialogue, false,
              reason: 'Level $level should NOT have fixed dialogue');
        }
      });
    });

    group('level timing', () {
      test('startLevel records start time', () {
        expect(state.levelStartTime, isNull);
        state.startLevel();
        expect(state.levelStartTime, isNotNull);
      });

      test('completeLevel increments level and records time', () {
        state.startLevel();
        // Small delay isn't needed — any duration will be recorded
        final elapsed = state.completeLevel();
        expect(elapsed, greaterThanOrEqualTo(0));
        expect(state.currentLevel, 2);
        expect(state.levelCompletionTimes, hasLength(1));
        expect(state.levelStartTime, isNull); // Reset after completion
      });

      test('completeLevel returns 0 if startLevel was not called', () {
        final elapsed = state.completeLevel();
        expect(elapsed, 0.0);
        expect(state.currentLevel, 2);
      });

      test('multiple completions accumulate times', () {
        state.startLevel();
        state.completeLevel();
        state.startLevel();
        state.completeLevel();
        state.startLevel();
        state.completeLevel();
        expect(state.currentLevel, 4);
        expect(state.levelCompletionTimes, hasLength(3));
      });
    });
  });
}
