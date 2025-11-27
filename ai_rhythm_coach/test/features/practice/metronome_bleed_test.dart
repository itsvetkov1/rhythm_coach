import 'package:flutter_test/flutter_test.dart';
import 'package:ai_rhythm_coach/services/rhythm_analyzer.dart';
import 'package:ai_rhythm_coach/models/tap_event.dart';

void main() {
  group('RhythmAnalyzer Metronome Bleed Detection', () {
    test('Should calculate low consistency for constant latency (metronome bleed)', () {
      // Simulate 60 seconds at 120 BPM = 120 beats
      // Expected beats: 0.0, 0.5, 1.0, ...
      final expectedBeats = List.generate(120, (i) => i * 0.5);
      
      // Simulate actual taps with constant 45ms latency (0.045s)
      // This simulates the microphone picking up the metronome speakers
      final actualTaps = expectedBeats.map((b) => b + 0.045).toList();
      
      // Create TapEvents manually since we can't easily mock the audio file processing
      // to produce exact timestamps without a complex setup.
      // We are testing the statistical analysis part here.
      final tapEvents = <TapEvent>[];
      for (int i = 0; i < expectedBeats.length; i++) {
        tapEvents.add(TapEvent(
          expectedTime: expectedBeats[i],
          actualTime: actualTaps[i],
          error: (actualTaps[i] - expectedBeats[i]) * 1000, // 45ms
        ));
      }

      final averageError = RhythmAnalyzer.calculateAverageError(tapEvents);
      final consistency = RhythmAnalyzer.calculateConsistency(tapEvents);

      print('Average Error: $averageError ms');
      print('Consistency: $consistency ms');

      // Expect average error to be around 45ms
      expect(averageError, closeTo(45.0, 0.1));

      // Expect consistency to be near 0 (perfectly consistent delay)
      expect(consistency, closeTo(0.0, 0.1));
    });

    test('Should calculate higher consistency for human playing', () {
      final expectedBeats = List.generate(120, (i) => i * 0.5);
      
      // Simulate human playing: 45ms latency +/- 10ms jitter
      final tapEvents = <TapEvent>[];
      for (int i = 0; i < expectedBeats.length; i++) {
        // Alternating error to create variance
        final jitter = (i % 2 == 0) ? 0.010 : -0.010; 
        final actualTime = expectedBeats[i] + 0.045 + jitter;
        
        tapEvents.add(TapEvent(
          expectedTime: expectedBeats[i],
          actualTime: actualTime,
          error: (actualTime - expectedBeats[i]) * 1000,
        ));
      }

      final consistency = RhythmAnalyzer.calculateConsistency(tapEvents);
      print('Human Consistency: $consistency ms');

      // Standard deviation of [55, 35, 55, 35...]
      // Mean is 45.
      // Variance is ((10^2 + (-10^2))/2) = 100
      // StdDev is 10.
      expect(consistency, closeTo(10.0, 0.1));
    });
  });
}
