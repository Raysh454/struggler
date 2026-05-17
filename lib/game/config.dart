import 'package:flame/components.dart';

/// Centralized configuration class for STRUGGLER game constants.
/// Centralizing all magic numbers here allows easy adjustment of sizes,
/// scaling factors, player speeds, combat stats, timers, and AI validation constraints.
class GameConfig {
  // --- Grid & Tile System ---
  static const double tileSize = 32.0;
  static const double blockOverlap = 1.0;
  static const int pillarMaxDepth = 6;
  static const double lavaBleed = 32.0;

  // --- Player Starting Defaults ---
  static const double playerMaxHealthDefault = 100.0;
  static const double playerMaxResolveDefault = 100.0;
  static const double playerSwordDamageDefault = 25.0;

  // --- Player Physics & Stats ---
  static const double playerMoveSpeed = 200.0;
  static const double playerJumpForce = -400.0;
  static const double playerGravity = 900.0;
  static const double playerMaxFallSpeed = 600.0;
  static const int playerMaxJumps = 2;
  static const double playerJumpBufferDuration = 0.15;
  static const double playerCoyoteDuration = 0.1;
  
  static final Vector2 playerSize = Vector2(28, 40);
  static final Vector2 playerAnimationSize = Vector2(128, 64);

  // --- Player Combat ---
  static const double playerAttackDuration = 0.28;
  static const double playerAttackCooldown = 0.35;
  static const double playerDodgeDuration = 0.2;
  static const double playerDodgeSpeed = 450.0;
  static const double playerDodgeCooldown = 0.5;
  static const double playerHitStopDuration = 0.05;
  static const double playerRespawnDelay = 1.5;
  static const double playerHurtDuration = 0.3;

  // --- Enemy Configs ---
  static const double enemyGravity = 900.0;
  static const double enemyHurtDuration = 0.15;
  static final Vector2 enemySizeBasic = Vector2(28, 36);
  static final Vector2 enemySizeHeavy = Vector2(36, 44);
  static final Vector2 enemySizeFast = Vector2(22, 32);

  // --- Hazard Settings ---
  static const double spikeDamageDefault = 20.0;
  static const double lavaDamageDefault = 15.0;

  // --- Pickup Settings ---
  static const double healthPickupHealAmountDefault = 30.0;
  static final Vector2 healthPickupSize = Vector2.all(10);
  static final Vector2 orePickupSize = Vector2.all(10);

  // --- Portal Settings ---
  static final Vector2 exitPortalSize = Vector2(32, 48);

  // --- Decoration Scales & Offsets (PlatformBlock) ---
  // Grass
  static const double grassSpawnChance = 0.7; // 70% chance to spawn if random > 0.3
  static final Vector2 grassPatchSize = Vector2(32, 32);
  static const double grassMaxXOffset = 4.0; // +/- 4 horizontal variance
  static const double grassYOffset = 17.0; // vertical offset relative to patch height

  // Rocks
  static const double rockSpawnChance = 0.15; // 15% chance to spawn if random > 0.85
  static const double rockScaleHeightReference = 24.0; // reference height for scaling
  static const double rockXOffset = 4.0;
  static const double rockYOffsetRatio = 0.6; // vertical placement ratio

  // Trees
  static const double treeSpawnChance = 0.08; // 8% chance to spawn if random > 0.92
  static const double treeScaleRatio = 1; // scaling factor
  static const double treeXOffset = 1;
  static const double treeYOffset = 3.0; // vertical offset
  static const int treePriority = -10;

  // --- AI Validation / Level Generator Settings ---
  static const int validatorMaxJumpHeight = 5;
  static const int validatorMaxHorizontalGap = 10;
  static const int validatorSpawnSafeRadius = 3;
  static const int validatorExitSafeRadius = 2;
  static const int validatorMaxRepairIterations = 3;
}
