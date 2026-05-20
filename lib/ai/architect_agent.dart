import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'prompts.dart';

/// The Antigravity Agent ("The Architect") — Core AI Orchestrator.
///
/// Communicates with Gemini via a Cloud Functions relay gateway to generate
/// map layouts and dynamically tune difficulty based on player telemetry.
class ArchitectAgent {
  static const String _relayUrl =
      'https://us-central1-struggler-496812.cloudfunctions.net/architect-relay';

  ArchitectAgent();

  /// Phase 1: Generate the map layout for the next level.
  Future<Map<String, dynamic>?> generateMapLayout(
    Map<String, dynamic> telemetry,
  ) async {
    return _generateViaRelay(telemetry, architectMapPrompt, 'MapLayout');
  }

  /// Phase 2: Generate difficulty tuning based on live current-level telemetry.
  Future<Map<String, dynamic>?> generateDifficulty(
    Map<String, dynamic> telemetry,
  ) async {
    return _generateViaRelay(telemetry, architectDifficultyPrompt, 'Difficulty');
  }

  // ═══════════════════════════════════════════════════════════════
  // Relay Gateway Communication
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> _generateViaRelay(
    Map<String, dynamic> telemetry,
    String systemPrompt,
    String phase,
  ) async {
    final targetLevel = telemetry['targetLevel'] ?? '?';
    _logRequest(phase, targetLevel, telemetry);

    try {
      final requestBody = {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': jsonEncode(telemetry)}
            ]
          }
        ],
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt}
          ]
        },
        'generationConfig': {
          'responseMimeType': 'application/json'
        }
      };

      final response = await http.post(
        Uri.parse(_relayUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        _logError(phase, targetLevel,
            'HTTP ${response.statusCode}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
        return null;
      }

      final responseBody = jsonDecode(response.body);

      // Extract text — handle both Vertex AI format and simplified relay format
      String? text;
      if (responseBody is Map) {
        if (responseBody.containsKey('candidates')) {
          text = responseBody['candidates']?[0]?['content']?['parts']?[0]
              ?['text'] as String?;
        } else if (responseBody.containsKey('text')) {
          text = responseBody['text'] as String?;
        }
      }

      if (text == null) {
        _logError(phase, targetLevel, 'Empty response from relay.');
        return null;
      }

      // Strip markdown code fences if the model wrapped its response
      var cleanedText = text.trim();
      if (cleanedText.startsWith('```')) {
        cleanedText = cleanedText.replaceFirst(RegExp(r'^```\w*\n?'), '');
        cleanedText = cleanedText.replaceFirst(RegExp(r'\n?```$'), '');
        cleanedText = cleanedText.trim();
      }

      // Strip JS-style // comments that the model sometimes injects
      cleanedText = _stripJsonComments(cleanedText);

      final sanitizedText = _sanitizeJsonString(cleanedText);
      final decoded = jsonDecode(sanitizedText);

      // Handle both Map and List (extract first element if array)
      Map<String, dynamic> jsonResponse;
      if (decoded is Map<String, dynamic>) {
        jsonResponse = decoded;
      } else if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
        jsonResponse = Map<String, dynamic>.from(decoded.first as Map);
      } else {
        _logError(phase, targetLevel, 'Unexpected response type: ${decoded.runtimeType}');
        return null;
      }
      // Debug: show what keys the AI actually returned
      print('│  🔍 Response keys: ${jsonResponse.keys.toList()}');

      _logResponse(phase, targetLevel, jsonResponse);

      // Fire-and-forget logging — synchronous writes, never blocks the game loop
      _logSync(telemetry, jsonResponse, phase);

      return jsonResponse;
    } catch (e) {
      _logError(phase, targetLevel, '$e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Pretty Logging for Demo
  // ═══════════════════════════════════════════════════════════════

  void _logRequest(
      String phase, dynamic targetLevel, Map<String, dynamic> telemetry) {
    final emoji = phase == 'MapLayout' ? '🗺️' : '⚡';
    final gameProgress = telemetry['gameProgress'] as Map<String, dynamic>?;
    final deaths = gameProgress?['totalDeaths'] ?? '?';
    final gamePhase = gameProgress?['gamePhase'] ?? '?';
    final diamonds = gameProgress?['diamondsCollected'] ?? '?';

    print('');
    print(
        '┌───────────────────────────────────────────────────────────');
    print(
        '│  $emoji  ANTIGRAVITY AGENT ─ $phase Request (Level $targetLevel)');
    print(
        '├───────────────────────────────────────────────────────────');
    print('│  🎯 Target Level: $targetLevel');
    print('│  💀 Total Deaths: $deaths  │  💎 Diamonds: $diamonds');
    print('│  📖 Narrative Phase: $gamePhase');

    // Show live performance stats for difficulty phase
    if (phase == 'Difficulty') {
      final perf =
          telemetry['currentLevelPerformance'] as Map<String, dynamic>?;
      if (perf != null) {
        final hp = perf['healthPercent'] ?? '?';
        final dodges = perf['perfectDodgesSoFar'] ?? '?';
        final defeated = perf['enemiesDefeatedSoFar'] ?? '?';
        final total = perf['totalEnemiesInLevel'] ?? '?';
        final levelDeaths = perf['deathsThisLevel'] ?? '?';
        print(
            '│  ❤️  Health: $hp%  │  🛡️ Dodges: $dodges  │  ☠️ Deaths This Level: $levelDeaths');
        print('│  ⚔️  Enemies Defeated: $defeated / $total');
      }
    }

    print(
        '│  🔗 Endpoint: Cloud Functions Relay Gateway');
    print(
        '└───────────────────────────────────────────────────────────');
    print('');
  }

  void _logResponse(
      String phase, dynamic targetLevel, Map<String, dynamic> json) {
    print('');
    print(
        '┌───────────────────────────────────────────────────────────');
    print(
        '│  ✅  ANTIGRAVITY AGENT ─ $phase Response (Level $targetLevel)');
    print(
        '├───────────────────────────────────────────────────────────');

    if (phase == 'MapLayout') {
      final bp = json['levelBlueprint'] as Map<String, dynamic>?;
      final w = bp?['width'] ?? '?';
      final h = bp?['height'] ?? '?';
      final objects = bp?['objects'] as List<dynamic>? ?? [];
      final enemies =
          objects.where((o) => o['type'] == 'ENEMY').length;
      final pickups =
          objects.where((o) => o['type'] == 'PICKUP').length;
      final tiles = bp?['tiles'] as List<dynamic>? ?? [];
      print('│  📐 Blueprint: ${w}×${h} tiles (${tiles.length} tile regions)');
      print('│  👾 Enemies Placed: $enemies  │  💊 Pickups: $pickups');
    } else {
      final diff = json['difficulty'] ?? '?';
      final dmgMult = json['enemyDamageMultiplier'] ?? '?';
      final hpMult = json['enemyHealthMultiplier'] ?? '?';
      final dialogue = json['architectDialogue'] as String?;
      print('│  ⚔️  Difficulty Decision: $diff');
      print('│  💥 Damage ×$dmgMult  │  ❤️  Health ×$hpMult');
      if (dialogue != null && dialogue.isNotEmpty) {
        print('│  💬 Dialogue: "$dialogue"');
      }
      final events = json['narrativeEvents'] as List<dynamic>? ?? [];
      if (events.isNotEmpty) {
        print('│  📜 Narrative Events: ${events.length} taunts queued');
      }
    }

    // Reasoning block
    final reasoning = json['reasoning'] as String?;
    if (reasoning != null && reasoning.isNotEmpty) {
      print(
          '├───────────────────────────────────────────────────────────');
      print('│  🧠 Architect Reasoning:');
      for (final line in _wordWrap(reasoning, 55)) {
        print('│     $line');
      }
    }

    print(
        '└───────────────────────────────────────────────────────────');
    print('');
  }

  void _logError(String phase, dynamic targetLevel, String message) {
    print('');
    print(
        '┌───────────────────────────────────────────────────────────');
    print(
        '│  ❌  ANTIGRAVITY AGENT ─ $phase Error (Level $targetLevel)');
    print(
        '├───────────────────────────────────────────────────────────');
    for (final line in _wordWrap(message, 55)) {
      print('│  $line');
    }
    print(
        '└───────────────────────────────────────────────────────────');
    print('');
  }

  List<String> _wordWrap(String text, int maxWidth) {
    final words = text.split(' ');
    final lines = <String>[];
    var current = StringBuffer();
    for (final word in words) {
      if (current.length + word.length + 1 > maxWidth &&
          current.isNotEmpty) {
        lines.add(current.toString());
        current = StringBuffer();
      }
      if (current.isNotEmpty) current.write(' ');
      current.write(word);
    }
    if (current.isNotEmpty) lines.add(current.toString());
    return lines;
  }

  // ═══════════════════════════════════════════════════════════════
  // JSON Comment Stripping
  // ═══════════════════════════════════════════════════════════════

  /// Strips // line comments from JSON text, respecting string literals.
  String _stripJsonComments(String json) {
    final lines = json.split('\n');
    final result = <String>[];
    for (final line in lines) {
      if (line.trimLeft().startsWith('//')) continue; // Pure comment line
      // Find // outside of string literals
      int? commentStart;
      bool inString = false;
      bool escaped = false;
      for (int i = 0; i < line.length - 1; i++) {
        if (escaped) { escaped = false; continue; }
        if (line[i] == '\\') { escaped = true; continue; }
        if (line[i] == '"') { inString = !inString; continue; }
        if (!inString && line[i] == '/' && line[i + 1] == '/') {
          commentStart = i;
          break;
        }
      }
      result.add(commentStart != null ? line.substring(0, commentStart) : line);
    }
    return result.join('\n');
  }

  // ═══════════════════════════════════════════════════════════════
  // File Logging
  // ═══════════════════════════════════════════════════════════════

  /// Synchronous, non-blocking log writer.
  void _logSync(
    Map<String, dynamic> input,
    Map<String, dynamic> output,
    String phase,
  ) {
    // Disabled on mobile to prevent lag and FileSystemExceptions.
    return;
  }

  // ═══════════════════════════════════════════════════════════════
  // JSON Sanitization
  // ═══════════════════════════════════════════════════════════════

  String _sanitizeJsonString(String rawJson) {
    final buffer = StringBuffer();
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < rawJson.length; i++) {
      final char = rawJson[i];
      final code = char.codeUnitAt(0);

      if (escaped) {
        buffer.write(char);
        escaped = false;
        continue;
      }

      if (char == '\\') {
        buffer.write(char);
        if (inString) {
          escaped = true;
        }
        continue;
      }

      if (char == '"') {
        inString = !inString;
        buffer.write(char);
        continue;
      }

      if (inString) {
        if (code < 32) {
          if (char == '\n') {
            buffer.write(r'\n');
          } else if (char == '\r') {
            buffer.write(r'\r');
          } else if (char == '\t') {
            buffer.write(r'\t');
          }
        } else {
          buffer.write(char);
        }
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }
}
