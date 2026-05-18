import 'dart:ui';
import 'package:flutter/material.dart';
import '../game/struggler_game.dart';
import '../game/config.dart';

/// Glassmorphic button for premium styling.
class GlassButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final Color color;

  const GlassButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.color = const Color(0xFFFF2E63),
    Key? key,
  }) : super(key: key);

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.enabled ? widget.color : Colors.grey;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: widget.enabled
                ? (_isHovered
                      ? baseColor.withOpacity(0.3)
                      : baseColor.withOpacity(0.15))
                : Colors.white10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.enabled
                  ? (_isHovered ? baseColor : baseColor.withOpacity(0.5))
                  : Colors.white24,
              width: 1.5,
            ),
            boxShadow: widget.enabled && _isHovered
                ? [
                    BoxShadow(
                      color: baseColor.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.enabled ? Colors.white : Colors.grey.shade400,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Main Menu Overlay displayed when the game launches.
class MainMenuOverlay extends StatelessWidget {
  final StruggleGame game;

  const MainMenuOverlay({required this.game, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFF2E63).withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Game Logo Title
                  const Text(
                    'STRUGGLER',
                    style: TextStyle(
                      color: Color(0xFFFF2E63),
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(color: Color(0xAAFF2E63), blurRadius: 16),
                      ],
                    ),
                  ),
                  const Text(
                    "THE ARCHITECT'S TRIAL",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Actions
                  GlassButton(
                    label: 'BEGIN TRIAL',
                    color: const Color(0xFFFF2E63),
                    onTap: () {
                      game.overlays.remove('MainMenu');
                      game.resumeEngine();
                      game.showControlsNotifier.value = true;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Control Instructions Panel
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'CONTROLS:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        SizedBox(height: 8),
                        _ControlRow(
                          keyName: 'A / D',
                          action: 'Move Left / Right',
                        ),
                        _ControlRow(
                          keyName: 'W',
                          action: 'Jump (Double Jump available)',
                        ),
                        _ControlRow(
                          keyName: 'Space',
                          action: 'Dodge (Stamina-Draining I-Frames)',
                        ),
                        _ControlRow(
                          keyName: 'R',
                          action: 'Indomitable Lifesteal (Full Resolve)',
                        ),
                        _ControlRow(
                          keyName: 'E',
                          action: 'Interact / Enter Realm Portal',
                        ),
                        _ControlRow(
                          keyName: 'Left Click',
                          action: 'Sword Attack Combos',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  final String keyName;
  final String action;

  const _ControlRow({required this.keyName, required this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              keyName,
              style: const TextStyle(
                color: Color(0xFF08D9D6),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              action,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Guardian Upgrades Overlay to buy stats upgrades using willpower and diamonds.
class GuardianUpgradesOverlay extends StatefulWidget {
  final StruggleGame game;

  const GuardianUpgradesOverlay({required this.game, Key? key})
    : super(key: key);

  @override
  State<GuardianUpgradesOverlay> createState() =>
      _GuardianUpgradesOverlayState();
}

class _GuardianUpgradesOverlayState extends State<GuardianUpgradesOverlay> {
  @override
  Widget build(BuildContext context) {
    final state = widget.game.playerState;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(
                    0xFF00E5FF,
                  ).withOpacity(0.4), // Serene Cyan
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  const Text(
                    'GUARDIAN UPGRADES',
                    style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(color: Color(0x8800E5FF), blurRadius: 12),
                      ],
                    ),
                  ),
                  const Text(
                    'TEMPLE OF WILLPOWER',
                    style: TextStyle(
                      color: Color(0x80FFFFFF),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Currency Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _CurrencyIndicator(
                        label: 'WILLPOWER',
                        value: '${state.willpower}',
                        color: const Color(0xFFE0E0E0),
                        icon: Icons.auto_awesome,
                      ),
                      _CurrencyIndicator(
                        label: 'DIAMONDS',
                        value: '${state.diamondsCollected}',
                        color: const Color(0xFF00E5FF),
                        icon: Icons.diamond,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Upgrades list
                  _UpgradeItem(
                    title: 'Heart of Vigor',
                    subtitle: 'Increases Max HP (+20)',
                    currentValue: '${state.maxHealth.round()} HP',
                    level: 'Lvl ${state.healthUpgradeLevel}',
                    costDescription: '${state.healthUpgradeCost} Will',
                    canUpgrade: state.willpower >= state.healthUpgradeCost,
                    onUpgrade: () {
                      if (state.upgradeHealth()) {
                        setState(() {});
                      }
                    },
                  ),
                  _UpgradeItem(
                    title: 'Resolve Core',
                    subtitle: 'Increases Max Resolve (+20)',
                    currentValue: '${state.maxResolve.round()} Max',
                    level: 'Lvl ${state.resolveUpgradeLevel}',
                    costDescription: '${state.resolveUpgradeCost} Will',
                    canUpgrade: state.willpower >= state.resolveUpgradeCost,
                    onUpgrade: () {
                      if (state.upgradeResolve()) {
                        setState(() {});
                      }
                    },
                  ),
                  _UpgradeItem(
                    title: 'Stamina Vessel',
                    subtitle: 'Increases Max Stamina (+20)',
                    currentValue: '${state.maxStamina.round()} Max',
                    level: 'Lvl ${state.staminaUpgradeLevel}',
                    costDescription: '${state.staminaUpgradeCost} Will',
                    canUpgrade: state.willpower >= state.staminaUpgradeCost,
                    onUpgrade: () {
                      if (state.upgradeStamina()) {
                        setState(() {});
                      }
                    },
                  ),
                  _UpgradeItem(
                    title: 'Struggle\'s Edge',
                    subtitle: 'Increases Sword Damage (+5)',
                    currentValue: '${state.swordDamage.round()} DMG',
                    level: 'Lvl ${state.swordUpgradeLevel}',
                    costDescription: '${state.swordUpgradeCost} Will + 1 Dia',
                    canUpgrade:
                        state.willpower >= state.swordUpgradeCost &&
                        state.diamondsCollected >= 1,
                    onUpgrade: () {
                      if (state.upgradeSword()) {
                        setState(() {});
                      }
                    },
                  ),
                  _UpgradeItem(
                    title: "Hope's Sanctuary",
                    subtitle:
                        'Increases Hope\'s capacity to heal (+1) and damage (+10)',
                    currentValue:
                        '${state.catHealsMax} Heals / ${(GameConfig.catAttackDamage + (state.catHealUpgradeLevel - 1) * GameConfig.catAttackDamagePerLevel).round()} Dmg',
                    level: 'Lvl ${state.catHealUpgradeLevel}',
                    costDescription: '${state.catHealUpgradeCost} Will',
                    canUpgrade: state.willpower >= state.catHealUpgradeCost,
                    onUpgrade: () {
                      if (state.upgradeCatHeals()) {
                        setState(() {});
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Close button
                  GlassButton(
                    label: 'RETURN TO SANCTUARY',
                    color: const Color(0xFF00E5FF),
                    onTap: () {
                      widget.game.closeGuardianUpgrades();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencyIndicator extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _CurrencyIndicator({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String currentValue;
  final String level;
  final String costDescription;
  final bool canUpgrade;
  final VoidCallback onUpgrade;

  const _UpgradeItem({
    required this.title,
    required this.subtitle,
    required this.currentValue,
    required this.level,
    required this.costDescription,
    required this.canUpgrade,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x3300E5FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        level,
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'CURRENT: $currentValue',
                  style: const TextStyle(
                    color: Colors.white30,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Cost indicator and Upgrade Button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                costDescription,
                style: TextStyle(
                  color: canUpgrade
                      ? const Color(0xFF00FF88)
                      : Colors.redAccent.shade100,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: canUpgrade ? onUpgrade : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: canUpgrade
                        ? const Color(0xFF00E5FF)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'UPGRADE',
                    style: TextStyle(
                      color: canUpgrade ? Colors.black : Colors.white24,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The Architect Intro Overlay displayed at the start of an AI-generated level.
class ArchitectIntroOverlay extends StatelessWidget {
  final StruggleGame game;
  final String dialogue;

  const ArchitectIntroOverlay({required this.game, required this.dialogue, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFB71C1C), width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x66B71C1C), blurRadius: 20, spreadRadius: 2),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFB71C1C), width: 2),
                      borderRadius: BorderRadius.circular(8),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/characters/architect/dialogue.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'THE ARCHITECT',
                          style: TextStyle(
                            color: Color(0xFFFF5252),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          dialogue,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GlassButton(
                            label: 'CONTINUE',
                            color: const Color(0xFFB71C1C),
                            onTap: () {
                              game.overlays.remove('ArchitectIntro');
                              game.resumeEngine();
                              game.showControlsNotifier.value = true;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Top-Right HUD Dialogue box for dynamic in-game taunts.
class TopRightDialogueOverlay extends StatefulWidget {
  final String dialogue;

  const TopRightDialogueOverlay({required this.dialogue, Key? key}) : super(key: key);

  @override
  State<TopRightDialogueOverlay> createState() => _TopRightDialogueOverlayState();
}

class _TopRightDialogueOverlayState extends State<TopRightDialogueOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    
    _controller.forward();
    
    // Auto dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 20,
      right: 20,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFB71C1C), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0x33B71C1C), blurRadius: 10, spreadRadius: 1),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFB71C1C), width: 1),
                  borderRadius: BorderRadius.circular(4),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/characters/architect/dialogue.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'THE ARCHITECT',
                      style: TextStyle(
                        color: Color(0xFFFF5252),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.dialogue,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
