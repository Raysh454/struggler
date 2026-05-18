import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:struggler/game/level/level_data.dart';
import 'prompts.dart';

class ArchitectAgent {
  late final GenerativeModel _model;
  
  ArchitectAgent() {
    const apiKey = String.fromEnvironment('GEMINI_API_KEY');
    if (apiKey.isEmpty) {
      print('WARNING: GEMINI_API_KEY not found in environment.');
    }
    
    // We expect the model to return JSON that matches our schema.
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(architectPrompt),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );
  }

  /// Generates the next level data based on telemetry.
  Future<Map<String, dynamic>?> generateNextLevel(Map<String, dynamic> telemetry) async {
    try {
      final prompt = jsonEncode(telemetry);
      final response = await _model.generateContent([Content.text(prompt)]);
      
      final text = response.text;
      if (text == null) return null;
      
      final jsonResponse = jsonDecode(text) as Map<String, dynamic>;
      
      // Print the reasoning out for the Hackathon judges to see the "Agentic" edge.
      if (jsonResponse.containsKey('reasoning')) {
        print('\n=== THE ARCHITECT REASONING ===\n${jsonResponse['reasoning']}\n===============================\n');
      }
      
      return jsonResponse;
      
    } catch (e) {
      print('Architect Agent failed to generate level: $e');
      return null;
    }
  }
}
