/// Global game state tracking progression and session info.
class GameState {
  int currentLevel;
  final int maxLevels;
  bool isPaused;

  // Per-level timing
  DateTime? levelStartTime;
  final List<double> levelCompletionTimes; // seconds per level

  GameState({this.currentLevel = 1, this.maxLevels = 20})
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
    if (currentLevel <= 5) return 'awakening';
    if (currentLevel <= 14) return 'realization';
    if (currentLevel <= 20) return 'confrontation';
    return 'endless';
  }

  /// Is this a level with a fixed story dialogue?
  bool get hasFixedDialogue {
    return [1, 5, 10, 15, 20].contains(currentLevel);
  }
}
