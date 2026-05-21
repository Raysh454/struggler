import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/struggler_game.dart';
import 'game/systems/audio_manager.dart';
import 'screens/game_overlays.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to landscape for a platformer
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Hide system UI for immersive experience
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const StruggleApp());
}

class StruggleApp extends StatefulWidget {
  const StruggleApp({super.key});

  @override
  State<StruggleApp> createState() => _StruggleAppState();
}

class _StruggleAppState extends State<StruggleApp> {
  late final StruggleGame _game;

  @override
  void initState() {
    super.initState();
    _game = StruggleGame();
  }

  @override
  void dispose() {
    AudioManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Stack(
          children: [
            // Game Widget with configured high-fidelity overlays
            GameWidget(
              game: _game,
              overlayBuilderMap: {
                'MainMenu': (context, StruggleGame game) =>
                    MainMenuOverlay(game: game),
                'GuardianUpgrades': (context, StruggleGame game) =>
                    GuardianUpgradesOverlay(game: game),
                'ArchitectTopRightDialogue': (context, StruggleGame game) =>
                    TopRightDialogueOverlay(
                      dialogue: game.currentArchitectDialogue ?? '...',
                      game: game,
                    ),
                'BossChoiceOverlay': (context, StruggleGame game) =>
                    BossChoiceOverlay(game: game),
              },
            ),

            // Touch controls overlay
            ValueListenableBuilder<bool>(
              valueListenable: _game.showControlsNotifier,
              builder: (context, showControls, child) {
                // Hide touch controls when Main Menu or Upgrades screen is open
                if (!showControls) {
                  return const SizedBox.shrink();
                }
                return child!;
              },
              child: _TouchControls(game: _game),
            ),
          ],
        ),
      ),
    );
  }
}

/// On-screen touch controls for mobile play.
class _TouchControls extends StatelessWidget {
  final StruggleGame game;

  const _TouchControls({required this.game});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Row(
        children: [
          // Left side: D-pad (move left/right)
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ControlButton(
                      icon: Icons.arrow_back,
                      onDown: () => game.player.moveLeft = true,
                      onUp: () => game.player.moveLeft = false,
                    ),
                    const SizedBox(width: 8),
                    _ControlButton(
                      icon: Icons.arrow_downward,
                      onDown: () => game.player.downPressed = true,
                      onUp: () => game.player.downPressed = false,
                    ),
                    const SizedBox(width: 8),
                    _ControlButton(
                      icon: Icons.arrow_forward,
                      onDown: () => game.player.moveRight = true,
                      onUp: () => game.player.moveRight = false,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right side: Action buttons
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment
                      .end, // Saps the entire line to the absolute bottom
                  children: [
                    // 1. Bottom-row baseline items: INTERACT and RESOLVE
                    _ControlButton(
                      icon: Icons.auto_awesome,
                      label: 'INTRACT',
                      onDown: () {
                        if (game.isCutscenePlaying) {
                          game.skipCutscene();
                        } else if (game.player.currentPortal != null) {
                          game.transitionThroughPortal(
                            isReturn: game.player.currentPortal!.isReturn,
                          );
                        } else if (game.player.currentExitPortal != null) {
                          final enemiesRemaining = game.cachedAliveEnemiesCount;
                          if (enemiesRemaining <= 0) {
                            game.onLevelComplete();
                          } else {
                            game.onScreenShake(2.0);
                            print('[StruggleGame] Cannot exit level: $enemiesRemaining enemies still alive!');
                          }
                        } else if (game.player.currentGuardian != null) {
                          game.openGuardianUpgrades();
                        }
                      },
                      color: const Color(0xFF00E5FF),
                    ),
                    const SizedBox(width: 8),

                    // 2. Column for HEAL (top) and DODGE (bottom)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ControlButton(
                          icon: Icons.favorite,
                          label: 'HEAL',
                          onDown: () => game.player.triggerHopeHeal(),
                          color: const Color(0xFF00FF88),
                        ),
                        const SizedBox(
                          height: 6,
                        ), // Kept tight to pack them closer
                        _ControlButton(
                          icon: Icons.shield,
                          label: 'DODGE',
                          onDown: () => game.player.dodgePressed = true,
                          color: const Color(0xFF4488FF),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),

                    // 3. Column for JUMP (top) and LARGE ATK (bottom)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ControlButton(
                          icon: Icons.whatshot,
                          label: 'INDOMITABLE',
                          onDown: () => game.player.activateIndomitable(),
                          color: const Color(0xFFFF9900),
                          large: true,
                        ),
                        _ControlButton(
                          icon: Icons.arrow_upward,
                          label: 'JUMP',
                          onDown: () => game.player.jumpPressed = true,
                          color: const Color(0xFF44FF44),
                        ),
                        const SizedBox(
                          height: 6,
                        ), // Kept tight to pack them closer
                        _ControlButton(
                          icon: Icons.flash_on,
                          label: 'ATK',
                          onDown: () => game.player.attackPressed = true,
                          color: const Color(0xFFFF4444),
                          large: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single touch control button with press/release handling.
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onDown;
  final VoidCallback? onUp;
  final Color color;
  final bool large;

  const _ControlButton({
    required this.icon,
    required this.onDown,
    this.onUp,
    this.label,
    this.color = const Color(0xFFCCCCCC),
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = large ? 64.0 : 52.0;

    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp: (_) => onUp?.call(),
      onTapCancel: () => onUp?.call(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withAlpha(60),
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(color: color.withAlpha(120), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color.withAlpha(200), size: large ? 28 : 22),
            if (label != null)
              Text(
                label!,
                style: TextStyle(
                  color: color.withAlpha(180),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
