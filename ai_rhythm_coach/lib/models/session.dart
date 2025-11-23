import 'tap_event.dart';

class Session {
  final String id; // UUID
  final DateTime timestamp; // When session occurred
  final int bpm; // Metronome tempo
  final int durationSeconds; // Always 60 for MVP
  final String audioFilePath; // Path to recorded audio
  final List<TapEvent> tapEvents; // Detected tap timings
  final double averageError; // Average timing error (ms)
  final double consistency; // Standard deviation of errors
  final String coachingText; // AI-generated feedback

  Session({
    required this.id,
    required this.timestamp,
    required this.bpm,
    required this.durationSeconds,
    required this.audioFilePath,
    required this.tapEvents,
    required this.averageError,
    required this.consistency,
    required this.coachingText,
  });

  // JSON serialization for SharedPreferences
  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'bpm': bpm,
        'durationSeconds': durationSeconds,
        'audioFilePath': audioFilePath,
        'tapEvents': tapEvents.map((e) => e.toJson()).toList(),
        'averageError': averageError,
        'consistency': consistency,
        'coachingText': coachingText,
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        id: json['id'],
        timestamp: DateTime.parse(json['timestamp']),
        bpm: json['bpm'],
        durationSeconds: json['durationSeconds'],
        audioFilePath: json['audioFilePath'],
        tapEvents: (json['tapEvents'] as List)
            .map((e) => TapEvent.fromJson(e))
            .toList(),
        averageError: json['averageError'],
        consistency: json['consistency'],
        coachingText: json['coachingText'],
      );
}
