# AI Rhythm Coach - Complete Technical Specification
**Version:** 1.0 MVP  
**Platform:** Android  
**Target:** Solo Developer Implementation via Claude Code  
**Last Updated:** November 22, 2025

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Architecture](#2-architecture)
3. [Data Models](#3-data-models)
4. [Component Specifications](#4-component-specifications)
5. [Screen Specifications](#5-screen-specifications)
6. [AI Integration Architecture](#6-ai-integration-architecture)
7. [Technology Stack](#7-technology-stack)
8. [Implementation Roadmap](#8-implementation-roadmap)
9. [Testing Strategy](#9-testing-strategy)
10. [Security & Configuration](#10-security--configuration)

---

## 1. System Overview

### 1.1 Product Purpose

AI Rhythm Coach is a mobile application that helps drummers and musicians improve rhythm accuracy through AI-powered coaching feedback. Users play against a metronome, and the app analyzes their performance to provide personalized coaching insights.

### 1.2 MVP Goals

- Validate core concept: AI-generated coaching feedback provides value
- Establish baseline rhythm analysis accuracy
- Gather real-world usage data for algorithm refinement
- Achieve functional MVP within 13-14 weeks part-time development

### 1.3 MVP Scope

**In Scope:**
- Android-only platform
- Single time signature: 4/4
- BPM range: 40-200
- Practice session: 60 seconds with 4-beat count-in
- Configurable AI services (Anthropic Claude or OpenAI GPT)
- Local storage (10 recent sessions)
- Rhythm accuracy analysis via onset detection
- AI-generated coaching text

**Out of Scope (Post-MVP):**
- iOS platform
- Multiple time signatures (3/4, 6/8, etc.)
- Tap tempo functionality
- Preset management (saved configurations)
- Cloud sync / user accounts
- Visual waveform display
- Advanced audio processing (spectral analysis)

### 1.4 Key Constraints

- Solo developer with Flutter beginner experience
- Simplicity-first architecture (avoid over-engineering)
- No ongoing infrastructure costs (local-only storage)
- AI API costs only (pay-per-use model)

---

## 2. Architecture

### 2.1 High-Level System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      AI Rhythm Coach App                     │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐         ┌──────────────┐                  │
│  │   Practice   │────────▶│   Results    │                  │
│  │    Screen    │         │    Screen    │                  │
│  └──────┬───────┘         └──────┬───────┘                  │
│         │                        │                           │
│         │                        │                           │
│  ┌──────▼────────────────────────▼───────┐                  │
│  │                                        │                  │
│  │         State Management Layer         │                  │
│  │            (Provider)                  │                  │
│  │                                        │                  │
│  │  ┌─────────────────┐  ┌─────────────┐ │                  │
│  │  │ Practice        │  │  Session    │ │                  │
│  │  │ Controller      │  │  Manager    │ │                  │
│  │  └────────┬────────┘  └──────┬──────┘ │                  │
│  └───────────┼──────────────────┼────────┘                  │
│              │                  │                            │
│  ┌───────────▼──────────────────▼────────┐                  │
│  │                                        │                  │
│  │          Service Layer                 │                  │
│  │                                        │                  │
│  │  ┌────────────┐  ┌──────────────┐     │                  │
│  │  │  Audio     │  │   Rhythm     │     │                  │
│  │  │  Service   │  │   Analyzer   │     │                  │
│  │  └──────┬─────┘  └──────┬───────┘     │                  │
│  │         │                │             │                  │
│  │  ┌──────▼────────────────▼───────┐    │                  │
│  │  │     AI Coaching Service       │    │                  │
│  │  └──────────────┬────────────────┘    │                  │
│  └─────────────────┼─────────────────────┘                  │
│                    │                                         │
│  ┌─────────────────▼─────────────────────┐                  │
│  │                                        │                  │
│  │        Persistence Layer               │                  │
│  │                                        │                  │
│  │  ┌──────────────┐  ┌───────────────┐  │                  │
│  │  │ Shared       │  │  File System  │  │                  │
│  │  │ Preferences  │  │  (Audio)      │  │                  │
│  │  └──────────────┘  └───────────────┘  │                  │
│  └────────────────────────────────────────┘                  │
│                                                               │
└─────────────────────────────────────────────────────────────┘

External Dependencies:
┌────────────────────┐         ┌────────────────────┐
│  Anthropic Claude  │   OR    │   OpenAI GPT       │
│  API               │         │   API              │
└────────────────────┘         └────────────────────┘
```

### 2.2 Architectural Principles

**Layered Architecture:**
1. **Presentation Layer:** Screens and widgets (UI)
2. **State Management Layer:** Controllers managing business logic
3. **Service Layer:** Reusable services (audio, rhythm analysis, AI)
4. **Persistence Layer:** Local storage (SharedPreferences + file system)

**Key Patterns:**
- **Provider Pattern:** State management and dependency injection
- **Service Pattern:** Encapsulated business logic in reusable services
- **Repository Pattern (lightweight):** SessionManager abstracts persistence

**Data Flow Summary:**

**Practice Session Flow:**
```
User Input (Start) → PracticeController
  ↓
Audio Service (Record + Metronome)
  ↓
Raw Audio File
  ↓
Rhythm Analyzer (FFT + Onset Detection)
  ↓
Tap Events List + Timing Errors
  ↓
AI Coaching Service (API call)
  ↓
Coaching Text
  ↓
Session Model (Complete)
  ↓
Session Manager (Save)
  ↓
Results Screen (Display)
```

### 2.3 Component Relationships

**PracticeController:**
- Orchestrates entire practice session
- Depends on: AudioService, RhythmAnalyzer, AICoachingService, SessionManager
- Manages: Session lifecycle, state transitions, error handling

**SessionManager:**
- Handles persistence of session history
- Depends on: SharedPreferences, File System
- Provides: CRUD operations for sessions

**AudioService:**
- Records user input
- Plays metronome clicks
- Depends on: flutter_sound
- Returns: Audio file path

**RhythmAnalyzer:**
- Analyzes audio for onset detection
- Depends on: fftea
- Returns: List of TapEvent with timing errors

**AICoachingService:**
- Sends data to AI API
- Depends on: http, AIConfig
- Returns: Coaching text string

---

## 3. Data Models

### 3.1 Session Model

```dart
class Session {
  final String id;                    // UUID
  final DateTime timestamp;           // When session occurred
  final int bpm;                      // Metronome tempo
  final int durationSeconds;          // Always 60 for MVP
  final String audioFilePath;         // Path to recorded audio
  final List<TapEvent> tapEvents;     // Detected tap timings
  final double averageError;          // Average timing error (ms)
  final double consistency;           // Standard deviation of errors
  final String coachingText;          // AI-generated feedback
  
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
```

### 3.2 TapEvent Model

```dart
class TapEvent {
  final double actualTime;       // Time of tap in seconds (from start)
  final double expectedTime;     // Expected beat time in seconds
  final double error;            // Difference in milliseconds (actual - expected)
  
  TapEvent({
    required this.actualTime,
    required this.expectedTime,
    required this.error,
  });
  
  bool get isEarly => error < 0;
  bool get isLate => error > 0;
  bool get isOnTime => error.abs() < 10.0;  // Within 10ms tolerance
  
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
```

### 3.3 PracticeState Enum

```dart
enum PracticeState {
  idle,           // Initial state, ready to start
  countIn,        // 4-beat count-in playing
  recording,      // Active recording (60s)
  processing,     // Analyzing audio + generating coaching
  completed,      // Session finished, ready to view results
  error,          // Error occurred during session
}
```

---

## 4. Component Specifications

### 4.1 PracticeController

**Purpose:** Orchestrates the complete practice session lifecycle from start to AI coaching generation.

**Responsibilities:**
- Manage practice session state machine
- Coordinate AudioService, RhythmAnalyzer, AICoachingService
- Handle error scenarios gracefully
- Notify UI of state changes via Provider

**State:**
```dart
class PracticeController extends ChangeNotifier {
  PracticeState _state = PracticeState.idle;
  int _bpm = 120;  // Default tempo
  Session? _currentSession;
  String? _errorMessage;
  
  // Getters
  PracticeState get state => _state;
  int get bpm => _bpm;
  Session? get currentSession => _currentSession;
  String? get errorMessage => _errorMessage;
  
  // Services (injected)
  final AudioService _audioService;
  final RhythmAnalyzer _rhythmAnalyzer;
  final AICoachingService _aiCoachingService;
  final SessionManager _sessionManager;
}
```

**Key Methods:**

```dart
// Start practice session with 4-beat count-in
Future<void> startSession() async {
  try {
    _setState(PracticeState.countIn);
    
    // Play 4-beat count-in
    await _audioService.playCountIn(_bpm);
    
    // Start recording + metronome simultaneously
    _setState(PracticeState.recording);
    await _audioService.startRecording();
    await _audioService.startMetronome(_bpm);
    
    // Wait for 60 seconds
    await Future.delayed(Duration(seconds: 60));
    
    // Stop recording + metronome
    final audioFilePath = await _audioService.stopRecording();
    await _audioService.stopMetronome();
    
    // Process results
    await _processSession(audioFilePath);
    
  } catch (e) {
    _handleError(e);
  }
}

// Process recorded audio to generate coaching
Future<void> _processSession(String audioFilePath) async {
  _setState(PracticeState.processing);
  
  // Analyze rhythm
  final tapEvents = await _rhythmAnalyzer.analyzeAudio(
    audioFilePath: audioFilePath,
    bpm: _bpm,
    durationSeconds: 60,
  );
  
  // Calculate metrics
  final averageError = _calculateAverageError(tapEvents);
  final consistency = _calculateConsistency(tapEvents);
  
  // Generate AI coaching
  final coachingText = await _aiCoachingService.generateCoaching(
    bpm: _bpm,
    tapEvents: tapEvents,
    averageError: averageError,
    consistency: consistency,
  );
  
  // Create session object
  _currentSession = Session(
    id: Uuid().v4(),
    timestamp: DateTime.now(),
    bpm: _bpm,
    durationSeconds: 60,
    audioFilePath: audioFilePath,
    tapEvents: tapEvents,
    averageError: averageError,
    consistency: consistency,
    coachingText: coachingText,
  );
  
  // Save session
  await _sessionManager.saveSession(_currentSession!);
  
  _setState(PracticeState.completed);
}

// Update BPM setting
void setBpm(int newBpm) {
  if (newBpm >= 40 && newBpm <= 200) {
    _bpm = newBpm;
    notifyListeners();
  }
}

// Reset to idle state
void reset() {
  _state = PracticeState.idle;
  _currentSession = null;
  _errorMessage = null;
  notifyListeners();
}
```

**Error Handling:**
```dart
void _handleError(dynamic error) {
  _state = PracticeState.error;
  
  if (error is AudioRecordingException) {
    _errorMessage = 'Recording failed. Check microphone permissions.';
  } else if (error is AIServiceException) {
    _errorMessage = 'Coaching generation failed. Check internet connection.';
  } else {
    _errorMessage = 'An unexpected error occurred. Please try again.';
  }
  
  notifyListeners();
}
```

### 4.2 SessionManager

**Purpose:** Manage persistence and retrieval of session history.

**Responsibilities:**
- Save new sessions (metadata to SharedPreferences, audio to file system)
- Retrieve session list (most recent 10)
- Delete old sessions when limit exceeded
- Provide session by ID

**Implementation:**

```dart
class SessionManager {
  static const String _sessionsKey = 'sessions';
  static const int _maxSessions = 10;
  
  final SharedPreferences _prefs;
  
  SessionManager(this._prefs);
  
  // Save new session
  Future<void> saveSession(Session session) async {
    // Load existing sessions
    final sessions = await getSessions();
    
    // Add new session at front
    sessions.insert(0, session);
    
    // Trim to max sessions
    if (sessions.length > _maxSessions) {
      final removed = sessions.removeLast();
      await _deleteAudioFile(removed.audioFilePath);
    }
    
    // Save to SharedPreferences
    final jsonList = sessions.map((s) => s.toJson()).toList();
    await _prefs.setString(_sessionsKey, jsonEncode(jsonList));
  }
  
  // Get all sessions (most recent first)
  Future<List<Session>> getSessions() async {
    final jsonString = _prefs.getString(_sessionsKey);
    if (jsonString == null) return [];
    
    final jsonList = jsonDecode(jsonString) as List;
    return jsonList.map((json) => Session.fromJson(json)).toList();
  }
  
  // Get session by ID
  Future<Session?> getSession(String id) async {
    final sessions = await getSessions();
    return sessions.firstWhere((s) => s.id == id, orElse: () => null);
  }
  
  // Delete audio file
  Future<void> _deleteAudioFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
```

### 4.3 AudioService

**Purpose:** Handle all audio operations (recording, playback, metronome).

**Responsibilities:**
- Record user input to audio file
- Play metronome clicks (high/low for downbeat)
- Play count-in (4 beats before recording)
- Manage flutter_sound recorder and player instances

**Implementation:**

```dart
class AudioService {
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  Timer? _metronomeTimer;
  int _beatCount = 0;
  
  // Initialize audio session
  Future<void> initialize() async {
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    
    await _recorder!.openRecorder();
    await _player!.openPlayer();
  }
  
  // Cleanup resources
  Future<void> dispose() async {
    await _recorder?.closeRecorder();
    await _player?.closePlayer();
    _metronomeTimer?.cancel();
  }
  
  // Play 4-beat count-in
  Future<void> playCountIn(int bpm) async {
    final interval = Duration(milliseconds: (60000 / bpm).round());
    
    for (int i = 0; i < 4; i++) {
      await _player!.startPlayer(
        fromURI: 'assets/audio/click_high.wav',
      );
      await Future.delayed(interval);
    }
  }
  
  // Start recording to file
  Future<void> startRecording() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${directory.path}/recording_$timestamp.aac';
    
    await _recorder!.startRecorder(
      toFile: path,
      codec: Codec.aacADTS,
    );
  }
  
  // Stop recording and return file path
  Future<String> stopRecording() async {
    final path = await _recorder!.stopRecorder();
    return path!;
  }
  
  // Start metronome click track
  Future<void> startMetronome(int bpm) async {
    final interval = Duration(milliseconds: (60000 / bpm).round());
    _beatCount = 0;
    
    _metronomeTimer = Timer.periodic(interval, (timer) async {
      _beatCount++;
      
      // Play high click on beat 1, low click on others
      final clickFile = (_beatCount % 4 == 1)
          ? 'assets/audio/click_high.wav'
          : 'assets/audio/click_low.wav';
      
      await _player!.startPlayer(fromURI: clickFile);
    });
  }
  
  // Stop metronome
  Future<void> stopMetronome() async {
    _metronomeTimer?.cancel();
    _metronomeTimer = null;
  }
  
  // Play recorded audio file
  Future<void> playRecording(String filePath) async {
    await _player!.startPlayer(fromURI: filePath);
  }
}
```

### 4.4 RhythmAnalyzer

**Purpose:** Analyze recorded audio to detect tap onsets and calculate timing errors.

**Responsibilities:**
- Load audio file and extract samples
- Apply FFT to detect onset events
- Match onsets to expected beat times
- Calculate timing errors for each tap

**Implementation:**

```dart
class RhythmAnalyzer {
  // Analyze audio file for rhythm accuracy
  Future<List<TapEvent>> analyzeAudio({
    required String audioFilePath,
    required int bpm,
    required int durationSeconds,
  }) async {
    // Load audio samples
    final samples = await _loadAudioSamples(audioFilePath);
    
    // Detect onset times (in seconds)
    final onsetTimes = _detectOnsets(samples);
    
    // Generate expected beat times
    final expectedBeats = _generateExpectedBeats(bpm, durationSeconds);
    
    // Match onsets to nearest expected beats
    final tapEvents = _matchOnsetsToBeats(onsetTimes, expectedBeats);
    
    return tapEvents;
  }
  
  // Load audio file and convert to samples
  Future<List<double>> _loadAudioSamples(String filePath) async {
    // Use flutter_sound to decode audio file
    // Return normalized sample values (-1.0 to 1.0)
    // Implementation will use flutter_sound's PCM extraction
  }
  
  // Detect onset times using FFT spectral flux
  List<double> _detectOnsets(List<double> samples) {
    final onsets = <double>[];
    const int fftSize = 2048;
    const int hopSize = 512;
    const double sampleRate = 44100;
    
    // Sliding window FFT
    for (int i = 0; i < samples.length - fftSize; i += hopSize) {
      final window = samples.sublist(i, i + fftSize);
      
      // Apply FFT using fftea
      final fft = FFT(fftSize);
      final spectrum = fft.realFft(window);
      
      // Calculate spectral flux (difference from previous frame)
      // If flux exceeds threshold, mark as onset
      // Record time as: (i / sampleRate)
    }
    
    return onsets;
  }
  
  // Generate expected beat times for given BPM
  List<double> _generateExpectedBeats(int bpm, int durationSeconds) {
    final beats = <double>[];
    final beatInterval = 60.0 / bpm;  // Seconds per beat
    
    for (double time = 0; time < durationSeconds; time += beatInterval) {
      beats.add(time);
    }
    
    return beats;
  }
  
  // Match detected onsets to expected beats
  List<TapEvent> _matchOnsetsToBeats(
    List<double> onsetTimes,
    List<double> expectedBeats,
  ) {
    final tapEvents = <TapEvent>[];
    
    for (final expectedTime in expectedBeats) {
      // Find nearest onset within ±300ms window
      final nearestOnset = _findNearestOnset(
        onsetTimes,
        expectedTime,
        maxDistance: 0.3,  // 300ms tolerance
      );
      
      if (nearestOnset != null) {
        final error = (nearestOnset - expectedTime) * 1000;  // Convert to ms
        
        tapEvents.add(TapEvent(
          actualTime: nearestOnset,
          expectedTime: expectedTime,
          error: error,
        ));
      }
    }
    
    return tapEvents;
  }
  
  // Find nearest onset to target time
  double? _findNearestOnset(
    List<double> onsets,
    double targetTime,
    {required double maxDistance}
  ) {
    double? nearest;
    double minDistance = double.infinity;
    
    for (final onset in onsets) {
      final distance = (onset - targetTime).abs();
      if (distance < minDistance && distance <= maxDistance) {
        minDistance = distance;
        nearest = onset;
      }
    }
    
    return nearest;
  }
}
```

### 4.5 AICoachingService

**Purpose:** Generate personalized coaching feedback using AI API.

**Responsibilities:**
- Format rhythm analysis data for AI prompt
- Send API request to configured AI service (Claude or GPT)
- Parse and return coaching text
- Handle API errors gracefully

**Implementation:**

```dart
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
    
    return '''
You are a professional rhythm coach analyzing a drummer's practice session.

Session Details:
- Tempo: $bpm BPM
- Total beats detected: ${tapEvents.length}
- Average timing error: ${averageError.toStringAsFixed(2)}ms
- Consistency (std dev): ${consistency.toStringAsFixed(2)}ms
- Early hits: $earlyCount
- Late hits: $lateCount
- On-time hits (±10ms): $onTimeCount

Timing Errors (first 10 beats):
${tapEvents.take(10).map((e) => '${e.error.toStringAsFixed(1)}ms').join(', ')}

Provide encouraging, actionable coaching feedback (2-3 sentences) focusing on:
1. What they did well
2. Primary area for improvement
3. Specific practice suggestion

Keep tone supportive and motivating. Avoid overly technical language.
''';
  }
  
  // Call Anthropic Claude API
  Future<String> _callClaudeAPI(String prompt) async {
    final response = await _client.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': AIConfig.anthropicApiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': 'claude-sonnet-4-20250514',
        'max_tokens': 300,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    );
    
    if (response.statusCode != 200) {
      throw AIServiceException('Claude API error: ${response.statusCode}');
    }
    
    final data = jsonDecode(response.body);
    return data['content'][0]['text'];
  }
  
  // Call OpenAI GPT API
  Future<String> _callOpenAIAPI(String prompt) async {
    final response = await _client.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AIConfig.openaiApiKey}',
      },
      body: jsonEncode({
        'model': 'gpt-4',
        'max_tokens': 300,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    );
    
    if (response.statusCode != 200) {
      throw AIServiceException('OpenAI API error: ${response.statusCode}');
    }
    
    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'];
  }
}

// Custom exception for AI service errors
class AIServiceException implements Exception {
  final String message;
  AIServiceException(this.message);
  
  @override
  String toString() => message;
}
```

---

## 5. Screen Specifications

### 5.1 Practice Screen

**Purpose:** Main interface for conducting practice sessions.

**Layout:**

```
┌─────────────────────────────────┐
│       AI Rhythm Coach           │  ← App Bar
├─────────────────────────────────┤
│                                 │
│         [ICON]                  │  ← Status icon (mic/processing)
│                                 │
│     Practice Session            │  ← Title
│                                 │
│   ┌─────────────────────────┐   │
│   │     BPM: 120            │   │  ← BPM display + slider
│   │   ◄────────●────────►   │   │     (40-200 range)
│   └─────────────────────────┘   │
│                                 │
│   ┌─────────────────────────┐   │
│   │                         │   │
│   │    [START SESSION]      │   │  ← Primary action button
│   │                         │   │     (changes based on state)
│   └─────────────────────────┘   │
│                                 │
│   Status: Ready                 │  ← State message
│                                 │
│   Recent Sessions ▼             │  ← Expandable list
│                                 │
└─────────────────────────────────┘
```

**State-Based UI Changes:**

| State | Button Text | Status Message | Icon |
|-------|------------|----------------|------|
| idle | "Start Session" | "Ready to practice" | Microphone |
| countIn | "Count-in..." | "Get ready! (3...2...1...)" | Metronome |
| recording | "Recording..." | "Keep playing! (45s remaining)" | Recording |
| processing | "Analyzing..." | "Generating coaching feedback..." | Spinner |
| completed | "View Results" | "Session complete!" | Checkmark |
| error | "Try Again" | Error message | Warning |

**Widgets:**

```dart
class PracticeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<PracticeController>(
      builder: (context, controller, child) {
        return Scaffold(
          appBar: AppBar(title: Text('AI Rhythm Coach')),
          body: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status icon
                _buildStatusIcon(controller.state),
                
                SizedBox(height: 32),
                
                // Title
                Text(
                  'Practice Session',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                
                SizedBox(height: 48),
                
                // BPM Selector
                _buildBpmSelector(controller),
                
                SizedBox(height: 48),
                
                // Action Button
                _buildActionButton(context, controller),
                
                SizedBox(height: 24),
                
                // Status Message
                Text(
                  _getStatusMessage(controller),
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: 48),
                
                // Recent Sessions
                _buildRecentSessions(context),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildBpmSelector(PracticeController controller) {
    return Column(
      children: [
        Text('BPM: ${controller.bpm}', style: TextStyle(fontSize: 24)),
        Slider(
          value: controller.bpm.toDouble(),
          min: 40,
          max: 200,
          divisions: 160,
          onChanged: (value) => controller.setBpm(value.toInt()),
        ),
      ],
    );
  }
  
  Widget _buildActionButton(
    BuildContext context,
    PracticeController controller,
  ) {
    final isDisabled = controller.state == PracticeState.countIn ||
                      controller.state == PracticeState.recording ||
                      controller.state == PracticeState.processing;
    
    return ElevatedButton(
      onPressed: isDisabled ? null : () => _handleButtonPress(context, controller),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        child: Text(
          _getButtonText(controller.state),
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
  
  String _getButtonText(PracticeState state) {
    switch (state) {
      case PracticeState.idle:
        return 'Start Session';
      case PracticeState.countIn:
        return 'Count-in...';
      case PracticeState.recording:
        return 'Recording...';
      case PracticeState.processing:
        return 'Analyzing...';
      case PracticeState.completed:
        return 'View Results';
      case PracticeState.error:
        return 'Try Again';
    }
  }
  
  void _handleButtonPress(
    BuildContext context,
    PracticeController controller,
  ) {
    if (controller.state == PracticeState.completed) {
      // Navigate to results
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(
            session: controller.currentSession!,
          ),
        ),
      );
    } else {
      // Start new session
      controller.startSession();
    }
  }
}
```

### 5.2 Results Screen

**Purpose:** Display session results and AI coaching feedback.

**Layout:**

```
┌─────────────────────────────────┐
│    ← Session Results            │  ← App Bar with back button
├─────────────────────────────────┤
│                                 │
│   Session: Nov 22, 2025 14:30   │  ← Timestamp
│   Tempo: 120 BPM                │
│                                 │
│   ┌─────────────────────────┐   │
│   │  Performance Metrics    │   │  ← Card
│   │                         │   │
│   │  Average Error: 12ms    │   │
│   │  Consistency: 8ms       │   │
│   │  Beats Detected: 118    │   │
│   │                         │   │
│   │  ● Early: 23            │   │
│   │  ● On Time: 72          │   │
│   │  ● Late: 23             │   │
│   └─────────────────────────┘   │
│                                 │
│   ┌─────────────────────────┐   │
│   │  AI Coaching            │   │  ← Card
│   │                         │   │
│   │  [Coaching text here    │   │
│   │   spanning 2-3          │   │
│   │   sentences...]          │   │
│   │                         │   │
│   └─────────────────────────┘   │
│                                 │
│   ┌─────────────────────────┐   │
│   │  [Play Recording]       │   │  ← Button
│   └─────────────────────────┘   │
│                                 │
│   [Practice Again]              │  ← Button (returns to Practice)
│                                 │
└─────────────────────────────────┘
```

**Widgets:**

```dart
class ResultsScreen extends StatelessWidget {
  final Session session;
  
  ResultsScreen({required this.session});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Session Results'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session info
            Text(
              _formatTimestamp(session.timestamp),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Tempo: ${session.bpm} BPM',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            
            SizedBox(height: 24),
            
            // Performance Metrics Card
            _buildMetricsCard(context),
            
            SizedBox(height: 24),
            
            // AI Coaching Card
            _buildCoachingCard(context),
            
            SizedBox(height: 24),
            
            // Action Buttons
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetricsCard(BuildContext context) {
    final early = session.tapEvents.where((t) => t.isEarly).length;
    final onTime = session.tapEvents.where((t) => t.isOnTime).length;
    final late = session.tapEvents.where((t) => t.isLate).length;
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Metrics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            Text('Average Error: ${session.averageError.toStringAsFixed(1)}ms'),
            Text('Consistency: ${session.consistency.toStringAsFixed(1)}ms'),
            Text('Beats Detected: ${session.tapEvents.length}'),
            SizedBox(height: 12),
            Text('● Early: $early'),
            Text('● On Time: $onTime'),
            Text('● Late: $late'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCoachingCard(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'AI Coaching',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              session.coachingText,
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => _playRecording(context),
          icon: Icon(Icons.play_arrow),
          label: Text('Play Recording'),
        ),
        SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Practice Again'),
        ),
      ],
    );
  }
  
  void _playRecording(BuildContext context) async {
    final audioService = Provider.of<AudioService>(context, listen: false);
    await audioService.playRecording(session.audioFilePath);
  }
}
```

---

## 6. AI Integration Architecture

### 6.1 Data Flow: Practice Session → AI Coaching

```
┌──────────────────────────────────────────────────────────────┐
│                      Practice Session                        │
│                                                               │
│  User plays against metronome (60s)                          │
│         ↓                                                     │
│  AudioService records to AAC file                            │
│         ↓                                                     │
│  RhythmAnalyzer:                                             │
│    - Loads audio samples                                     │
│    - Applies FFT sliding window (2048 samples, 512 hop)     │
│    - Detects spectral flux onsets                           │
│    - Matches onsets to expected beat times (±300ms window)  │
│    - Calculates timing errors (ms)                          │
│         ↓                                                     │
│  Results: List<TapEvent>                                     │
│    - actualTime, expectedTime, error for each detected beat │
│         ↓                                                     │
│  Calculate Metrics:                                          │
│    - Average error (mean of all timing errors)              │
│    - Consistency (standard deviation of errors)             │
│    - Early/late/on-time counts                              │
│         ↓                                                     │
│  AICoachingService.generateCoaching():                       │
│    - Format metrics into structured prompt                   │
│    - Send HTTP POST to AI API (Claude or GPT)               │
│    - Parse response text                                     │
│         ↓                                                     │
│  Coaching Text (String)                                      │
│         ↓                                                     │
│  Create Session object (complete)                            │
│         ↓                                                     │
│  SessionManager.saveSession():                               │
│    - Serialize Session to JSON                               │
│    - Save to SharedPreferences                               │
│    - Audio file already on disk                              │
│         ↓                                                     │
│  Navigate to ResultsScreen                                   │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### 6.2 AI Prompt Structure

**Goals:**
- Provide context: tempo, session duration
- Present quantitative metrics: average error, consistency
- Show error distribution: early/late/on-time breakdown
- Request: encouraging, actionable coaching (2-3 sentences)

**Example Prompt:**

```
You are a professional rhythm coach analyzing a drummer's practice session.

Session Details:
- Tempo: 120 BPM
- Total beats detected: 118
- Average timing error: 12.3ms
- Consistency (std dev): 8.7ms
- Early hits: 23
- Late hits: 23
- On-time hits (±10ms): 72

Timing Errors (first 10 beats):
-5.2ms, 8.1ms, -2.3ms, 15.6ms, 3.4ms, -7.8ms, 1.2ms, -11.4ms, 6.9ms, -3.1ms

Provide encouraging, actionable coaching feedback (2-3 sentences) focusing on:
1. What they did well
2. Primary area for improvement
3. Specific practice suggestion

Keep tone supportive and motivating. Avoid overly technical language.
```

**Example AI Response:**

```
Great consistency overall! You're staying within 12ms of the beat on average, 
which shows solid internal timing. Focus on those early hits—try feeling the 
beat land just a hair later. Practice at this tempo with exaggerated "heavy" 
downbeats to anchor your timing.
```

### 6.3 API Configuration

**Config File Structure (gitignored):**

```dart
// lib/config.dart
enum AIProvider { anthropic, openai }

class AIConfig {
  static const AIProvider provider = AIProvider.anthropic;
  static const String anthropicApiKey = 'sk-ant-...';
  static const String openaiApiKey = 'sk-...';
}
```

**API Endpoints:**

| Provider | Endpoint | Model | Max Tokens |
|----------|----------|-------|------------|
| Anthropic | `https://api.anthropic.com/v1/messages` | `claude-sonnet-4-20250514` | 300 |
| OpenAI | `https://api.openai.com/v1/chat/completions` | `gpt-4` | 300 |

### 6.4 Error Handling Strategy

**AI Service Failure Scenarios:**

1. **No Internet Connection**
   - Detect: HTTP request timeout or network error
   - Fallback: "Coaching unavailable. Please check your internet connection and try again."
   - Action: Session still saved with empty coaching text

2. **API Key Invalid/Expired**
   - Detect: 401/403 HTTP status
   - Fallback: "API authentication failed. Please check your configuration."
   - Action: Session saved, prompt user to verify API key

3. **Rate Limit Exceeded**
   - Detect: 429 HTTP status
   - Fallback: "Service temporarily unavailable. Please try again in a moment."
   - Action: Session saved, suggest retry

4. **API Server Error**
   - Detect: 500/502/503 HTTP status
   - Fallback: "Coaching service unavailable. Your session data has been saved."
   - Action: Session saved, offer to retry later

**Graceful Degradation:**
- Always save session data (audio + metrics)
- Display metrics even without coaching text
- Provide option to "Regenerate Coaching" from Results screen (future enhancement)

---

## 7. Technology Stack

### 7.1 Core Framework

#### **Recommended: Flutter**
**Score: 95/100**

**Rationale:**
- Cross-platform foundation (iOS expansion ready)
- Hot reload enables rapid development
- Rich package ecosystem (audio, FFT, state management)
- Single codebase for Android MVP + future iOS
- Strong community, excellent documentation

**Trade-offs:**
- **Advantages:**
  - Write once, deploy to Android + iOS (future)
  - Mature audio packages (flutter_sound)
  - Native performance for audio processing
  - Built-in Material Design widgets
  
- **Disadvantages:**
  - Larger APK size than native Android (~20MB vs ~5MB)
  - Dart language learning curve (minimal for someone with programming background)
  - Platform-specific features require plugins

- **Best for:** Cross-platform mobile apps, especially audio/multimedia apps

**Alternatives Considered:**

**Native Android (Kotlin)**
**Score: 85/100**
- Optimal performance, smallest APK
- No cross-platform advantage
- Requires complete rewrite for iOS
- Not aligned with user's Flutter experimentation goal

**React Native**
**Score: 80/100**
- Cross-platform, JavaScript ecosystem
- Audio support less mature than Flutter
- Bridge overhead for audio processing
- Less performant for real-time audio tasks

---

### 7.2 Programming Language

#### **Recommended: Dart**
**Score: 95/100**

**Rationale:**
- Required by Flutter (no alternative)
- Modern, strongly-typed language
- Excellent async/await support (critical for audio)
- Null-safety built-in (reduces runtime errors)
- Fast compilation, hot reload

**Trade-offs:**
- **Advantages:**
  - Clean syntax, easy to learn from Java/C#/JavaScript background
  - Strong type system catches errors at compile time
  - Excellent async handling for audio/network operations
  - Fast execution (compiled to native code)
  
- **Disadvantages:**
  - Smaller ecosystem than JavaScript/Python
  - Primarily used for Flutter (less transferable skill)

- **Best for:** Flutter development

---

### 7.3 State Management

#### **Recommended: Provider**
**Score: 92/100**

**Rationale:**
- Official Flutter recommendation
- Simple API, minimal boilerplate
- Perfect for MVP complexity (2 screens, 3-4 controllers)
- Built-in dependency injection
- Excellent documentation and examples

**Trade-offs:**
- **Advantages:**
  - Easy to learn (ChangeNotifier + Consumer pattern)
  - Sufficient for all MVP state management needs
  - No code generation required
  - Minimal performance overhead
  
- **Disadvantages:**
  - May need refactoring if app grows significantly (not a concern for MVP)
  - No built-in immutability (manual best practices)

- **Best for:** Small to medium apps, MVPs, Flutter beginners

**Alternatives Considered:**

**Riverpod**
**Score: 88/100**
- More modern than Provider, better testing
- Steeper learning curve
- Overkill for MVP scope
- Good post-MVP migration path

**Bloc**
**Score: 75/100**
- Popular, excellent for complex state
- Heavy boilerplate for simple MVP
- Over-engineered for this use case

---

### 7.4 Audio Recording

#### **Recommended: flutter_sound**
**Score: 90/100**

**Rationale:**
- Unified package for recording AND playback
- Format conversion support (AAC to WAV for FFT)
- Active maintenance, Flutter team endorsed
- Works on Android + iOS (future-proof)
- Handles audio session management

**Trade-offs:**
- **Advantages:**
  - Single package for all audio needs (recording, playback, metronome)
  - Built-in codec support (AAC, WAV, PCM)
  - Audio session management (important for Android)
  - Simultaneous recording + playback (metronome during recording)
  
- **Disadvantages:**
  - Slightly heavier than specialized packages
  - Some features unused in MVP (streaming, advanced codecs)

- **Best for:** Apps requiring both recording and playback

**Alternatives Considered:**

**audio_recorder (separate package)**
**Score: 75/100**
- Lightweight, simple recording only
- Requires separate playback package
- Less unified API
- No format conversion support

---

### 7.5 Audio Playback

#### **Recommended: flutter_sound (same package)**
**Score: 90/100**

**Rationale:**
- Already using for recording (unified solution)
- Playback capabilities meet all needs:
  - Metronome click playback (high/low clicks)
  - Recorded session playback (Results screen)
- No additional dependencies

---

### 7.6 FFT / Signal Processing

#### **Recommended: fftea**
**Score: 88/100**

**Rationale:**
- Pure Dart implementation (no native dependencies)
- Simple API (`FFT(size).realFft(samples)`)
- Sufficient performance for 60s audio analysis (non-real-time)
- Works on all platforms (Android, iOS, web)
- Actively maintained

**Trade-offs:**
- **Advantages:**
  - Zero platform-specific setup
  - Easy to use and understand
  - Adequate performance for offline analysis
  - No compilation/build complexity
  
- **Disadvantages:**
  - Slower than native FFT libraries (FFTW, KissFFT)
  - Not suitable for real-time analysis (MVP doesn't need this)

- **Best for:** Offline audio analysis in Flutter apps

**Alternatives Considered:**

**fftw_ffi (FFI binding to FFTW)**
**Score: 80/100**
- Faster performance
- Native library dependencies (complex setup)
- Overkill for 60s offline analysis
- Platform-specific compilation

**Custom FFT Implementation**
**Score: 40/100**
- Educational value
- Slow, error-prone
- Not recommended for production

---

### 7.7 AI Service Integration

#### **Recommended: Anthropic Claude + OpenAI GPT (Configurable)**
**Score: 93/100**

**Rationale:**
- **Flexibility:** User can choose provider via config
- **Quality:** Both produce excellent coaching text
- **Cost-Effectiveness:** Pay-per-use, no minimum spend
- **Simplicity:** Direct REST API calls (no SDKs needed)
- **Claude Advantage:** Longer context, lower cost per token
- **GPT Advantage:** Faster response times, broader adoption

**Trade-offs:**
- **Advantages:**
  - Best-in-class language models for coaching quality
  - No infrastructure required (serverless from client perspective)
  - Easy API integration (http package sufficient)
  - Configurable per user preference/budget
  
- **Disadvantages:**
  - Requires internet connection (acceptable for MVP use case)
  - Per-call API costs (~$0.01-0.02 per coaching session)
  - Potential rate limiting (unlikely for solo developer MVP)

- **Best for:** Apps requiring high-quality natural language generation

**Configuration Approach:**

```dart
// config.dart (gitignored)
enum AIProvider { anthropic, openai }

class AIConfig {
  static const AIProvider provider = AIProvider.anthropic;
  static const String anthropicApiKey = 'sk-ant-...';
  static const String openaiApiKey = 'sk-...';
}
```

**Alternatives Considered:**

**On-Device ML Model (TensorFlow Lite)**
**Score: 55/100**
- No internet required, no ongoing costs
- Significantly lower quality coaching text
- Requires model training or fine-tuning (complex, time-consuming)
- Limited vocabulary and contextual understanding
- Not feasible for MVP timeline

**Template-Based Coaching (No AI)**
**Score: 60/100**
- Simple if-else logic based on timing patterns
- No API costs or connectivity requirements
- Rigid, formulaic responses lacking personalization
- Doesn't leverage modern AI capabilities
- Misses key product differentiator

---

### 7.8 Data Persistence

#### **Recommended: SharedPreferences (metadata) + File System (audio)**
**Score: 91/100**

**Rationale:**
- **Simplicity:** SharedPreferences is key-value storage, extremely simple API
- **Solo Developer:** Native to Flutter, zero setup, well-documented
- **Functional Adequacy:** Perfect for small session metadata (10 sessions ≈ 50 KB JSON)
- **Performance:** Fast reads/writes for lightweight data
- **File System:** Standard approach for audio files (platform-agnostic paths)

**Trade-offs:**
- **Advantages:**
  - SharedPreferences: No database overhead for simple data
  - Zero configuration required
  - Automatic persistence across app restarts
  - Fast synchronous reads
  - File system naturally suited for large binary data (audio)
  
- **Disadvantages:**
  - SharedPreferences not suited for large datasets (not a concern: 10 sessions)
  - No relational queries (not needed: simple list)
  - Manual JSON serialization (trivial for Session model)

- **Best for:** Apps with small, flat data structures and binary file storage

**Alternatives Considered:**

**SQLite (sqflite)**
**Score: 75/100**
- Overkill for 10-session list with no relational needs
- Requires schema definition, migration handling
- Adds complexity for marginal benefit at MVP stage
- Better suited for hundreds/thousands of records with complex queries

**Hive**
**Score: 80/100**
- Fast NoSQL database, good for structured data
- Requires schema definition (TypeAdapters)
- More complex than SharedPreferences for this use case
- Good option if session history expands significantly post-MVP

**Firebase / Cloud Storage**
**Score: 50/100**
- Requires user accounts, internet connectivity
- Ongoing costs, privacy concerns
- Massive overkill for local-only MVP
- Consider for future cloud sync feature

---

### 7.9 HTTP Client (AI API Calls)

#### **Recommended: http package**
**Score: 90/100**

**Rationale:**
- **Simplicity:** Flutter's official HTTP package, minimal API surface
- **Solo Developer:** Straightforward request/response pattern, excellent docs
- **Functional Adequacy:** All needed features (POST, headers, JSON body)
- **Lightweight:** Small package size, no unnecessary features
- **Consistency:** Official Flutter Foundation package

**Trade-offs:**
- **Advantages:**
  - Simple API: `http.post(url, headers: {...}, body: jsonEncode(...))`
  - Official support and maintenance
  - Easy to understand for beginners
  - Sufficient for AI API integration needs
  
- **Disadvantages:**
  - No built-in retry logic (implement manually if needed)
  - No request/response interceptors (not needed for MVP)
  - Manual JSON encoding/decoding (trivial)

- **Best for:** Simple RESTful API integrations without complex requirements

**Alternatives Considered:**

**dio**
**Score: 85/100**
- More features (interceptors, file uploads, retries)
- Heavier package
- Overkill for simple AI API POST requests
- Better suited for complex API integrations

---

### 7.10 Development Environment

#### **Recommended: Android Studio + Flutter Plugin**
**Score: 94/100**

**Rationale:**
- **Simplicity:** Official IDE recommended by Flutter team
- **Solo Developer:** Integrated emulator, debugging, profiling
- **Functional Adequacy:** All Flutter development needs covered
- **Android Target:** Native support for Android SDK, AVD management
- **Tooling:** Excellent Dart analyzer, hot reload, widget inspector

**Trade-offs:**
- **Advantages:**
  - Complete IDE with all necessary tools
  - Android emulator integrated
  - Excellent debugging (breakpoints, hot reload, widget inspector)
  - Flutter plugin officially maintained
  - Strong Dart language support
  
- **Disadvantages:**
  - Heavy RAM usage (8 GB recommended, 16 GB ideal)
  - Slower startup than lightweight editors
  - Occasional plugin update issues (minor)

- **Best for:** Flutter development with Android as primary target

**Alternatives Considered:**

**VS Code + Flutter Extension**
**Score: 88/100**
- Lightweight, faster startup
- Great for code editing, adequate debugging
- Requires separate Android Studio installation for SDK/emulator
- Good choice if RAM-constrained or prefer lighter editor

**IntelliJ IDEA + Flutter Plugin**
**Score: 87/100**
- Similar to Android Studio (same base)
- More general-purpose features
- Slightly heavier than needed for pure Flutter work

---

### 7.11 Version Control & Deployment

#### **Recommended: Git + GitHub**
**Score: 95/100**

**Rationale:**
- **Simplicity:** Industry-standard version control
- **Solo Developer:** Free private repositories, excellent documentation
- **Functional Adequacy:** Handles all version control, collaboration (future), CI/CD integration needs
- **Tooling:** GitHub Actions for potential automated builds

**Trade-offs:**
- **Advantages:**
  - Free for solo developers
  - Excellent integration with Android Studio / VS Code
  - GitHub Actions for CI/CD (optional, future)
  - Industry-standard skills
  
- **Disadvantages:**
  - Requires learning Git basics (essential skill regardless)
  - Must remember to gitignore sensitive files (API keys, keystore)

- **Best for:** Any software development project

**Deployment Approach (MVP):**
- Manual builds via Android Studio
- Generate signed APK for testing
- Distribute via file sharing (email, Drive, etc.)
- Future: Google Play Store once MVP validated

---

### 7.12 Testing Framework

#### **Recommended: Flutter Test (built-in)**
**Score: 93/100**

**Rationale:**
- **Simplicity:** Included with Flutter, zero setup
- **Solo Developer:** Familiar API (similar to other testing frameworks)
- **Functional Adequacy:** Unit tests, widget tests, integration tests all supported
- **Tooling:** Excellent IDE integration, code coverage reports

**Trade-offs:**
- **Advantages:**
  - No additional packages required
  - Widget testing unique to Flutter (test UI without devices)
  - Mock support built-in
  - Fast test execution
  
- **Disadvantages:**
  - Integration tests can be slow (run on real devices/emulators)
  - Mocking complex dependencies requires packages (mockito)

- **Best for:** Flutter projects of any size

**Additional Packages:**

**mockito (for mocking)**
**Score: 90/100**
- Standard mocking library for Dart
- Necessary for testing controllers with external dependencies
- Simple API, code generation support

---

### 7.13 Summary: Complete Technology Stack (MVP)

| Layer | Technology | Score | Key Rationale |
|-------|-----------|-------|---------------|
| **Framework** | Flutter | 95/100 | Cross-platform ready, hot reload, rich packages |
| **Language** | Dart | 95/100 | Required by Flutter, modern, strongly typed |
| **State Management** | Provider | 92/100 | Simple, official, perfect for MVP complexity |
| **Audio Recording** | flutter_sound | 90/100 | Unified recording + playback, format conversion |
| **Audio Playback** | flutter_sound | 90/100 | Same package, metronome clicks + session playback |
| **FFT / Onset Detection** | fftea | 88/100 | Pure Dart, simple API, sufficient performance |
| **AI Service** | Claude / GPT (config) | 93/100 | Quality coaching, configurable, cost-effective |
| **HTTP Client** | http | 90/100 | Official, simple, sufficient for AI API calls |
| **Persistence (metadata)** | SharedPreferences | 91/100 | Perfect for small JSON data |
| **Persistence (audio)** | File System | 95/100 | Standard approach for binary files |
| **IDE** | Android Studio | 94/100 | Official, comprehensive, Android-focused |
| **Version Control** | Git + GitHub | 95/100 | Industry standard, free, future CI/CD ready |
| **Testing** | Flutter Test + mockito | 93/100 | Built-in, comprehensive, easy mocking |

**Consistency Check:**
All recommendations align with:
- Simplicity-first mandate (no over-engineering)
- Solo developer capacity (learnable, maintainable)
- Android-only MVP scope (iOS-ready architecture)
- Speed to market (mature packages, avoid custom implementations)
- Cost efficiency (minimal ongoing costs except AI API)

---

## 8. Implementation Roadmap

### 8.1 Overview

This roadmap breaks MVP development into achievable phases for a solo developer with Flutter beginner experience, emphasizing incremental progress and testability. Total estimated duration: **13-14 weeks part-time** (10-15 hours/week).

### 8.2 Phase 0: Environment Setup & Foundation
**Duration: 3-5 days**

**Goal:** Establish development environment and project structure

**Tasks:**

1. **Development Environment**
   - Install Android Studio + Flutter SDK (latest stable)
   - Configure Android emulator (API 30+ recommended)
   - Install VS Code (optional, for lighter editing)
   - Setup version control (Git + GitHub private repo)
   - Create `.gitignore` for Flutter (include `config.dart`)

2. **Project Initialization**
   - Create new Flutter project: `flutter create ai_rhythm_coach`
   - Setup project structure:
     ```
     lib/
       models/
       controllers/
       screens/
       widgets/
       services/
       utils/
       config.dart (gitignored)
     assets/
       audio/
         click_high.wav
         click_low.wav
     ```

3. **Dependencies Configuration**
   - Add to `pubspec.yaml`:
     ```yaml
     dependencies:
       flutter:
         sdk: flutter
       provider: ^6.0.5
       flutter_sound: ^9.2.13
       fftea: ^1.0.0
       http: ^1.1.0
       shared_preferences: ^2.2.0
       path_provider: ^2.1.0
       uuid: ^4.0.0
     
     dev_dependencies:
       flutter_test:
         sdk: flutter
       mockito: ^5.4.0
       build_runner: ^2.4.0
     ```
   - Run `flutter pub get`

4. **Configuration Setup**
   - Create `lib/config.dart`:
     ```dart
     enum AIProvider { anthropic, openai }
     
     class AIConfig {
       static const AIProvider provider = AIProvider.anthropic;
       static const String anthropicApiKey = 'YOUR_KEY_HERE';
       static const String openaiApiKey = 'YOUR_KEY_HERE';
     }
     ```
   - Add `config.dart` to `.gitignore`
   - Obtain API keys (Anthropic or OpenAI)

5. **Asset Preparation**
   - Generate or obtain metronome click audio files:
     - `click_high.wav` (800 Hz sine wave, 50ms)
     - `click_low.wav` (400 Hz sine wave, 50ms)
   - Add assets to `pubspec.yaml`:
     ```yaml
     flutter:
       assets:
         - assets/audio/
     ```

**Success Criteria:**
- Flutter project builds and runs on Android emulator
- Git repository initialized and pushed to GitHub
- All dependencies resolve successfully
- Assets load without errors

---

### 8.3 Phase 1: Data Models & State Foundation
**Duration: 1 week**

**Goal:** Implement core data models and basic state management structure

**Tasks:**

1. **Data Models**
   - Implement `TapEvent` model with JSON serialization
   - Implement `Session` model with JSON serialization
   - Implement `PracticeState` enum
   - Write unit tests for serialization/deserialization

2. **Basic Controllers (Shell)**
   - Create `PracticeController` extending `ChangeNotifier`
     - State property + setter
     - BPM property + setter (with validation 40-200)
     - Stub methods: `startSession()`, `reset()`
   - Create `SessionManager` class
     - Constructor with SharedPreferences injection
     - Stub methods: `saveSession()`, `getSessions()`, `getSession()`

3. **Provider Setup**
   - Configure `MultiProvider` in `main.dart`:
     ```dart
     void main() async {
       WidgetsFlutterBinding.ensureInitialized();
       final prefs = await SharedPreferences.getInstance();
       
       runApp(
         MultiProvider(
           providers: [
             ChangeNotifierProvider(create: (_) => PracticeController(...)),
             Provider(create: (_) => SessionManager(prefs)),
             // Add service providers in later phases
           ],
           child: MyApp(),
         ),
       );
     }
     ```

4. **Testing**
   - Unit tests for `TapEvent` and `Session` models
   - Unit tests for `PracticeController` state transitions
   - Unit tests for `SessionManager` (using mock SharedPreferences)

**Success Criteria:**
- All data models serialize/deserialize correctly
- `PracticeController` state changes notify listeners
- Tests pass with >80% coverage for models/controllers

---

### 8.4 Phase 2: Audio Services Implementation
**Duration: 2 weeks**

**Goal:** Implement all audio-related functionality (recording, playback, metronome)

**Tasks:**

1. **AudioService Foundation**
   - Create `AudioService` class
   - Implement `initialize()` and `dispose()` methods
   - Setup flutter_sound recorder and player instances
   - Handle audio session permissions (Android)

2. **Recording Implementation**
   - Implement `startRecording()` method
     - Generate timestamped filename
     - Record to AAC format
     - Store in app documents directory
   - Implement `stopRecording()` method
     - Return file path
   - Test recording on real device (emulator has limited audio support)

3. **Metronome Implementation**
   - Implement `playCountIn(int bpm)` method
     - Play 4 high clicks at specified BPM
     - Wait between clicks
   - Implement `startMetronome(int bpm)` method
     - Use Timer.periodic for click scheduling
     - Play high click on beat 1 (downbeat)
     - Play low click on beats 2-4
   - Implement `stopMetronome()` method
     - Cancel timer
     - Stop playback

4. **Playback Implementation**
   - Implement `playRecording(String filePath)` method
     - Play recorded audio file
     - Handle playback state (playing/stopped)

5. **Testing**
   - Manual testing on physical Android device
   - Verify:
     - Recording quality (audible taps)
     - Metronome timing accuracy (use external metronome app for comparison)
     - Count-in behavior (4 beats before recording starts)
     - Simultaneous recording + metronome playback

**Success Criteria:**
- Can record 60 seconds of audio successfully
- Metronome plays accurate clicks at 40-200 BPM range
- Count-in plays correctly (4 beats)
- Audio files saved to correct location
- No crashes or audio glitches

---

### 8.5 Phase 3: Rhythm Analysis Implementation
**Duration: 2 weeks**

**Goal:** Implement FFT-based onset detection and rhythm analysis

**Tasks:**

1. **RhythmAnalyzer Foundation**
   - Create `RhythmAnalyzer` class
   - Implement `analyzeAudio()` main method skeleton

2. **Audio Loading**
   - Implement `_loadAudioSamples(String filePath)` method
     - Use flutter_sound to decode audio file to PCM
     - Convert to List<double> normalized samples (-1.0 to 1.0)
     - Handle format conversion (AAC → PCM)

3. **Onset Detection**
   - Implement `_detectOnsets(List<double> samples)` method
     - Sliding window FFT (2048 samples, 512 hop size)
     - Calculate spectral flux (difference between consecutive frames)
     - Apply threshold to detect onset peaks
     - Return onset times in seconds
   - Tune threshold value through experimentation

4. **Beat Matching**
   - Implement `_generateExpectedBeats(int bpm, int durationSeconds)` method
     - Calculate beat interval (60.0 / bpm)
     - Generate list of expected beat times
   - Implement `_matchOnsetsToBeats(List<double> onsets, List<double> beats)` method
     - For each expected beat, find nearest onset within ±300ms
     - Calculate timing error (actual - expected) in milliseconds
     - Return List<TapEvent>

5. **Testing & Tuning**
   - Create test audio files with known tap patterns
   - Verify onset detection accuracy:
     - Test with various BPMs (40, 80, 120, 160, 200)
     - Test with different tap intensities (loud, soft)
     - Tune FFT parameters and thresholds for best accuracy
   - Target: 90%+ tap detection rate for clear taps

**Success Criteria:**
- Detects 90%+ of taps on test recordings
- Timing error calculations are accurate (compare to manual analysis)
- Works across 40-200 BPM range
- Processing time <5 seconds for 60s audio on mid-range Android device

---

### 8.6 Phase 4: AI Coaching Integration
**Duration: 1.5 weeks**

**Goal:** Implement AI service integration for coaching generation

**Tasks:**

1. **AICoachingService Foundation**
   - Create `AICoachingService` class
   - Inject http.Client for testability
   - Create `AIServiceException` custom exception

2. **Prompt Building**
   - Implement `_buildPrompt()` method
     - Format session metrics (BPM, average error, consistency)
     - Calculate early/late/on-time counts
     - Include first 10 timing errors for context
     - Structure prompt according to specification (Section 6.2)

3. **API Integration**
   - Implement `_callClaudeAPI(String prompt)` method
     - POST to Anthropic endpoint
     - Handle response parsing
     - Extract coaching text from response
   - Implement `_callOpenAIAPI(String prompt)` method
     - POST to OpenAI endpoint
     - Handle response parsing
     - Extract coaching text from response
   - Implement `generateCoaching()` method
     - Select API based on AIConfig.provider
     - Call appropriate API method
     - Return coaching text

4. **Error Handling**
   - Handle network errors (no internet)
   - Handle API errors (401, 429, 500)
   - Implement graceful fallback messages
   - Test offline behavior (should save session without coaching)

5. **Testing**
   - Mock API responses for unit testing
   - Test with real API calls (use test data):
     - Verify coaching quality at different BPMs
     - Verify coaching quality for different error patterns (early, late, inconsistent)
     - Test error scenarios (invalid API key, rate limit)
   - Estimate API costs: ~$0.01-0.02 per session

**Success Criteria:**
- Generates coaching text within 3-5 seconds
- Coaching text is relevant to session metrics
- Error handling prevents app crashes
- API costs are acceptable for MVP testing

---

### 8.7 Phase 5: Practice Screen UI
**Duration: 1.5 weeks**

**Goal:** Build complete Practice Screen with state-driven UI

**Tasks:**

1. **Basic Screen Layout**
   - Create `PracticeScreen` StatelessWidget
   - Implement Consumer<PracticeController> structure
   - Build static layout (app bar, title, placeholder widgets)

2. **BPM Selector Widget**
   - Implement BPM display text
   - Implement BPM slider (40-200 range, divisions: 160)
   - Connect to `controller.setBpm()`
   - Test slider responsiveness

3. **Action Button Widget**
   - Implement state-based button text logic
   - Implement state-based button enabled/disabled logic
   - Connect to `controller.startSession()` or navigate to Results
   - Style button appropriately (size, padding, colors)

4. **Status Icon & Message Widgets**
   - Implement icon switching based on state (mic, metronome, recording, spinner, checkmark, warning)
   - Implement status message switching based on state
   - Add animations (optional, for polish)

5. **Recent Sessions Widget (Basic)**
   - Display list of recent session timestamps
   - Make list items tappable (navigate to Results screen)
   - Use FutureBuilder to load sessions from SessionManager

6. **State Integration**
   - Connect all widgets to PracticeController via Consumer
   - Ensure UI updates on state changes
   - Test all state transitions (idle → countIn → recording → processing → completed → idle)

**Success Criteria:**
- UI accurately reflects all PracticeState values
- BPM selection works smoothly
- Button behavior matches state machine
- Can navigate to Results screen (even if Results screen incomplete)

---

### 8.8 Phase 6: Controller Integration & Session Flow
**Duration: 1.5 weeks**

**Goal:** Implement complete practice session orchestration in PracticeController

**Tasks:**

1. **Service Injection**
   - Inject AudioService, RhythmAnalyzer, AICoachingService, SessionManager into PracticeController
   - Update Provider configuration in main.dart

2. **Session Start Logic**
   - Implement `startSession()` method:
     - Set state to countIn
     - Call `AudioService.playCountIn()`
     - Set state to recording
     - Start recording and metronome simultaneously
     - Wait 60 seconds (Future.delayed)
     - Stop recording and metronome
     - Proceed to processing

3. **Session Processing Logic**
   - Implement `_processSession(String audioFilePath)` method:
     - Set state to processing
     - Call `RhythmAnalyzer.analyzeAudio()`
     - Calculate average error and consistency
     - Call `AICoachingService.generateCoaching()`
     - Create Session object
     - Call `SessionManager.saveSession()`
     - Set state to completed

4. **Error Handling**
   - Implement `_handleError()` method
     - Set state to error
     - Set appropriate error message
     - Notify listeners
   - Test error scenarios:
     - Recording failure (permission denied)
     - AI service failure (no internet)
     - General exceptions

5. **Testing**
   - End-to-end testing on physical device:
     - Complete session: start → count-in → record → process → results
     - Verify each state transition
     - Verify session saved correctly
     - Test at multiple BPMs (40, 80, 120, 160, 200)
   - Test error recovery (retry after error)

**Success Criteria:**
- Complete practice session flows from start to finish
- Session data persists correctly
- AI coaching generates successfully
- Error states handle gracefully
- No crashes or hangs

---

### 8.9 Phase 7: Results Screen UI
**Duration: 1 week**

**Goal:** Build Results Screen to display session data and coaching

**Tasks:**

1. **Basic Screen Layout**
   - Create `ResultsScreen` StatelessWidget
   - Accept `Session` parameter in constructor
   - Implement app bar with back button
   - Build static layout structure

2. **Session Info Display**
   - Format and display timestamp
   - Display BPM

3. **Performance Metrics Card**
   - Display average error (formatted to 1 decimal place)
   - Display consistency (formatted to 1 decimal place)
   - Display total beats detected
   - Display early/late/on-time counts with colored indicators

4. **AI Coaching Card**
   - Display coaching text with appropriate styling
   - Add lightbulb icon for visual clarity
   - Style card with distinct background color

5. **Action Buttons**
   - Implement "Play Recording" button
     - Connect to `AudioService.playRecording()`
   - Implement "Practice Again" button
     - Navigate back to Practice Screen
     - Reset PracticeController state

6. **Polish**
   - Add spacing, padding, alignment
   - Test on various screen sizes (use different emulator configs)
   - Ensure scrollability for smaller screens

**Success Criteria:**
- All session data displays correctly
- Coaching text is readable and well-styled
- Playback button plays recorded audio
- Navigation works smoothly

---

### 8.10 Phase 8: SessionManager Implementation
**Duration: 3-4 days**

**Goal:** Complete session persistence functionality

**Tasks:**

1. **Save Session Implementation**
   - Implement `saveSession(Session session)` method:
     - Load existing sessions from SharedPreferences
     - Add new session at front of list
     - Trim to max 10 sessions
     - Delete audio file of removed session
     - Serialize list to JSON
     - Save to SharedPreferences

2. **Load Sessions Implementation**
   - Implement `getSessions()` method:
     - Load JSON string from SharedPreferences
     - Deserialize to List<Session>
     - Return list (most recent first)
   - Implement `getSession(String id)` method

3. **File Management**
   - Implement `_deleteAudioFile(String path)` helper method
   - Test file deletion works correctly

4. **Testing**
   - Test save/load cycle (save session, restart app, verify load)
   - Test 10-session limit (save 11+ sessions, verify oldest deleted)
   - Test audio file cleanup (verify deleted session audio removed)

**Success Criteria:**
- Sessions persist across app restarts
- Session limit enforced (max 10)
- Old audio files deleted automatically
- No SharedPreferences storage issues

---

### 8.11 Phase 9: Testing & Bug Fixes
**Duration: 1.5 weeks**

**Goal:** Comprehensive testing and bug resolution

**Tasks:**

1. **Unit Testing Coverage**
   - Write/complete unit tests for all controllers
   - Write/complete unit tests for all services
   - Target: >80% code coverage
   - Run: `flutter test --coverage`

2. **Widget Testing**
   - Widget tests for Practice Screen state rendering
   - Widget tests for Results Screen data display
   - Widget tests for BPM selector behavior

3. **Integration Testing**
   - End-to-end test: complete practice session flow
   - Test on multiple Android devices (different API levels, screen sizes)
   - Test at boundary BPMs (40, 200)

4. **Bug Hunting & QA**
   - User your QA background to systematically test:
     - Edge cases (very fast/slow BPMs)
     - Error scenarios (no mic permission, no internet, invalid API key)
     - UI states (all state transitions)
     - Data persistence (restart app, clear cache)
   - Create bug tracking spreadsheet
   - Prioritize and fix critical bugs

5. **Performance Testing**
   - Measure audio processing time (target: <5s)
   - Measure app startup time
   - Check memory usage (no leaks)
   - Test battery drain during 60s recording

**Success Criteria:**
- All critical bugs fixed
- Unit test coverage >80%
- App runs smoothly on test devices
- No crashes in normal use cases

---

### 8.12 Phase 10: Polish & MVP Finalization
**Duration: 1 week**

**Goal:** Final polish and prepare for user testing

**Tasks:**

1. **UI Polish**
   - Refine colors, spacing, typography
   - Add loading indicators where appropriate
   - Improve button states and feedback
   - Test dark mode (if supported)

2. **User Experience Improvements**
   - Add helpful tooltips or hints
   - Improve error messages (user-friendly language)
   - Add confirmation dialogs where appropriate (e.g., "Start recording?")

3. **Documentation**
   - Write README.md with:
     - Project description
     - Setup instructions
     - Build instructions
     - API key configuration
   - Document known limitations
   - Document post-MVP feature ideas

4. **Build & Distribution Preparation**
   - Generate signed APK:
     - Create keystore
     - Configure signing in `build.gradle`
     - Build release APK: `flutter build apk --release`
   - Test release APK on physical device
   - Create installation instructions for testers

5. **Deployment Preparation**
   - Setup GitHub releases
   - Prepare initial release notes
   - Create simple landing page (optional)

**Success Criteria:**
- Release APK builds successfully
- App installs and runs on test devices
- Documentation is complete and clear
- Ready for user testing

---

### 8.13 Phase 11: User Testing & Iteration
**Duration: Ongoing (2+ weeks)

**Goal:** Gather real-world usage data and iterate

**Tasks:**

1. **User Testing Setup**
   - Recruit 5-10 drummers/musicians
   - Distribute APK via Google Drive or email
   - Provide brief user guide

2. **Feedback Collection**
   - Create feedback form (Google Forms)
   - Ask about:
     - AI coaching quality and relevance
     - Rhythm analysis accuracy (do detected taps match reality?)
     - UI usability
     - Feature requests
   - Monitor for crashes (Firebase Crashlytics optional)

3. **Data Analysis**
   - Review session data (timing errors, BPM distributions)
   - Identify algorithm tuning opportunities (FFT thresholds, onset detection sensitivity)
   - Assess AI coaching patterns (are responses helpful?)

4. **Iteration**
   - Prioritize fixes/improvements based on feedback
   - Implement critical bug fixes
   - Tune rhythm analysis algorithm if needed
   - Refine AI prompts if coaching quality issues
   - Release updated versions

**Success Criteria:**
- 5+ users complete at least 3 practice sessions
- Gather actionable feedback
- Identify high-priority improvements for post-MVP
- Validate core concept (does AI coaching provide value?)

---

### 8.14 Roadmap Summary Table

| Phase | Duration | Key Deliverables |
|-------|----------|------------------|
| 0: Setup | 3-5 days | Dev environment, project structure, dependencies |
| 1: Data Models | 1 week | Models, basic controllers, Provider setup |
| 2: Audio Services | 2 weeks | Recording, metronome, playback, count-in |
| 3: Rhythm Analysis | 2 weeks | FFT, onset detection, beat matching |
| 4: AI Integration | 1.5 weeks | API calls, prompt building, error handling |
| 5: Practice UI | 1.5 weeks | Practice Screen, state-driven UI |
| 6: Controller Integration | 1.5 weeks | Complete session orchestration |
| 7: Results UI | 1 week | Results Screen, session display |
| 8: SessionManager | 3-4 days | Persistence implementation |
| 9: Testing & Bugs | 1.5 weeks | Comprehensive testing, bug fixes |
| 10: Polish & Finalization | 1 week | UI polish, documentation, release build |
| 11: User Testing | 2+ weeks | Feedback collection, iteration |

**Total MVP Timeline: 13-14 weeks part-time (10-15 hours/week)**

---

## 9. Testing Strategy

### 9.1 Testing Approach

**Testing Pyramid:**
```
        /\
       /E2E\       ← Few integration tests (critical paths)
      /------\
     /Widget \     ← Moderate widget tests (UI components)
    /----------\
   /   Unit     \  ← Many unit tests (models, controllers, services)
  /--------------\
```

### 9.2 Unit Testing

**Target Coverage: >80%**

**Test Suites:**

1. **Models**
   - `TapEvent` serialization/deserialization
   - `Session` serialization/deserialization
   - Model property validation

2. **Controllers**
   - `PracticeController` state transitions
   - `PracticeController` BPM validation (40-200 range)
   - `PracticeController` error handling

3. **Services**
   - `SessionManager` save/load operations (mock SharedPreferences)
   - `SessionManager` session limit enforcement
   - `RhythmAnalyzer` onset detection logic (use synthetic test data)
   - `RhythmAnalyzer` beat matching algorithm
   - `AICoachingService` prompt building
   - `AICoachingService` API response parsing (mock HTTP responses)

**Example Unit Test:**

```dart
// test/controllers/practice_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:ai_rhythm_coach/controllers/practice_controller.dart';

void main() {
  group('PracticeController', () {
    test('initial state is idle', () {
      final controller = PracticeController(...);
      expect(controller.state, PracticeState.idle);
    });
    
    test('setBpm validates range', () {
      final controller = PracticeController(...);
      
      controller.setBpm(120);
      expect(controller.bpm, 120);
      
      controller.setBpm(250); // Above max
      expect(controller.bpm, 120); // Unchanged
      
      controller.setBpm(30); // Below min
      expect(controller.bpm, 120); // Unchanged
    });
  });
}
```

### 9.3 Widget Testing

**Test Suites:**

1. **Practice Screen**
   - BPM slider interaction
   - Button text changes based on state
   - Button enabled/disabled based on state
   - Status message updates

2. **Results Screen**
   - Session data displays correctly
   - Metrics calculation and display
   - Coaching text displays

**Example Widget Test:**

```dart
// test/screens/practice_screen_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_rhythm_coach/screens/practice_screen.dart';

void main() {
  testWidgets('Start button shows correct text in idle state', (tester) async {
    final controller = MockPracticeController();
    when(controller.state).thenReturn(PracticeState.idle);
    
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: controller,
          child: PracticeScreen(),
        ),
      ),
    );
    
    expect(find.text('Start Session'), findsOneWidget);
  });
}
```

### 9.4 Integration Testing

**Critical Paths:**

1. **Complete Practice Session Flow**
   - User starts session
   - Count-in plays (4 beats)
   - Recording captures 60 seconds with metronome
   - Processing analyzes audio
   - AI generates coaching
   - Session saves
   - Results screen displays

2. **Session History**
   - User completes session
   - Session appears in recent list
   - User taps session in list
   - Results screen loads with correct data

**Example Integration Test Outline:**

```dart
// integration_test/practice_session_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('Complete practice session flow', (tester) async {
    // Start app
    await tester.pumpWidget(MyApp());
    
    // Find and tap Start Session button
    final startButton = find.text('Start Session');
    await tester.tap(startButton);
    await tester.pumpAndSettle();
    
    // Verify count-in state
    expect(find.text('Count-in...'), findsOneWidget);
    
    // Wait for recording to complete (60s + processing time)
    await tester.pump(Duration(seconds: 70));
    
    // Verify completion
    expect(find.text('View Results'), findsOneWidget);
    
    // Navigate to results
    await tester.tap(find.text('View Results'));
    await tester.pumpAndSettle();
    
    // Verify results screen
    expect(find.text('Session Results'), findsOneWidget);
    expect(find.textContaining('BPM'), findsOneWidget);
    expect(find.textContaining('AI Coaching'), findsOneWidget);
  });
}
```

### 9.5 Manual Testing Checklist

**Functional Testing:**
- [ ] Recording captures audio correctly
- [ ] Metronome plays accurate tempo (verify with external metronome)
- [ ] Count-in plays 4 beats before recording
- [ ] Onset detection finds taps accurately
- [ ] AI coaching generates successfully
- [ ] Session saves and persists
- [ ] Session history displays correctly
- [ ] Playback works on Results screen
- [ ] BPM selector validates range (40-200)

**Edge Cases:**
- [ ] Very slow BPM (40)
- [ ] Very fast BPM (200)
- [ ] Soft taps (low volume)
- [ ] Loud taps (high volume)
- [ ] Inconsistent playing (intentionally erratic)
- [ ] No taps detected (complete silence)
- [ ] Background noise (test in noisy environment)

**Error Scenarios:**
- [ ] No microphone permission (deny permission)
- [ ] No internet connection (airplane mode)
- [ ] Invalid API key (test with wrong key)
- [ ] API rate limit (spam requests)
- [ ] Storage full (simulate low storage)

**Platform Testing:**
- [ ] Test on Android 8.0 (API 26)
- [ ] Test on Android 11+ (API 30+)
- [ ] Test on small screen (5" phone)
- [ ] Test on large screen (6.5"+ phone)
- [ ] Test on tablet (if available)

---

## 10. Security & Configuration

### 10.1 API Key Management

**Critical Security Practice:**

**NEVER commit API keys to version control.**

**Implementation:**

1. **Config File (Gitignored):**
   ```dart
   // lib/config.dart
   enum AIProvider { anthropic, openai }
   
   class AIConfig {
     static const AIProvider provider = AIProvider.anthropic;
     static const String anthropicApiKey = 'sk-ant-...';
     static const String openaiApiKey = 'sk-...';
   }
   ```

2. **Gitignore Entry:**
   ```
   # .gitignore
   lib/config.dart
   ```

3. **Template File (Committed):**
   ```dart
   // lib/config.dart.template
   enum AIProvider { anthropic, openai }
   
   class AIConfig {
     static const AIProvider provider = AIProvider.anthropic;
     static const String anthropicApiKey = 'YOUR_ANTHROPIC_KEY_HERE';
     static const String openaiApiKey = 'YOUR_OPENAI_KEY_HERE';
   }
   ```

4. **Setup Instructions in README:**
   ```markdown
   ## Setup
   
   1. Copy `lib/config.dart.template` to `lib/config.dart`
   2. Add your API key(s) to `lib/config.dart`
   3. Select your preferred AI provider
   ```

### 10.2 Permissions

**Android Manifest (`android/app/src/main/AndroidManifest.xml`):**

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Required for audio recording -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    
    <!-- Required for audio playback -->
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    
    <!-- Required for file storage -->
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    
    <!-- Required for AI API calls -->
    <uses-permission android:name="android.permission.INTERNET" />
    
    <application>
        <!-- ... -->
    </application>
</manifest>
```

**Runtime Permission Handling:**

```dart
// In AudioService.initialize()
import 'package:permission_handler/permission_handler.dart';

Future<void> initialize() async {
  // Request microphone permission
  final status = await Permission.microphone.request();
  
  if (status.isDenied) {
    throw AudioRecordingException('Microphone permission denied');
  }
  
  // Initialize audio session
  _recorder = FlutterSoundRecorder();
  _player = FlutterSoundPlayer();
  
  await _recorder!.openRecorder();
  await _player!.openPlayer();
}
```

### 10.3 Data Privacy

**Local-Only Storage:**
- All session data stored locally on device
- No user accounts or cloud sync in MVP
- Audio files stored in app-private directory (not accessible by other apps)

**Privacy Policy (Future):**
- If publishing to Google Play Store, must include privacy policy
- Disclose: audio recording, AI API data transmission
- For MVP: not required if distributing APK directly

### 10.4 Code Obfuscation (Release Builds)

**Build Configuration:**

```bash
# Build release APK with code obfuscation
flutter build apk --release --obfuscate --split-debug-info=./debug-info
```

**Benefits:**
- Makes reverse-engineering harder
- Smaller APK size
- Protects API keys (partially, not substitute for proper key management)

---

## Appendix A: File Structure Reference

```
ai_rhythm_coach/
├── android/
│   └── app/
│       └── src/
│           └── main/
│               └── AndroidManifest.xml
├── assets/
│   └── audio/
│       ├── click_high.wav
│       └── click_low.wav
├── lib/
│   ├── controllers/
│   │   └── practice_controller.dart
│   ├── models/
│   │   ├── practice_state.dart
│   │   ├── session.dart
│   │   └── tap_event.dart
│   ├── screens/
│   │   ├── practice_screen.dart
│   │   └── results_screen.dart
│   ├── services/
│   │   ├── ai_coaching_service.dart
│   │   ├── audio_service.dart
│   │   ├── rhythm_analyzer.dart
│   │   └── session_manager.dart
│   ├── widgets/
│   │   └── (reusable UI components as needed)
│   ├── config.dart (gitignored)
│   ├── config.dart.template (committed)
│   └── main.dart
├── test/
│   ├── controllers/
│   ├── models/
│   ├── services/
│   └── screens/
├── integration_test/
│   └── practice_session_test.dart
├── .gitignore
├── pubspec.yaml
└── README.md
```

---

## Appendix B: Key Package Documentation Links

| Package | Documentation URL |
|---------|------------------|
| Provider | https://pub.dev/packages/provider |
| flutter_sound | https://pub.dev/packages/flutter_sound |
| fftea | https://pub.dev/packages/fftea |
| http | https://pub.dev/packages/http |
| shared_preferences | https://pub.dev/packages/shared_preferences |
| path_provider | https://pub.dev/packages/path_provider |
| uuid | https://pub.dev/packages/uuid |
| mockito | https://pub.dev/packages/mockito |

---

## Appendix C: Estimated Costs

**Development Costs:**
- Flutter: Free
- Android Studio: Free
- Android Emulator: Free
- Git + GitHub: Free (private repo)

**Testing Costs:**
- Physical Android device: $100-300 (one-time, use existing if available)
- AI API testing: ~$5-10 for 100-200 test sessions

**MVP User Testing Costs:**
- AI API (10 users × 10 sessions × $0.015/session): ~$1.50

**Total MVP Budget: <$20 (excluding hardware)**

---

## Appendix D: Post-MVP Feature Ideas

**Features to Consider After MVP Validation:**

1. **iOS Support**
   - Leverage Flutter cross-platform architecture
   - Minimal code changes required
   - Estimated: 2-3 weeks

2. **Multiple Time Signatures**
   - Add 3/4, 6/8, 5/4, etc.
   - Requires UI for time signature selection
   - Rhythm analyzer logic updates

3. **Tap Tempo**
   - Let user tap to set BPM
   - Calculate average interval from taps

4. **Preset Management**
   - Save favorite BPM + time signature combos
   - Quick-access to presets

5. **Progress Tracking**
   - Show improvement over time
   - Charts for average error trends
   - Session streak counter

6. **Cloud Sync**
   - User accounts (Firebase Auth)
   - Cloud storage for sessions (Firebase Storage)
   - Cross-device sync

7. **Advanced Audio Visualization**
   - Waveform display
   - Real-time visual feedback during recording

8. **Custom Metronome Sounds**
   - Let users upload their own click sounds
   - Synthesize different instrument sounds

9. **Social Features**
   - Share sessions with friends
   - Leaderboards for accuracy

10. **Coaching Insights Dashboard**
    - Aggregate coaching themes
    - Identify recurring issues
    - Personalized practice recommendations

---

## Document End

**This technical specification is now complete and ready for Claude Code implementation.**

**Next Steps:**
1. Review this document thoroughly
2. Setup development environment (Phase 0)
3. Begin implementation following the roadmap
4. Use this document as reference throughout development

**For Questions or Clarifications:**
- Reference specific section numbers in this document
- Consult package documentation (Appendix B)
- Test assumptions early and iterate

**Good luck building your AI Rhythm Coach MVP! 🥁**
