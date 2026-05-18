import 'package:flame/components.dart';

/// Centralized configuration class for STRUGGLER game constants.
/// Centralizing all magic numbers here allows easy adjustment of sizes,
/// scaling factors, player speeds, combat stats, timers, and AI validation constraints.
class GameConfig {
  // --- Grid & Tile System ---
  static const double tileSize = 32.0;
  static const double blockOverlap = 1.0;
  static const int pillarMaxDepth = 6;
  static const double lavaBleed = 2.0;

  // --- Player Starting Defaults ---
  static const double playerMaxHealthDefault = 100.0;
  static const double playerMaxResolveDefault = 100.0;
  static const double playerMaxStaminaDefault = 100.0;
  static const double playerSwordDamageDefault = 25.0;

  // --- Player Physics & Stats ---
  static const double playerMoveSpeed = 200.0;
  static const double playerJumpForce = -400.0;
  static const double playerGravity = 900.0;
  static const double playerMaxFallSpeed = 600.0;
  static const int playerMaxJumps = 2;
  static const double playerJumpBufferDuration = 0.15;
  static const double playerCoyoteDuration = 0.1;

  // --- Player Stamina Costs & Regeneration ---
  static const double playerStaminaRegenRate =
      30.0; // Units regenerated per second
  static const double playerStaminaJumpCost = 12.0;
  static const double playerStaminaAttackCost = 10.0;
  static const double playerStaminaPlungeCost = 30.0;
  static const double playerStaminaDodgeCost = 15.0;

  static final Vector2 playerSize = Vector2(28, 40);
  static final Vector2 playerAnimationSize = Vector2(128, 64);

  // --- Player Combat ---
  static const double playerResolveDrainRate = 30.0;
  static const double playerIndomitableDamageMultiplier = 2.0;
  static const double playerIndomitableDefenseMultiplier = 0.5;
  static const double playerIndomitableLifestealRatio = 0.5;

  // --- Player Combat & Combo system ---
  static const double playerAttackDuration = 0.28;
  static const double playerAttackCooldown = 0.35;
  static const double playerComboWindow = 0.5;
  static const double playerAttackInputBuffer = 0.2;
  static const double playerAttackDamageDelayRatio = 0.5;
  static const double playerAttackFreezeRatio = 0.7;

  // --- Player Air / Plunge attacks ---
  static const double playerPlungeSpeed = 800.0;
  static const double playerPlungeDelay = 0.2;
  static const double playerPlungeSplashRadius = 60.0;
  static const double playerPlungeSplashDamage = 35.0;

  static const double playerDodgeDuration = 0.2;
  static const double playerDodgeSpeed = 450.0;
  static const double playerDodgeCooldown = 0.5;
  static const double playerHitStopDuration = 0.05;
  static const double playerRespawnDelay = 1.5;
  static const double playerHurtDuration = 0.3;

  // --- Upgrade Cost Settings ---
  static const int upgradeHealthBaseCost = 100;
  static const int upgradeResolveBaseCost = 100;
  static const int upgradeStaminaBaseCost = 100;
  static const int upgradeSwordBaseCost = 100;
  static const int catHealUpgradeBaseCost = 200;

  // Friendly Characters
  static final Vector2 renderSizeGuardian = Vector2(100, 150);
  static final Vector2 renderSizeCat = Vector2(40, 40);

  static double offsetYGuardian = -210;
  static double offsetYCat = 10;

  // --- Guardian & Cat Settings ---
  static final Vector2 guardianSize = Vector2(48, 64);

  // Companion Cat "Hope" Mechanics
  static const double catAttackDamage = 10.0;
  static const double catAttackDamagePerLevel = 10.0;
  static const double catAttackCooldown = 3.0;
  static const double catAttackRange = 40.0;
  static const double catAttackDamageDelay =
      0.25; // Delay in seconds before damage is dealt
  static const double catHealThreshold = 0.20; // 20% health trigger
  static const double catHealAmount =
      healthPickupHealAmountDefault; // default 30.0
  static const int catHealsPerLevel = 1;

  // --- Enemy Configs ---
  static const double enemyGravity = 900.0;
  static const double enemyHurtDuration = 0.4;
  static const double enemyDamageMultiplier = 2;
  static const double enemyHealthMultiplier = 1;

  static const double enemySkeletonHurtDuration = 0.4;
  static const double enemySkeletonStaggerForce = 30;

  static const double enemyGoblinHurtDuration = 0.4;
  static const double enemyGoblinStaggerForce = 30;

  static const double enemyNightborneHurtDuration = 0.4;
  static const double enemyNightborneStaggerForce = 30;

  static const double enemyBringerHurtDuration = 0.4;
  static const double enemyBringerStaggerForce = 30.0;

  static const double enemyArcherHurtDuration = 0.15;
  static const double enemyArcherStaggerForce = 30;

  static const double enemyWizardHurtDuration = 0.15;
  static const double enemyWizardStaggerForce = 30;

  // --- Enemy Health Configs ---
  static const double enemyHealthSkeleton = 120.0;
  static const double enemyHealthGoblin = 80.0;
  static const double enemyHealthNightborne = 160.0;
  static const double enemyHealthBringer = 240.0;
  static const double enemyHealthArcher = 75.0;
  static const double enemyHealthWizard = 80.0;
  static const double enemyHealthArchitect = 1500;

  // --- Enemy Willpower (Will) Drop Configs ---
  static const int enemyWillSkeleton = 30;
  static const int enemyWillGoblin = 20;
  static const int enemyWillNightborne = 50;
  static const int enemyWillBringer = 80;
  static const int enemyWillArcher = 25;
  static const int enemyWillWizard = 25;
  static const int enemyWillArchitect = 1500;

  // --- Enemy Resolve Drop Configs ---
  static const double enemyResolveSkeleton = 25.0;
  static const double enemyResolveGoblin = 20.0;
  static const double enemyResolveNightborne = 40.0;
  static const double enemyResolveBringer = 50.0;
  static const double enemyResolveArcher = 25.0;
  static const double enemyResolveWizard = 25.0;
  static const double enemyResolveArchitect = 100.0;

  // --- Enemy Damage Configs (Contact or base melee) ---
  static const double enemyDamageSkeleton = 24.0;
  static const double enemyDamageGoblin = 16.0;
  static const double enemyDamageNightborne = 36.0;
  static const double enemyDamageBringer = 44.0;
  static const double enemyDamageArcher = 12.0;
  static const double enemyDamageWizard = 12.0;
  static const double enemyDamageArchitect = 0.0;

  // --- Enemy Speed Configs ---
  static const double enemySpeedSkeleton = 65.0;
  static const double enemySpeedGoblin = 105.0;
  static const double enemySpeedNightborne = 135.0;
  static const double enemySpeedBringer = 50.0;
  static const double enemySpeedArcher = 55.0;
  static const double enemySpeedWizard = 40.0;
  static const double enemySpeedArchitect = 0.0;
  // Legacy sizes (kept for backward compat)
  static final Vector2 enemySizeBasic = Vector2(28, 36);
  static final Vector2 enemySizeHeavy = Vector2(36, 44);
  static final Vector2 enemySizeFast = Vector2(22, 32);

  // Per-type hitboxes (physics collision size)
  static final Vector2 enemyHitboxSkeleton = Vector2(56, 72);
  static final Vector2 enemyHitboxGoblin = Vector2(30, 44);
  static final Vector2 enemyHitboxArcher = Vector2(32, 48);
  static final Vector2 enemyHitboxWizard = Vector2(32, 48);
  static final Vector2 enemyHitboxNightborne = Vector2(40, 58);
  static final Vector2 enemyHitboxBringer = Vector2(52, 68);
  static final Vector2 enemyHitboxArchitect = Vector2(96, 96);

  // Per-type visual sizes (sprite frame size for rendering)
  static final Vector2 enemySizeSkeleton = Vector2(100, 150);
  static final Vector2 enemySizeGoblin = Vector2(100, 150);
  static final Vector2 enemySizeArcher = Vector2(60, 100);
  static final Vector2 enemySizeWizard = Vector2(64, 64);
  static final Vector2 enemySizeNightborne = Vector2(100, 140);
  static final Vector2 enemySizeBringer = Vector2(100, 100);
  static final Vector2 enemySizeArchitect = Vector2(96, 96);

  // --- Enemy Y Offsets (adjusts sprite rendering relative to hitbox bottom) ---
  static const double enemyYOffsetSkeleton = 50;
  static const double enemyYOffsetGoblin = 50;
  static const double enemyYOffsetArcher = 25;
  static const double enemyYOffsetWizard = 6;
  static const double enemyYOffsetNightborne = 25;
  static const double enemyYOffsetBringer = 0;

  // --- Enemy Health Bar Offsets (relative to hitbox top) ---
  static const double enemyHealthBarYOffsetSkeleton = 10.0;
  static const double enemyHealthBarYOffsetGoblin = -6.0;
  static const double enemyHealthBarYOffsetArcher = -14.0;
  static const double enemyHealthBarYOffsetWizard = -12.0;
  static const double enemyHealthBarYOffsetNightborne = 0.0;
  static const double enemyHealthBarYOffsetBringer = 0.0;
  static const double enemyHealthBarYOffsetArchitect = -6.0;

  // --- Projectiles ---
  static const double arrowSpeed = 580.0;
  static const double arrowDamage = 12.0;
  static const double arrowRange = 650.0;
  static const double orbSpeed = 200.0;
  static const double orbDamage = 18.0;
  static const double orbRange = 480.0;
  static const double thunderDamage = 28.0;
  static const double thunderHandFallSpeed = 380.0;
  static final Vector2 thunderHandSize = Vector2(150, 120);
  static const double thunderHandYOffset = -80.0;

  // --- Enemy AI ---
  static const double enemyAggroRange = 150.0;
  static const double enemyAggroRangeSkeleton = 150.0;
  static const double enemyAggroRangeGoblin = 150.0;
  static const double enemyAggroRangeNightborne = 150.0;
  static const double enemyAggroRangeBringer = 150.0;
  static const double enemyAggroRangeArcher = 300.0;
  static const double enemyAggroRangeWizard = 300.0;
  static const double enemyRangedBackoffDist = 160.0;
  static const double enemyAttackRange = 52.0; // General fallback
  static const double enemyAttackRangeSkeleton = 55.0; // Medium sword range
  static const double enemyAttackRangeGoblin = 35.0; // Short dagger range
  static const double enemyAttackRangeNightborne = 55.0; // Long blade range
  static const double enemyAttackRangeBringer = 40.0; // Massive scythe range
  static const double enemyAttackReachPadding =
      15.0; // Extra horizontal reach check for melee attacks
  static const double enemyAttackMaxVerticalDiff = 40.0; // General fallback
  static const double enemyAttackMaxVerticalDiffSkeleton =
      40.0; // Skeleton vertical range
  static const double enemyAttackMaxVerticalDiffGoblin =
      30.0; // Goblin vertical range
  static const double enemyAttackMaxVerticalDiffNightborne =
      50.0; // Nightborne vertical range
  static const double enemyAttackMaxVerticalDiffBringer =
      60.0; // Bringer vertical range
  static const double enemyMeleeAttackCooldown = 1.2;
  static const double enemyRangedFireCooldown = 2.8; // archer
  static const double enemyWizardFireCooldown = 3.6;
  static const double bringerSpellInterval = 6.0;
  static const double bringerSpellRange = 300.0;
  static const double bringerFlipOffsetX = 28.0;

  // --- Nightborn Explosion ---
  static const double nightbornExplosionRadius = 90.0;
  static const double nightbornExplosionDamage = 32.0;

  // --- Architect Teleport ---
  static const double architectTeleportInterval = 4.5;
  static const double architectTeleportShrinkTime = 0.18;
  static const double architectBobAmplitude = 6.0;
  static const double architectBobSpeed = 2.0;

  // --- Hazard Settings ---
  static const double spikeDamageDefault = 20.0;
  static const double spikeOffset =
      2.0; // Positive values move spikes outwards, negative moves inwards.
  static const double lavaDamageDefault = 15.0;

  // --- Pickup Settings ---
  static const double healthPickupHealAmountDefault = 30.0;
  static final Vector2 healthPickupSize = Vector2.all(10);
  static final Vector2 diamondPickupSize = Vector2.all(10);

  // --- Portal Settings ---
  static final Vector2 exitPortalSize = Vector2(32, 48);
  static final Vector2 guardianPortalSize = Vector2(32, 48);

  // --- Decoration Scales & Offsets (PlatformBlock) ---
  // Grass
  static const double grassSpawnChance =
      0.7; // 70% chance to spawn if random > 0.3
  static final Vector2 grassPatchSize = Vector2(32, 32);
  static const double grassMaxXOffset = 4.0; // +/- 4 horizontal variance
  static const double grassYOffset =
      17.0; // vertical offset relative to patch height

  // Rocks
  static const double rockSpawnChance =
      0.15; // 15% chance to spawn if random > 0.85
  static const double rockScaleHeightReference =
      24.0; // reference height for scaling
  static const double rockXOffset = 4.0;
  static const double rockYOffsetRatio = 0.6; // vertical placement ratio

  // Trees
  static const double treeSpawnChance =
      0.08; // 8% chance to spawn if random > 0.92
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

  // --- AI / Level Generation ---
  /// Set to true to generate a new AI level on death. False = replay same cached level.
  static const bool generateNewLevelOnDeath = false;

  // --- Boss Fight Dialogues ---
  static const List<String> architectPhaseDialogues = [
    "Is this your best effort?",
    "I will reshape this world to break you.",
    "Your resolve is an illusion.",
    "No more games. Die.",
    "Impossible...",
  ];

  static const String architectDeathKillDialogue =
      "So be it... back to the void.";
  static const String architectDeathSpareDialogue =
      "You spare the hand that strikes you? Fool.";
}
