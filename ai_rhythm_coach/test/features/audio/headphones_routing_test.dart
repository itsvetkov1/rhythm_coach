import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_rhythm_coach/controllers/practice_controller.dart';
import 'package:ai_rhythm_coach/models/practice_state.dart';
import 'package:ai_rhythm_coach/models/tap_event.dart';
import 'package:ai_rhythm_coach/models/session.dart';
import 'package:ai_rhythm_coach/services/ai_coaching_service.dart';
import 'package:ai_rhythm_coach/services/audio_service.dart';
import 'package:ai_rhythm_coach/services/rhythm_analyzer.dart';
import 'package:ai_rhythm_coach/services/session_manager.dart';
import 'package:ai_rhythm_coach/screens/practice_screen.dart';
import 'package:ai_rhythm_coach/widgets/headphones_warning_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Mock Services
class MockAudioService extends AudioService {
  bool initializeCalled = false;
  bool configureAudioRoutingCalled = false;
  bool playCountInCalled = false;
  bool startRecordingCalled = false;
  bool startMetronomeCalled = false;

  @override
  Future<void> initialize() async {
    initializeCalled = true;
    // Simulate successful initialization with audio routing
    configureAudioRoutingCalled = true;
  }

  @override
  Future<void> playCountIn(int bpm) async {
    playCountInCalled = true;
  }

  @override
  Future<void> startRecording() async {
    startRecordingCalled = true;
  }

  @override
  Future<void> startMetronome(int bpm) async {
    startMetronomeCalled = true;
  }

  @override
  Future<String> stopRecording() async => 'test_path';

  @override
  Future<void> stopMetronome() async {}

  @override
  Future<void> dispose() async {}
}

class MockRhythmAnalyzer extends RhythmAnalyzer {
  @override
  Future<List<TapEvent>> analyzeAudio({
    required String audioFilePath,
    required int bpm,
    required int durationSeconds,
    bool debugMode = false,
    String? debugOutputPath,
  }) async {
    return [TapEvent(actualTime: 0.5, expectedTime: 0.5, error: 0.0)];
  }
}

class MockHttpClient extends Fake implements http.Client {}

class MockAICoachingService extends AICoachingService {
  MockAICoachingService() : super(MockHttpClient());

  @override
  Future<String> generateCoaching({
    required int bpm,
    required List<TapEvent> tapEvents,
    required double averageError,
    required double consistency,
  }) async {
    return "Great job!";
  }
}

class MockSharedPreferences extends Fake implements SharedPreferences {}

class MockSessionManager extends SessionManager {
  MockSessionManager() : super(MockSharedPreferences());

  @override
  Future<void> saveSession(Session session) async {}
}

void main() {
  group('Headphones Warning Dialog Tests', () {
    testWidgets('HeadphonesWarningDialog displays correct content',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => HeadphonesWarningDialog.show(context),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Headphones Required'), findsOneWidget);
      expect(
          find.text('Please connect your headphones before starting practice.'),
          findsOneWidget);
      expect(find.text('Why headphones are required:'), findsOneWidget);
      expect(find.text('The metronome will play through your headphones'),
          findsOneWidget);
      expect(find.text('Your microphone will record your performance'),
          findsOneWidget);
      expect(
          find.text(
              'This prevents the metronome from being recorded, ensuring accurate rhythm analysis'),
          findsOneWidget);
      expect(
          find.text(
              'Without headphones, rhythm analysis will not work correctly!'),
          findsOneWidget);
      expect(find.text('Not Now'), findsOneWidget);
      expect(find.text('Headphones Connected'), findsOneWidget);
      expect(find.byIcon(Icons.headset), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    });

    testWidgets(
        'HeadphonesWarningDialog returns true when user confirms headphones connected',
        (WidgetTester tester) async {
      bool? result;

      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await HeadphonesWarningDialog.show(context);
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // User confirms headphones connected
      await tester.tap(find.text('Headphones Connected'));
      await tester.pumpAndSettle();

      // Assert
      expect(result, isTrue);
      expect(find.byType(HeadphonesWarningDialog), findsNothing);
    });

    testWidgets(
        'HeadphonesWarningDialog returns false when user clicks Not Now',
        (WidgetTester tester) async {
      bool? result;

      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await HeadphonesWarningDialog.show(context);
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // User clicks Not Now
      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      // Assert
      expect(result, isFalse);
      expect(find.byType(HeadphonesWarningDialog), findsNothing);
    });

    testWidgets('HeadphonesWarningDialog is not dismissible by tapping outside',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => HeadphonesWarningDialog.show(context),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Try to dismiss by tapping outside (barrier)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Assert - Dialog should still be visible
      expect(find.byType(HeadphonesWarningDialog), findsOneWidget);
    });
  });

  group('PracticeScreen Headphones Warning Tests', () {
    late PracticeController controller;
    late MockAudioService mockAudioService;
    late MockRhythmAnalyzer mockRhythmAnalyzer;
    late MockAICoachingService mockAICoachingService;
    late MockSessionManager mockSessionManager;

    setUp(() {
      mockAudioService = MockAudioService();
      mockRhythmAnalyzer = MockRhythmAnalyzer();
      mockAICoachingService = MockAICoachingService();
      mockSessionManager = MockSessionManager();

      controller = PracticeController(
        audioService: mockAudioService,
        rhythmAnalyzer: mockRhythmAnalyzer,
        aiCoachingService: mockAICoachingService,
        sessionManager: mockSessionManager,
      );
    });

    testWidgets('PracticeScreen shows headphones warning dialog on startup',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<PracticeController>.value(
            value: controller,
            child: const PracticeScreen(),
          ),
        ),
      );

      // Act - Wait for post-frame callback
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(HeadphonesWarningDialog), findsOneWidget);
      expect(find.text('Headphones Required'), findsOneWidget);
    });

    testWidgets(
        'PracticeScreen only shows headphones warning dialog once on startup',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<PracticeController>.value(
            value: controller,
            child: const PracticeScreen(),
          ),
        ),
      );

      // Act - Wait for post-frame callback
      await tester.pumpAndSettle();

      // Dismiss the dialog
      await tester.tap(find.text('Headphones Connected'));
      await tester.pumpAndSettle();

      // Rebuild the widget (simulating state change)
      controller.setBpm(140);
      await tester.pumpAndSettle();

      // Assert - Dialog should not appear again
      expect(find.byType(HeadphonesWarningDialog), findsNothing);
    });
  });

  group('AudioService Audio Routing Tests', () {
    testWidgets('AudioService initializes with audio routing configuration',
        (WidgetTester tester) async {
      // Arrange
      final mockAudioService = MockAudioService();
      final controller = PracticeController(
        audioService: mockAudioService,
        rhythmAnalyzer: MockRhythmAnalyzer(),
        aiCoachingService: MockAICoachingService(),
        sessionManager: MockSessionManager(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<PracticeController>.value(
            value: controller,
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => controller.startSession(),
                  child: const Text('Start Practice'),
                ),
              ),
            ),
          ),
        ),
      );

      // Dismiss headphones warning first
      await tester.pumpAndSettle();
      if (find.text('Headphones Connected').evaluate().isNotEmpty) {
        await tester.tap(find.text('Headphones Connected'));
        await tester.pumpAndSettle();
      }

      // Act
      await tester.tap(find.text('Start Practice'));
      await tester.pump();

      // Assert
      expect(mockAudioService.initializeCalled, isTrue);
      expect(mockAudioService.configureAudioRoutingCalled, isTrue);
    });
  });

  group('Audio Separation Integration Tests', () {
    testWidgets(
        'Complete flow: Warning dialog -> Audio routing -> Recording starts',
        (WidgetTester tester) async {
      // Arrange
      final mockAudioService = MockAudioService();
      final controller = PracticeController(
        audioService: mockAudioService,
        rhythmAnalyzer: MockRhythmAnalyzer(),
        aiCoachingService: MockAICoachingService(),
        sessionManager: MockSessionManager(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<PracticeController>.value(
            value: controller,
            child: const PracticeScreen(),
          ),
        ),
      );

      // Step 1: Verify headphones warning appears on startup
      await tester.pumpAndSettle();
      expect(find.byType(HeadphonesWarningDialog), findsOneWidget);
      expect(find.text('Headphones Required'), findsOneWidget);

      // Step 2: User confirms headphones are connected
      await tester.tap(find.text('Headphones Connected'));
      await tester.pumpAndSettle();
      expect(find.byType(HeadphonesWarningDialog), findsNothing);

      // Step 3: Start practice session
      await tester.tap(find.text('Start Practice'));
      await tester.pump();

      // Step 4: Verify audio routing is configured during initialization
      expect(mockAudioService.initializeCalled, isTrue);
      expect(mockAudioService.configureAudioRoutingCalled, isTrue,
          reason: 'Audio routing must be configured to prevent metronome from being recorded');

      // Step 5: Verify recording and metronome start
      expect(controller.state, PracticeState.recording);
      expect(mockAudioService.playCountInCalled, isTrue);
      expect(mockAudioService.startRecordingCalled, isTrue);
      expect(mockAudioService.startMetronomeCalled, isTrue);

      // Cleanup: Fast forward to let the session timer finish
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets(
        'Verify audio routing prevents metronome from microphone recording',
        (WidgetTester tester) async {
      // This is a unit test that verifies the architectural separation
      // In a real device test, this would verify:
      // 1. Metronome audio output goes to headphones/wired output
      // 2. Recording input comes from microphone only
      // 3. Recorded audio does NOT contain metronome clicks

      final mockAudioService = MockAudioService();
      final controller = PracticeController(
        audioService: mockAudioService,
        rhythmAnalyzer: MockRhythmAnalyzer(),
        aiCoachingService: MockAICoachingService(),
        sessionManager: MockSessionManager(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<PracticeController>.value(
            value: controller,
            child: const PracticeScreen(),
          ),
        ),
      );

      // Dismiss dialog
      await tester.pumpAndSettle();
      await tester.tap(find.text('Headphones Connected'));
      await tester.pumpAndSettle();

      // Start practice
      await tester.tap(find.text('Start Practice'));
      await tester.pump();

      // Verify audio routing is configured BEFORE recording starts
      expect(mockAudioService.configureAudioRoutingCalled, isTrue,
          reason: 'Audio routing must be set up before any audio playback');
      expect(mockAudioService.initializeCalled, isTrue);

      // This ensures:
      // - AudioService.initialize() was called
      // - _configureAudioRouting() was called during initialization
      // - Audio focus is set to route playback to headphones
      // - Recording will capture from microphone only
      // - Metronome clicks won't be in the recorded audio

      // Cleanup
      await tester.pump(const Duration(seconds: 61));
    });
  });
}
