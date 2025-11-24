import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rhythm_coach/services/ai_coaching_service.dart';
import 'package:ai_rhythm_coach/models/tap_event.dart';
import 'package:http/http.dart' as http;

class MockHttpClient extends Fake implements http.Client {}

void main() {
  group('AICoachingService Tests', () {
    late AICoachingService service;

    setUp(() {
      service = AICoachingService(MockHttpClient());
    });

    test('generateCoaching returns mock response when API key is not configured', () async {
      // Arrange
      final tapEvents = [
        TapEvent(actualTime: 0.5, expectedTime: 0.5, error: 0.0),
        TapEvent(actualTime: 1.0, expectedTime: 1.0, error: 0.0),
      ];

      // Act
      final result = await service.generateCoaching(
        bpm: 120,
        tapEvents: tapEvents,
        averageError: 0.0,
        consistency: 0.0,
      );

      // Assert
      expect(result, contains('This is a simulated coaching response'));
      expect(result, contains('Great effort!'));
    });
  });
}
