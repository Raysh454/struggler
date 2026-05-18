import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../models/player_state.dart';
import '../struggler_game.dart';
import '../components/enemy.dart';

/// HUD overlay showing health, resolve, stamina, level, and counters.
class GameHud extends PositionComponent with HasGameReference<StruggleGame> {
  final PlayerState playerState;
  final int currentLevel;

  GameHud({
    required this.playerState,
    required this.currentLevel,
  }) : super(
          position: Vector2(16, 16),
          size: Vector2(300, 105), // Increased height to house stamina and new counters
          priority: 100, // Render on top
        );

  @override
  void render(Canvas canvas) {
    // --- Health Bar ---
    _drawLabel(canvas, 'HP', 0, 0);
    _drawBar(
      canvas,
      x: 30,
      y: 0,
      width: 150,
      height: 14,
      percent: playerState.health / playerState.maxHealth,
      fillColor: const Color(0xFFFF3344),
      bgColor: const Color(0xFF331111),
    );
    // Health text
    _drawText(
      canvas,
      '${playerState.health.round()}/${playerState.maxHealth.round()}',
      185,
      0,
      10,
    );

    // --- Resolve Bar ---
    _drawLabel(canvas, 'RS', 0, 22);
    final resolveColor = playerState.isIndomitable
        ? const Color(0xFFFF2222) // Pulsing red when active
        : const Color(0xFF4488FF);
    _drawBar(
      canvas,
      x: 30,
      y: 22,
      width: 150,
      height: 14,
      percent: playerState.resolve / playerState.maxResolve,
      fillColor: resolveColor,
      bgColor: const Color(0xFF111133),
    );
    _drawText(
      canvas,
      '${playerState.resolve.round()}/${playerState.maxResolve.round()}',
      185,
      22,
      10,
    );

    // --- Stamina Bar ---
    _drawLabel(canvas, 'ST', 0, 44);
    _drawBar(
      canvas,
      x: 30,
      y: 44,
      width: 150,
      height: 14,
      percent: playerState.stamina / playerState.maxStamina,
      fillColor: const Color(0xFF33CC66),
      bgColor: const Color(0xFF113311),
    );
    // Stamina text
    _drawText(
      canvas,
      '${playerState.stamina.round()}/${playerState.maxStamina.round()}',
      185,
      44,
      10,
    );

    // --- Level Indicator ---
    _drawText(canvas, 'LEVEL $currentLevel', 0, 68, 13);

    // --- Enemy Counter ---
    final enemiesRemaining = game.world.children.whereType<BaseEnemy>().where((e) => !e.isDead).length;
    _drawText(
      canvas,
      'ENEMIES: $enemiesRemaining',
      105,
      68,
      12,
      color: enemiesRemaining == 0 ? const Color(0xFF44FF44) : const Color(0xFFFF5555),
    );

    // --- Hope Heals Counter ---
    final healsRemaining = playerState.catHealsRemaining;
    _drawText(
      canvas,
      'HEALS: $healsRemaining/${playerState.catHealsMax}',
      210,
      68,
      12,
      color: healsRemaining > 0 ? const Color(0xFF00FF88) : const Color(0xFFFF5555),
    );

    // --- Death Count ---
    _drawText(
      canvas,
      'DEATHS: ${playerState.deathCount}',
      0,
      88,
      10,
      color: const Color(0xFF888888),
    );

    // --- Diamond count ---
    _drawText(
      canvas,
      'DIAMONDS: ${playerState.diamondsCollected}',
      110,
      88,
      10,
      color: const Color(0xFF00E5FF), // Cyan/Diamond color
    );

    // --- Willpower count ---
    _drawText(
      canvas,
      'WILL: ${playerState.willpower}',
      190,
      88,
      10,
      color: const Color(0xFFFF5722),
    );
  }

  void _drawBar(
    Canvas canvas, {
    required double x,
    required double y,
    required double width,
    required double height,
    required double percent,
    required Color fillColor,
    required Color bgColor,
  }) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(x, y, width, height),
      Paint()..color = bgColor,
    );
    // Fill
    canvas.drawRect(
      Rect.fromLTWH(x, y, width * percent.clamp(0, 1), height),
      Paint()..color = fillColor,
    );
    // Border
    canvas.drawRect(
      Rect.fromLTWH(x, y, width, height),
      Paint()
        ..color = const Color(0xFF666666)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawLabel(Canvas canvas, String text, double x, double y) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFFCCCCCC),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x, y));
  }

  void _drawText(
    Canvas canvas,
    String text,
    double x,
    double y,
    double fontSize, {
    Color color = const Color(0xFFDDDDDD),
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x, y));
  }
}
