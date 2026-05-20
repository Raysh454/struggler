import 'dart:convert';
import 'dart:io';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:google_generative_ai/google_generative_ai.dart' as google_vertex;
import 'prompts.dart';

class ArchitectAgent {
  auth.AutoRefreshingAuthClient? _authClient;
  String _projectId = 'struggler-496812';
  final String _location = 'us-central1';
  bool _useVertexAdc = false;

  // Fallback models when not using ADC
  google_vertex.GenerativeModel? _fallbackMapModel;
  google_vertex.GenerativeModel? _fallbackDifficultyModel;

  Future<void>? _initFuture;

  ArchitectAgent() {
    _ensureInitialized();
  }

  Future<void> _ensureInitialized() {
    _initFuture ??= _initAgent();
    return _initFuture!;
  }

  Future<void> _initAgent() async {
    final apiKey = Platform.environment['GEMINI_API_KEY'] ?? '';
    if (apiKey.isNotEmpty) {
      _useVertexAdc = false;
      print('[ArchitectAgent] Found GEMINI_API_KEY in environment variables. Bypassing ADC and using standard Google Generative AI REST client.');
      
      _fallbackMapModel = google_vertex.GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        systemInstruction: google_vertex.Content.system(architectMapPrompt),
        generationConfig: google_vertex.GenerationConfig(responseMimeType: 'application/json'),
        requestOptions: const google_vertex.RequestOptions(apiVersion: 'v1beta'),
      );

      _fallbackDifficultyModel = google_vertex.GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        systemInstruction: google_vertex.Content.system(architectDifficultyPrompt),
        generationConfig: google_vertex.GenerationConfig(responseMimeType: 'application/json'),
        requestOptions: const google_vertex.RequestOptions(apiVersion: 'v1beta'),
      );
      return;
    }

    try {
      // 1. Try to find the local project ID from gcloud credentials
      _projectId = _getProjectId();
      print('[ArchitectAgent] Found GCP Project ID: $_projectId');

      // 2. Initialize ADC credentials
      final scopes = ['https://www.googleapis.com/auth/cloud-platform'];
      _authClient = await auth.clientViaApplicationDefaultCredentials(scopes: scopes);
      _useVertexAdc = true;
      print('[ArchitectAgent] Authenticated successfully with Application Default Credentials (ADC) via gcloud.');
    } catch (e) {
      _useVertexAdc = false;
      print('[ArchitectAgent] ADC Authentication not available or failed: $e');
      print('[ArchitectAgent] Falling back to standard Google Generative AI REST client...');
      
      _fallbackMapModel = google_vertex.GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        systemInstruction: google_vertex.Content.system(architectMapPrompt),
        generationConfig: google_vertex.GenerationConfig(responseMimeType: 'application/json'),
        requestOptions: const google_vertex.RequestOptions(apiVersion: 'v1beta'),
      );

      _fallbackDifficultyModel = google_vertex.GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        systemInstruction: google_vertex.Content.system(architectDifficultyPrompt),
        generationConfig: google_vertex.GenerationConfig(responseMimeType: 'application/json'),
        requestOptions: const google_vertex.RequestOptions(apiVersion: 'v1beta'),
      );
    }
  }

  /// Helper to dynamically parse project ID from the local ADC file.
  String _getProjectId() {
    // 1. Check GOOGLE_APPLICATION_CREDENTIALS environment variable
    final envPath = Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'];
    if (envPath != null && envPath.isNotEmpty) {
      try {
        final file = File(envPath);
        if (file.existsSync()) {
          final json = jsonDecode(file.readAsStringSync());
          if (json['project_id'] != null) return json['project_id'] as String;
          if (json['quota_project_id'] != null) return json['quota_project_id'] as String;
        }
      } catch (_) {}
    }

    // 2. Check standard local paths for gcloud auth
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    final paths = [
      '$home/.config/gcloud/application_default_credentials.json',
      '$home/AppData/Roaming/gcloud/application_default_credentials.json',
    ];

    for (final path in paths) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          final json = jsonDecode(file.readAsStringSync());
          if (json['project_id'] != null) return json['project_id'] as String;
          if (json['quota_project_id'] != null) return json['quota_project_id'] as String;
        }
      } catch (_) {}
    }

    // Default fallback
    return 'struggler-496812';
  }

  /// Phase 1: Generate the map layout for the next level.
  Future<Map<String, dynamic>?> generateMapLayout(
    Map<String, dynamic> telemetry,
  ) async {
    await _ensureInitialized();
    final targetLevel = telemetry['targetLevel'] ?? 'unknown';
    print('[ArchitectAgent] Dispatching MapLayout request to AI Architect for Level $targetLevel (Vertex ADC: $_useVertexAdc)...');
    if (_useVertexAdc) {
      return _generateVertexAdc(telemetry, architectMapPrompt, 'MapLayout');
    } else {
      return _generateFallback(_fallbackMapModel, telemetry, 'MapLayout');
    }
  }

  /// Phase 2: Generate difficulty tuning based on live current-level telemetry.
  Future<Map<String, dynamic>?> generateDifficulty(
    Map<String, dynamic> telemetry,
  ) async {
    await _ensureInitialized();
    final targetLevel = telemetry['targetLevel'] ?? 'unknown';
    print('[ArchitectAgent] Dispatching Difficulty request to AI Architect for Level $targetLevel (Vertex ADC: $_useVertexAdc)...');
    if (_useVertexAdc) {
      return _generateVertexAdc(telemetry, architectDifficultyPrompt, 'Difficulty');
    } else {
      return _generateFallback(_fallbackDifficultyModel, telemetry, 'Difficulty');
    }
  }

  /// Vertex AI REST API call via Application Default Credentials (ADC)
  Future<Map<String, dynamic>?> _generateVertexAdc(
    Map<String, dynamic> telemetry,
    String systemPrompt,
    String phase,
  ) async {
    try {
      if (_authClient == null) {
        // Ensure initialized
        await _initAgent();
        if (_authClient == null) return null;
      }

      final url = Uri.parse(
        'https://$_location-aiplatform.googleapis.com/v1/projects/$_projectId/locations/$_location/publishers/google/models/gemini-2.5-flash:generateContent',
      );

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

      final targetLevel = telemetry['targetLevel'] ?? 'unknown';
      print('[ArchitectAgent] Sending Vertex ADC HTTP request for Level $targetLevel ($phase)...');
      final response = await _authClient!.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception('Vertex AI REST call failed with status: ${response.statusCode}\nBody: ${response.body}');
      }

      final responseBody = jsonDecode(response.body);
      final text = responseBody['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text == null) {
        print('[ArchitectAgent] Received empty text response from Vertex ADC for Level $targetLevel ($phase).');
        return null;
      }
      print('[ArchitectAgent] Vertex ADC response received successfully for Level $targetLevel ($phase).');

      final sanitizedText = _sanitizeJsonString(text);
      final jsonResponse = jsonDecode(sanitizedText) as Map<String, dynamic>;

      // Print the reasoning for visibility
      if (jsonResponse.containsKey('reasoning')) {
        final targetLevel = telemetry['targetLevel'] ?? 'unknown';
        print(
          '\n=== THE ARCHITECT REASONING ($phase for Level $targetLevel) ===\n${jsonResponse['reasoning']}\n===============================\n',
        );
      }

      // Fire-and-forget logging — synchronous writes, never blocks the game loop
      _logSync(telemetry, jsonResponse, phase);

      return jsonResponse;
    } catch (e) {
      final targetLevel = telemetry['targetLevel'] ?? 'unknown';
      print('[ArchitectAgent] Vertex ADC call failed for Level $targetLevel ($phase): $e');
      // Attempt fallback if ADC failed dynamically
      if (phase == 'MapLayout' && _fallbackMapModel != null) {
        print('[ArchitectAgent] Attempting fallback model for Level $targetLevel ($phase)...');
        return _generateFallback(_fallbackMapModel, telemetry, phase);
      } else if (phase == 'Difficulty' && _fallbackDifficultyModel != null) {
        print('[ArchitectAgent] Attempting fallback model for Level $targetLevel ($phase)...');
        return _generateFallback(_fallbackDifficultyModel, telemetry, phase);
      }
      return null;
    }
  }

  /// Shared fallback generation logic using standard google_generative_ai REST client.
  Future<Map<String, dynamic>?> _generateFallback(
    google_vertex.GenerativeModel? model,
    Map<String, dynamic> telemetry,
    String phase,
  ) async {
    if (model == null) return null;
    final targetLevel = telemetry['targetLevel'] ?? 'unknown';
    print('[ArchitectAgent] Sending fallback REST API request for Level $targetLevel ($phase)...');
    try {
      final prompt = jsonEncode(telemetry);
      final response = await model.generateContent([google_vertex.Content.text(prompt)]);

      final text = response.text;
      if (text == null) {
        print('[ArchitectAgent] Received empty text response from fallback REST client for Level $targetLevel ($phase).');
        return null;
      }
      print('[ArchitectAgent] Fallback REST client response received successfully for Level $targetLevel ($phase).');

      final sanitizedText = _sanitizeJsonString(text);
      final jsonResponse = jsonDecode(sanitizedText) as Map<String, dynamic>;

      // Print the reasoning for visibility
      if (jsonResponse.containsKey('reasoning')) {
        final targetLevel = telemetry['targetLevel'] ?? 'unknown';
        print(
          '\n=== THE ARCHITECT REASONING ($phase for Level $targetLevel) ===\n${jsonResponse['reasoning']}\n===============================\n',
        );
      }

      // Fire-and-forget logging — synchronous writes, never blocks the game loop
      _logSync(telemetry, jsonResponse, phase);

      return jsonResponse;
    } catch (e) {
      print('Architect Agent failed to generate $phase via Fallback API client: $e');
      return null;
    }
  }

  /// Synchronous, non-blocking log writer.
  void _logSync(
    Map<String, dynamic> input,
    Map<String, dynamic> output,
    String phase,
  ) {
    try {
      final logDir = Directory('logs');
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      final logFile = File('logs/logs.json');
      List<dynamic> logsList = [];
      if (logFile.existsSync()) {
        final contents = logFile.readAsStringSync();
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
        'phase': phase,
        'input_telemetry': input,
        'output_response': output,
      });

      logFile.writeAsStringSync(jsonEncode(logsList));
    } catch (logErr) {
      print('Failed to write to logs/logs.json: $logErr');
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
