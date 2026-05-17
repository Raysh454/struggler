import '../game/config.dart';

/// Tracks all mutable player state across the game session.
class PlayerState {
  // --- Health ---
  double maxHealth;
  double health;

  // --- Resolve ---
  double maxResolve;
  double resolve;
  bool isIndomitable; // Active when resolve is full and triggered

  // --- Combat ---
  double swordDamage;
  int perfectDodges;

  // --- Upgrades (spent at Guardian) ---
  int oreCollected;
  int willpower; // Meta-currency earned on level completion

  // --- Session stats ---
  int deathCount;
  int currentLevel;
  int enemiesKilled;

  PlayerState({
    this.maxHealth = GameConfig.playerMaxHealthDefault,
    this.maxResolve = GameConfig.playerMaxResolveDefault,
    this.swordDamage = GameConfig.playerSwordDamageDefault,
    this.oreCollected = 0,
    this.willpower = 0,
    this.currentLevel = 1,
  })  : health = maxHealth,
        resolve = 0.0,
        isIndomitable = false,
        perfectDodges = 0,
        deathCount = 0,
        enemiesKilled = 0;

  /// Reset health/resolve for a new level attempt (after death).
  void resetForRetry() {
    health = maxHealth;
    resolve = 0;
    isIndomitable = false;
  }

  /// Add resolve. Returns true if Indomitable is now available.
  bool addResolve(double amount) {
    resolve = (resolve + amount).clamp(0, maxResolve);
    return resolve >= maxResolve;
  }

  /// Take damage. Returns true if the player died.
  bool takeDamage(double amount) {
    if (isIndomitable) amount /= 2; // Half damage in Indomitable state
    health = (health - amount).clamp(0, maxHealth);
    return health <= 0;
  }

  /// Heal the player.
  void heal(double amount) {
    health = (health + amount).clamp(0, maxHealth);
  }

  /// Get effective sword damage (doubled in Indomitable state).
  double get effectiveDamage => isIndomitable ? swordDamage * 2 : swordDamage;

  /// Telemetry snapshot for The Architect AI.
  Map<String, dynamic> toTelemetry() {
    return {
      'health_percent': (health / maxHealth * 100).round(),
      'resolve_percent': (resolve / maxResolve * 100).round(),
      'death_count': deathCount,
      'current_level': currentLevel,
      'enemies_killed': enemiesKilled,
      'perfect_dodges': perfectDodges,
      'ore_collected': oreCollected,
    };
  }
}
