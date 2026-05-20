import 'package:flutter_test/flutter_test.dart';
import 'package:struggler/models/player_state.dart';

void main() {
  group('PlayerState', () {
    late PlayerState state;

    setUp(() {
      state = PlayerState();
    });

    group('initialization', () {
      test('has correct default values', () {
        expect(state.maxHealth, 100.0);
        expect(state.health, 100.0);
        expect(state.maxResolve, 100.0);
        expect(state.resolve, 0.0);
        expect(state.maxStamina, 100.0);
        expect(state.stamina, 100.0);
        expect(state.swordDamage, 25.0);
        expect(state.isIndomitable, false);
        expect(state.perfectDodges, 0);
        expect(state.diamondsCollected, 0);
        expect(state.willpower, 0);
        expect(state.deathCount, 0);
        expect(state.currentLevel, 0);
        expect(state.enemiesKilled, 0);
      });

      test('accepts custom initial values', () {
        final custom = PlayerState(
          maxHealth: 200,
          maxResolve: 50,
          maxStamina: 150,
          swordDamage: 40,
          diamondsCollected: 3,
          willpower: 10,
          currentLevel: 5,
        );
        expect(custom.maxHealth, 200.0);
        expect(custom.health, 200.0); // health starts at maxHealth
        expect(custom.maxResolve, 50.0);
        expect(custom.maxStamina, 150.0);
        expect(custom.stamina, 150.0);
        expect(custom.swordDamage, 40.0);
        expect(custom.diamondsCollected, 3);
        expect(custom.willpower, 10);
        expect(custom.currentLevel, 5);
      });
    });

    group('takeDamage', () {
      test('reduces health by the damage amount', () {
        final died = state.takeDamage(30);
        expect(state.health, 70.0);
        expect(died, false);
      });

      test('returns true when health reaches 0', () {
        final died = state.takeDamage(100);
        expect(state.health, 0.0);
        expect(died, true);
      });

      test('returns true when damage exceeds health', () {
        final died = state.takeDamage(150);
        expect(state.health, 0.0);
        expect(died, true);
      });

      test('health does not go below 0', () {
        state.takeDamage(200);
        expect(state.health, 0.0);
      });

      test('halves damage during Indomitable state', () {
        state.isIndomitable = true;
        state.takeDamage(40);
        expect(state.health, 80.0); // 40 / 2 = 20 damage
      });

      test('Indomitable halved damage does not prevent death from massive hit', () {
        state.isIndomitable = true;
        final died = state.takeDamage(250);
        expect(died, true);
        expect(state.health, 0.0);
      });
    });

    group('heal', () {
      test('restores health', () {
        state.takeDamage(50);
        state.heal(30);
        expect(state.health, 80.0);
      });

      test('does not exceed maxHealth', () {
        state.takeDamage(10);
        state.heal(50);
        expect(state.health, 100.0);
      });

      test('healing at full health does nothing', () {
        state.heal(50);
        expect(state.health, 100.0);
      });
    });

    group('addResolve', () {
      test('increases resolve', () {
        final ready = state.addResolve(30);
        expect(state.resolve, 30.0);
        expect(ready, false);
      });

      test('returns true when resolve reaches max', () {
        final ready = state.addResolve(100);
        expect(state.resolve, 100.0);
        expect(ready, true);
      });

      test('clamps resolve to maxResolve', () {
        state.addResolve(150);
        expect(state.resolve, 100.0);
      });

      test('accumulates across multiple calls', () {
        state.addResolve(30);
        state.addResolve(25);
        final ready = state.addResolve(50);
        expect(state.resolve, 100.0); // 30+25+50=105, clamped to 100
        expect(ready, true);
      });
    });

    group('effectiveDamage', () {
      test('returns base damage normally', () {
        expect(state.effectiveDamage, 25.0);
      });

      test('returns doubled damage during Indomitable state', () {
        state.isIndomitable = true;
        expect(state.effectiveDamage, 50.0);
      });
    });

    group('resetForRetry', () {
      test('restores health to max', () {
        state.takeDamage(60);
        state.resetForRetry();
        expect(state.health, 100.0);
      });

      test('zeroes resolve and disables Indomitable', () {
        state.addResolve(80);
        state.isIndomitable = true;
        state.resetForRetry();
        expect(state.resolve, 0.0);
        expect(state.isIndomitable, false);
      });

      test('restores stamina to maxStamina', () {
        state.stamina = 10;
        state.resetForRetry();
        expect(state.stamina, 100.0);
      });

      test('does NOT reset death count or enemies killed', () {
        state.deathCount = 5;
        state.enemiesKilled = 12;
        state.resetForRetry();
        expect(state.deathCount, 5);
        expect(state.enemiesKilled, 12);
      });
    });

    group('resetFully', () {
      test('resets all stats, currencies, and upgrades to default start values', () {
        state.maxHealth = 160.0;
        state.health = 120.0;
        state.maxResolve = 140.0;
        state.resolve = 50.0;
        state.isIndomitable = true;
        state.maxStamina = 120.0;
        state.stamina = 80.0;
        state.swordDamage = 45.0;
        state.perfectDodges = 10;
        state.diamondsCollected = 5;
        state.willpower = 400;
        state.healthUpgradeLevel = 4;
        state.resolveUpgradeLevel = 3;
        state.staminaUpgradeLevel = 2;
        state.swordUpgradeLevel = 3;
        state.catHealUpgradeLevel = 2;
        state.catHealsRemaining = 1;
        state.deathCount = 15;
        state.enemiesKilled = 80;

        state.resetFully();

        expect(state.maxHealth, 100.0);
        expect(state.health, 100.0);
        expect(state.maxResolve, 100.0);
        expect(state.resolve, 0.0);
        expect(state.isIndomitable, false);
        expect(state.maxStamina, 100.0);
        expect(state.stamina, 100.0);
        expect(state.swordDamage, 25.0);
        expect(state.perfectDodges, 0);
        expect(state.diamondsCollected, 0);
        expect(state.willpower, 0);
        expect(state.healthUpgradeLevel, 1);
        expect(state.resolveUpgradeLevel, 1);
        expect(state.staminaUpgradeLevel, 1);
        expect(state.swordUpgradeLevel, 1);
        expect(state.catHealUpgradeLevel, 1);
        expect(state.catHealsRemaining, GameConfig.catHealsPerLevel);
        expect(state.deathCount, 0);
        expect(state.enemiesKilled, 0);
      });
    });

    group('toTelemetry', () {
      test('returns correct snapshot with default values', () {
        final telemetry = state.toTelemetry();
        expect(telemetry['health_percent'], 100);
        expect(telemetry['resolve_percent'], 0);
        expect(telemetry['death_count'], 0);
        expect(telemetry['current_level'], 0);
        expect(telemetry['enemies_killed'], 0);
        expect(telemetry['perfect_dodges'], 0);
        expect(telemetry['diamonds_collected'], 0);
      });

      test('reflects state changes accurately', () {
        state.takeDamage(30);
        state.addResolve(50);
        state.deathCount = 3;
        state.currentLevel = 7;
        state.enemiesKilled = 15;
        state.perfectDodges = 4;
        state.diamondsCollected = 2;

        final telemetry = state.toTelemetry();
        expect(telemetry['health_percent'], 70);
        expect(telemetry['resolve_percent'], 50);
        expect(telemetry['death_count'], 3);
        expect(telemetry['current_level'], 7);
        expect(telemetry['enemies_killed'], 15);
        expect(telemetry['perfect_dodges'], 4);
        expect(telemetry['diamonds_collected'], 2);
      });
    });

    group('toLiveTelemetry and deathsThisLevel', () {
      test('returns correct live telemetry snapshot', () {
        state.deathsThisLevel = 2;
        state.damageTakenThisLevel = 45.0;
        state.enemiesKilledThisLevel = 3;
        state.perfectDodgesThisLevel = 1;
        state.totalEnemiesInLevel = 8;

        final liveTelemetry = state.toLiveTelemetry();
        expect(liveTelemetry['healthPercent'], 100);
        expect(liveTelemetry['damageTakenSoFar'], 45.0);
        expect(liveTelemetry['enemiesDefeatedSoFar'], 3);
        expect(liveTelemetry['perfectDodgesSoFar'], 1);
        expect(liveTelemetry['totalEnemiesInLevel'], 8);
        expect(liveTelemetry['deathsThisLevel'], 2);
      });

      test('resets deathsThisLevel on new level but NOT on retry', () {
        state.deathsThisLevel = 3;
        state.resetForRetry();
        expect(state.deathsThisLevel, 3); // retained on retry!

        state.resetForNewLevel();
        expect(state.deathsThisLevel, 0); // reset on new level!
      });
    });

    group('Guardian Upgrades', () {
      test('upgradeHealth increases maxHealth and costs willpower with 100 * 2^(level-1) math', () {
        state.willpower = 250;
        final success = state.upgradeHealth();
        expect(success, true);
        expect(state.healthUpgradeLevel, 2);
        expect(state.maxHealth, 120.0);
        expect(state.health, 120.0);
        expect(state.willpower, 150); // 250 - 100 (Level 1 cost: 100)

        // Upgrade again (Level 2 cost: 200)
        final success2 = state.upgradeHealth();
        expect(success2, false); // Not enough willpower (needs 200, has 150)
        
        state.willpower = 200;
        final success3 = state.upgradeHealth();
        expect(success3, true);
        expect(state.healthUpgradeLevel, 3);
        expect(state.maxHealth, 140.0);
        expect(state.willpower, 0);
      });

      test('upgradeResolve increases maxResolve and costs willpower', () {
        state.willpower = 150;
        final success = state.upgradeResolve();
        expect(success, true);
        expect(state.resolveUpgradeLevel, 2);
        expect(state.maxResolve, 120.0);
        expect(state.willpower, 50); // 150 - 100
      });

      test('upgradeSword increases swordDamage and costs willpower + 1 diamond', () {
        state.willpower = 150;
        state.diamondsCollected = 2;
        final success = state.upgradeSword();
        expect(success, true);
        expect(state.swordUpgradeLevel, 2);
        expect(state.swordDamage, 35.0); // 25 + 10
        expect(state.diamondsCollected, 1);
        expect(state.willpower, 50); // 150 - 100
      });

      test('upgrade fails with insufficient resources', () {
        state.willpower = 50;
        final success = state.upgradeHealth();
        expect(success, false);
        expect(state.healthUpgradeLevel, 1);
        expect(state.maxHealth, 100.0);
      });
    });
  });
}
