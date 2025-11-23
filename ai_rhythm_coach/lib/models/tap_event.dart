class TapEvent {
  final double actualTime; // Time of tap in seconds (from start)
  final double expectedTime; // Expected beat time in seconds
  final double error; // Difference in milliseconds (actual - expected)

  TapEvent({
    required this.actualTime,
    required this.expectedTime,
    required this.error,
  });

  bool get isEarly => error < 0;
  bool get isLate => error > 0;
  bool get isOnTime => error.abs() < 10.0; // Within 10ms tolerance

  Map<String, dynamic> toJson() => {
        'actualTime': actualTime,
        'expectedTime': expectedTime,
        'error': error,
      };

  factory TapEvent.fromJson(Map<String, dynamic> json) => TapEvent(
        actualTime: json['actualTime'],
        expectedTime: json['expectedTime'],
        error: json['error'],
      );
}
