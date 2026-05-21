import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../models/player_state.dart';
import '../struggler_game.dart';

/// HUD overlay showing health, resolve, stamina, level, and counters.
class GameHud extends PositionComponent with HasGameReference<StruggleGame> {
  final PlayerState playerState;
  final int currentLevel;

  GameHud({required this.playerState, required this.currentLevel})
    : super(
        position: Vector2(16, 16),
        size: Vector2(
          300,
          105,
        ), // Increased height to house stamina and new counters
        priority: 100, // Render on top
      );

  // Tracked states to detect changes and rebuild/re-layout TextPainters
  double _lastHealth = -1;
  double _lastMaxHealth = -1;
  double _lastResolve = -1;
  double _lastMaxResolve = -1;
  double _lastStamina = -1;
  double _lastMaxStamina = -1;
  bool _lastIsIndomitable = false;
  int _lastLevel = -1;
  int _lastEnemiesCount = -1;
  int _lastHealsCount = -1;
  int _lastHealsMax = -1;
  int _lastDeathCount = -1;
  int _lastDiamondsCount = -1;
  int _lastWillpowerCount = -1;

  // Cached TextPainters
  late final TextPainter _hpLabelPainter;
  late final TextPainter _rsLabelPainter;
  late final TextPainter _stLabelPainter;

  late final TextPainter _hpTextPainter;
  late final TextPainter _rsTextPainter;
  late final TextPainter _stTextPainter;
  late final TextPainter _levelTextPainter;
  late final TextPainter _enemiesTextPainter;
  late final TextPainter _healsTextPainter;
  late final TextPainter _deathsTextPainter;
  late final TextPainter _diamondsTextPainter;
  late final TextPainter _willpowerTextPainter;

  final Paint _barBgPaint = Paint();
  final Paint _barFillPaint = Paint();
  final Paint _barBorderPaint = Paint()
    ..color = const Color(0xFF666666)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  bool _isFullyLoaded = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Static labels
    _hpLabelPainter = _createTextPainter('HP', 11, color: const Color(0xFFCCCCCC));
    _hpLabelPainter.layout();
    _rsLabelPainter = _createTextPainter('RS', 11, color: const Color(0xFFCCCCCC));
    _rsLabelPainter.layout();
    _stLabelPainter = _createTextPainter('ST', 11, color: const Color(0xFFCCCCCC));
    _stLabelPainter.layout();

    // Dynamic TextPainters (initially with empty or placeholder values, we will layout on update)
    _hpTextPainter = _createTextPainter('', 10);
    _rsTextPainter = _createTextPainter('', 10);
    _stTextPainter = _createTextPainter('', 10);
    _levelTextPainter = _createTextPainter('', 13);
    _enemiesTextPainter = _createTextPainter('', 12);
    _healsTextPainter = _createTextPainter('', 12);
    _deathsTextPainter = _createTextPainter('', 10);
    _diamondsTextPainter = _createTextPainter('', 10);
    _willpowerTextPainter = _createTextPainter('', 10);

    _isFullyLoaded = true;
  }

  TextPainter _createTextPainter(String text, double fontSize, {Color color = const Color(0xFFDDDDDD)}) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void _updateText(TextPainter painter, String text, double fontSize, Color color) {
    painter.text = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    );
    painter.layout();
  }

  @override
  void update(double dt) {
    if (!_isFullyLoaded) return;
    super.update(dt);

    // 1. Health
    final health = playerState.health;
    final maxHealth = playerState.maxHealth;
    if (health != _lastHealth || maxHealth != _lastMaxHealth) {
      _lastHealth = health;
      _lastMaxHealth = maxHealth;
      _updateText(
        _hpTextPainter,
        '${health.round()}/${maxHealth.round()}',
        10,
        const Color(0xFFDDDDDD),
      );
    }

    // 2. Resolve
    final resolve = playerState.resolve;
    final maxResolve = playerState.maxResolve;
    final isIndomitable = playerState.isIndomitable;
    if (resolve != _lastResolve || maxResolve != _lastMaxResolve || isIndomitable != _lastIsIndomitable) {
      _lastResolve = resolve;
      _lastMaxResolve = maxResolve;
      _lastIsIndomitable = isIndomitable;
      _updateText(
        _rsTextPainter,
        '${resolve.round()}/${maxResolve.round()}',
        10,
        const Color(0xFFDDDDDD),
      );
    }

    // 3. Stamina
    final stamina = playerState.stamina;
    final maxStamina = playerState.maxStamina;
    if (stamina != _lastStamina || maxStamina != _lastMaxStamina) {
      _lastStamina = stamina;
      _lastMaxStamina = maxStamina;
      _updateText(
        _stTextPainter,
        '${stamina.round()}/${maxStamina.round()}',
        10,
        const Color(0xFFDDDDDD),
      );
    }

    // 4. Level
    if (currentLevel != _lastLevel) {
      _lastLevel = currentLevel;
      _updateText(_levelTextPainter, 'LEVEL $currentLevel', 13, const Color(0xFFDDDDDD));
    }

    // 5. Enemy Counter
    final enemiesRemaining = game.cachedAliveEnemiesCount;
    if (enemiesRemaining != _lastEnemiesCount) {
      _lastEnemiesCount = enemiesRemaining;
      _updateText(
        _enemiesTextPainter,
        'ENEMIES: $enemiesRemaining',
        12,
        enemiesRemaining <= 0
            ? const Color(0xFF44FF44)
            : const Color(0xFFFF5555),
      );
    }

    // 6. Hope Heals
    final healsRemaining = playerState.catHealsRemaining;
    final healsMax = playerState.catHealsMax;
    if (healsRemaining != _lastHealsCount || healsMax != _lastHealsMax) {
      _lastHealsCount = healsRemaining;
      _lastHealsMax = healsMax;
      _updateText(
        _healsTextPainter,
        'HEALS: $healsRemaining/$healsMax',
        12,
        healsRemaining > 0
            ? const Color(0xFF00FF88)
            : const Color(0xFFFF5555),
      );
    }

    // 7. Death Count
    final deathCount = playerState.deathCount;
    if (deathCount != _lastDeathCount) {
      _lastDeathCount = deathCount;
      _updateText(_deathsTextPainter, 'DEATHS: $deathCount', 10, const Color(0xFF888888));
    }

    // 8. Diamonds
    final diamondsCount = playerState.diamondsCollected;
    if (diamondsCount != _lastDiamondsCount) {
      _lastDiamondsCount = diamondsCount;
      _updateText(_diamondsTextPainter, 'DIAMONDS: $diamondsCount', 10, const Color(0xFF00E5FF));
    }

    // 9. Willpower
    final willpowerCount = playerState.willpower;
    if (willpowerCount != _lastWillpowerCount) {
      _lastWillpowerCount = willpowerCount;
      _updateText(_willpowerTextPainter, 'WILL: $willpowerCount', 10, const Color(0xFFFF5722));
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_isFullyLoaded) return;
    // --- Health Bar ---
    _hpLabelPainter.paint(canvas, const Offset(0, 0));
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
    _hpTextPainter.paint(canvas, const Offset(185, 0));

    // --- Resolve Bar ---
    _rsLabelPainter.paint(canvas, const Offset(0, 22));
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
    _rsTextPainter.paint(canvas, const Offset(185, 22));

    // --- Stamina Bar ---
    _stLabelPainter.paint(canvas, const Offset(0, 44));
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
    _stTextPainter.paint(canvas, const Offset(185, 44));

    // --- Level Indicator ---
    _levelTextPainter.paint(canvas, const Offset(0, 68));

    // --- Enemy Counter ---
    _enemiesTextPainter.paint(canvas, const Offset(105, 68));

    // --- Hope Heals Counter ---
    _healsTextPainter.paint(canvas, const Offset(210, 68));

    // --- Death Count ---
    _deathsTextPainter.paint(canvas, const Offset(0, 88));

    // --- Diamond count ---
    _diamondsTextPainter.paint(canvas, const Offset(110, 88));

    // --- Willpower count ---
    _willpowerTextPainter.paint(canvas, const Offset(190, 88));
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
    _barBgPaint.color = bgColor;
    canvas.drawRect(
      Rect.fromLTWH(x, y, width, height),
      _barBgPaint,
    );
    // Fill
    _barFillPaint.color = fillColor;
    canvas.drawRect(
      Rect.fromLTWH(x, y, width * percent.clamp(0, 1), height),
      _barFillPaint,
    );
    // Border
    canvas.drawRect(
      Rect.fromLTWH(x, y, width, height),
      _barBorderPaint,
    );
  }
}
