/// Global game state tracking progression and session info.
class GameState {
  int currentLevel;
  final int maxLevels;
  bool isPaused;

  // Per-level timing
  DateTime? levelStartTime;
  final List<double> levelCompletionTimes; // seconds per level

  GameState({this.currentLevel = 0, this.maxLevels = 10})
    : isPaused = false,
      levelStartTime = null,
      levelCompletionTimes = [];

  void startLevel() {
    levelStartTime = DateTime.now();
  }

  double completeLevel() {
    final elapsed = levelStartTime != null
        ? DateTime.now().difference(levelStartTime!).inMilliseconds / 1000.0
        : 0.0;
    levelCompletionTimes.add(elapsed);
    currentLevel++;
    levelStartTime = null;
    return elapsed;
  }

  /// Which narrative arc are we in?
  String get narrativeArc {
    if (currentLevel == 0) return 'tutorial';
    if (currentLevel <= 3) return 'awakening';
    if (currentLevel <= 7) return 'realization';
    if (currentLevel <= 10) return 'confrontation';
    return 'endless';
  }

  /// Is this a level with a fixed story dialogue?
  bool get hasFixedDialogue {
    return [1, 3, 5, 7, 10].contains(currentLevel);
  }

  void reset() {
    currentLevel = 0;
    levelStartTime = null;
    levelCompletionTimes.clear();
  }
}
