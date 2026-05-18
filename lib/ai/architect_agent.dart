import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'prompts.dart';

class ArchitectAgent {
  late final GenerativeModel _model;
  late final String apiKey;

  ArchitectAgent() {
    apiKey = Platform.environment['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      print('WARNING: GEMINI_API_KEY not found in environment.');
    }

    // We expect the model to return JSON that matches our schema.
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(architectPrompt),
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );
  }

  /// Generates the next level data based on telemetry.
  Future<Map<String, dynamic>?> generateNextLevel(
    Map<String, dynamic> telemetry,
  ) async {
    if (apiKey.isEmpty) {
      print('WARNING: GEMINI_API_KEY not found in environment.');
      return null;
    }
    try {
      final prompt = jsonEncode(telemetry);
      final response = await _model.generateContent([Content.text(prompt)]);

      final text = response.text;
      if (text == null) return null;

      final sanitizedText = _sanitizeJsonString(text);
      final jsonResponse = jsonDecode(sanitizedText) as Map<String, dynamic>;

      // Print the reasoning out for the Hackathon judges to see the "Agentic" edge.
      if (jsonResponse.containsKey('reasoning')) {
        print(
          '\n=== THE ARCHITECT REASONING ===\n${jsonResponse['reasoning']}\n===============================\n',
        );
      }

      // Log communication to logs/logs.json
      try {
        final logDir = Directory('logs');
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        final logFile = File('logs/logs.json');
        List<dynamic> logsList = [];
        if (await logFile.exists()) {
          final contents = await logFile.readAsString();
          if (contents.isNotEmpty) {
            try {
              logsList = jsonDecode(contents) as List<dynamic>;
            } catch (e) {
              print('Error decoding logs/logs.json, starting fresh: $e');
            }
          }
        }

        logsList.add({
          'timestamp': DateTime.now().toIso8601String(),
          'input_telemetry': telemetry,
          'output_response': jsonResponse,
        });

        print("writing logs to logs/logs.json");
        await logFile.writeAsString(jsonEncode(logsList));
      } catch (logErr) {
        print('Failed to write to logs/logs.json: $logErr');
      }

      return jsonResponse;
    } catch (e) {
      print('Architect Agent failed to generate level: $e');
      return null;
    }
  }

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
        // If we encounter a raw control character inside a string literal, escape it
        if (code < 32) {
          if (char == '\n') {
            buffer.write(r'\n');
          } else if (char == '\r') {
            buffer.write(r'\r');
          } else if (char == '\t') {
            buffer.write(r'\t');
          } else {
            // ignore or omit other invalid characters
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
