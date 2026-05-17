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

  // --- Stamina ---
  double maxStamina;
  double stamina;

  // --- Combat ---
  double swordDamage;
  int perfectDodges;

  // --- Upgrades (spent at Guardian) ---
  int diamondsCollected;
  int willpower; // Meta-currency earned on level completion

  // Upgrade Levels (Starts at 1)
  int healthUpgradeLevel;
  int resolveUpgradeLevel;
  int staminaUpgradeLevel;
  int swordUpgradeLevel;

  // --- Lost Will (Death Mechanics) ---
  int lostWillpower = 0;
  double? lostWillX;
  double? lostWillY;
  int? lostWillLevelId;

  // --- Session stats ---
  int deathCount;
  int currentLevel;
  int enemiesKilled;

  PlayerState({
    this.maxHealth = GameConfig.playerMaxHealthDefault,
    this.maxResolve = GameConfig.playerMaxResolveDefault,
    this.maxStamina = GameConfig.playerMaxStaminaDefault,
    this.swordDamage = GameConfig.playerSwordDamageDefault,
    this.diamondsCollected = 0,
    this.willpower = 0,
    this.currentLevel = 1,
    this.healthUpgradeLevel = 1,
    this.resolveUpgradeLevel = 1,
    this.staminaUpgradeLevel = 1,
    this.swordUpgradeLevel = 1,
  })  : health = maxHealth,
        resolve = 0.0,
        isIndomitable = false,
        stamina = maxStamina,
        perfectDodges = 0,
        deathCount = 0,
        enemiesKilled = 0;

  // --- Upgrade Cost Calculations ---
  // Cost = 100 * 2^(level - 1)
  int get healthUpgradeCost => 100 * (1 << (healthUpgradeLevel - 1));
  int get resolveUpgradeCost => 100 * (1 << (resolveUpgradeLevel - 1));
  int get staminaUpgradeCost => 100 * (1 << (staminaUpgradeLevel - 1));
  int get swordUpgradeCost => 100 * (1 << (swordUpgradeLevel - 1));

  // --- Upgrade Execution ---
  bool upgradeHealth() {
    final cost = healthUpgradeCost;
    if (willpower >= cost) {
      willpower -= cost;
      healthUpgradeLevel++;
      maxHealth += 20.0;
      health = maxHealth; // Heal to full on upgrade
      return true;
    }
    return false;
  }

  bool upgradeResolve() {
    final cost = resolveUpgradeCost;
    if (willpower >= cost) {
      willpower -= cost;
      resolveUpgradeLevel++;
      maxResolve += 20.0;
      return true;
    }
    return false;
  }

  bool upgradeStamina() {
    final cost = staminaUpgradeCost;
    if (willpower >= cost) {
      willpower -= cost;
      staminaUpgradeLevel++;
      maxStamina += 20.0;
      stamina = maxStamina; // Recover stamina on upgrade
      return true;
    }
    return false;
  }

  bool upgradeSword() {
    final cost = swordUpgradeCost;
    if (willpower >= cost && diamondsCollected >= 1) {
      willpower -= cost;
      diamondsCollected -= 1;
      swordUpgradeLevel++;
      swordDamage += 10.0;
      return true;
    }
    return false;
  }

  /// Reset health/resolve/stamina for a new level attempt (after death).
  void resetForRetry() {
    health = maxHealth;
    resolve = 0;
    isIndomitable = false;
    stamina = maxStamina;

    // Death Mechanics: Old lost will is overwritten by current will. Diamonds are retained!
    lostWillpower = willpower;
    willpower = 0;
  }

  /// Add resolve. Returns true if Indomitable is now available.
  bool addResolve(double amount) {
    resolve = (resolve + amount).clamp(0, maxResolve);
    return resolve >= maxResolve;
  }

  /// Take damage. Returns true if the player died.
  bool takeDamage(double amount) {
    if (isIndomitable) amount *= GameConfig.playerIndomitableDefenseMultiplier;
    health = (health - amount).clamp(0, maxHealth);
    return health <= 0;
  }

  /// Heal the player.
  void heal(double amount) {
    health = (health + amount).clamp(0, maxHealth);
  }

  /// Get effective sword damage (multiplied by config during Indomitable state).
  double get effectiveDamage => isIndomitable ? swordDamage * GameConfig.playerIndomitableDamageMultiplier : swordDamage;

  /// Telemetry snapshot for The Architect AI.
  Map<String, dynamic> toTelemetry() {
    return {
      'health_percent': (health / maxHealth * 100).round(),
      'resolve_percent': (resolve / maxResolve * 100).round(),
      'death_count': deathCount,
      'current_level': currentLevel,
      'enemies_killed': enemiesKilled,
      'perfect_dodges': perfectDodges,
      'diamonds_collected': diamondsCollected,
    };
  }
}
