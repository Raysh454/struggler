import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../models/player_state.dart';

/// HUD overlay showing health, resolve, level, and death count.
class GameHud extends PositionComponent {
  final PlayerState playerState;
  final int currentLevel;

  GameHud({
    required this.playerState,
    required this.currentLevel,
  }) : super(
          position: Vector2(16, 16),
          size: Vector2(300, 80),
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

    // --- Level Indicator ---
    _drawText(canvas, 'LEVEL $currentLevel', 0, 48, 14);

    // --- Death Count ---
    _drawText(
      canvas,
      'DEATHS: ${playerState.deathCount}',
      0,
      66,
      10,
      color: const Color(0xFF888888),
    );

    // --- Ore count ---
    _drawText(
      canvas,
      'ORE: ${playerState.oreCollected}',
      130,
      66,
      10,
      color: const Color(0xFFFFB028),
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
