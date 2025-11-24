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
import 'package:ai_rhythm_coach/widgets/practice_action_button.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Mock Services
class MockAudioService extends AudioService {
  bool initializeCalled = false;
  bool playCountInCalled = false;
  bool startRecordingCalled = false;
  bool startMetronomeCalled = false;

  @override
  Future<void> initialize() async {
    initializeCalled = true;
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
  Future<List<TapEvent>> analyzeAudio({required String audioFilePath, required int bpm, required int durationSeconds}) async {
    return [TapEvent(actualTime: 0.5, expectedTime: 0.5, error: 0.0)];
  }
}

class MockHttpClient extends Fake implements http.Client {}

class MockAICoachingService extends AICoachingService {
  MockAICoachingService() : super(MockHttpClient()); 
  
  @override
  Future<String> generateCoaching({required int bpm, required List<TapEvent> tapEvents, required double averageError, required double consistency}) async {
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

  testWidgets('Start Practice button triggers session start and updates state', (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<PracticeController>.value(
          value: controller,
          child: const Scaffold(
            body: PracticeActionButton(),
          ),
        ),
      ),
    );

    // Verify initial state
    expect(find.text('Start Practice'), findsOneWidget);
    expect(controller.state, PracticeState.idle);

    // Act
    await tester.tap(find.text('Start Practice'));
    await tester.pump(); // Rebuild to reflect state change

    // Assert
    // The controller should transition to recording (since mock playCountIn is instant)
    expect(controller.state, PracticeState.recording);
    
    // Verify audio service calls
    expect(mockAudioService.initializeCalled, isTrue);
    expect(mockAudioService.playCountInCalled, isTrue);
    expect(mockAudioService.startRecordingCalled, isTrue);
    expect(mockAudioService.startMetronomeCalled, isTrue);

    // Fast forward to let the session timer finish to avoid pending timer error
    await tester.pump(const Duration(seconds: 61));
  });
}
