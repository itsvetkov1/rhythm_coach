import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tap_event.dart';
import '../config.dart';

class AIServiceException implements Exception {
  final String message;
  AIServiceException(this.message);
  @override
  String toString() => 'AIServiceException: $message';
}

class AICoachingService {
  final http.Client _client;

  AICoachingService(this._client);

  // Generate coaching text from session data
  Future<String> generateCoaching({
    required int bpm,
    required List<TapEvent> tapEvents,
    required double averageError,
    required double consistency,
  }) async {
    try {
      // Build prompt with session data
      final prompt = _buildPrompt(
        bpm: bpm,
        tapEvents: tapEvents,
        averageError: averageError,
        consistency: consistency,
      );

      // Call appropriate AI API based on config
      if (AIConfig.provider == AIProvider.anthropic) {
        return await _callClaudeAPI(prompt);
      } else {
        return await _callOpenAIAPI(prompt);
      }
    } catch (e) {
      throw AIServiceException('Failed to generate coaching: $e');
    }
  }

  // Build coaching prompt
  String _buildPrompt({
    required int bpm,
    required List<TapEvent> tapEvents,
    required double averageError,
    required double consistency,
  }) {
    // Calculate additional metrics
    final earlyCount = tapEvents.where((t) => t.isEarly).length;
    final lateCount = tapEvents.where((t) => t.isLate).length;
    final onTimeCount = tapEvents.where((t) => t.isOnTime).length;

    // Get first 10 timing errors for pattern analysis
    final timingErrorsSample = tapEvents.take(10).map((e) {
      return e.error.toStringAsFixed(1);
    }).join(', ');

    return '''You are a professional rhythm coach analyzing a drummer's practice session.

Session Details:
- Tempo: $bpm BPM
- Total beats detected: ${tapEvents.length}
- Average timing error: ${averageError.toStringAsFixed(2)}ms
- Consistency (std dev): ${consistency.toStringAsFixed(2)}ms
- Early hits: $earlyCount
- Late hits: $lateCount
- On-time hits (±10ms): $onTimeCount

Timing Errors (first 10 beats, in milliseconds):
$timingErrorsSample

Provide encouraging, actionable coaching feedback (2-3 sentences) focusing on:
1. What they did well
2. Primary area for improvement
3. Specific practice suggestion

Keep the tone positive and motivational.''';
  }

  // Call Anthropic Claude API
  Future<String> _callClaudeAPI(String prompt) async {
    if (AIConfig.anthropicApiKey == 'YOUR_ANTHROPIC_API_KEY_HERE') {
      throw AIServiceException(
          'Anthropic API key not configured. Please update lib/config.dart');
    }

    try {
      final response = await _client.post(
        Uri.parse(AIConfig.anthropicEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': AIConfig.anthropicApiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': AIConfig.anthropicModel,
          'max_tokens': 300,
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'];
      } else {
        throw AIServiceException(
            'Claude API error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw AIServiceException('Failed to call Claude API: $e');
    }
  }

  // Call OpenAI GPT API
  Future<String> _callOpenAIAPI(String prompt) async {
    if (AIConfig.openaiApiKey == 'YOUR_OPENAI_API_KEY_HERE') {
      throw AIServiceException(
          'OpenAI API key not configured. Please update lib/config.dart');
    }

    try {
      final response = await _client.post(
        Uri.parse(AIConfig.openaiEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AIConfig.openaiApiKey}',
        },
        body: jsonEncode({
          'model': AIConfig.openaiModel,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a professional rhythm coach helping drummers improve.',
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'max_tokens': 300,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        throw AIServiceException(
            'OpenAI API error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw AIServiceException('Failed to call OpenAI API: $e');
    }
  }
}
