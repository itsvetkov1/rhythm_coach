# Start Practice Flow Documentation

This document provides a complete, detailed explanation of what happens when a user presses the "Start Practice" button in the AI Rhythm Coach app.

---

## Table of Contents

1. [Quick Overview](#quick-overview)
2. [User Experience Flow (Layman's Terms)](#user-experience-flow-laymans-terms)
3. [Technical Implementation Overview](#technical-implementation-overview)
4. [Detailed Step-by-Step Flow](#detailed-step-by-step-flow)
5. [State Machine Diagram](#state-machine-diagram)
6. [Code Execution Path](#code-execution-path)
7. [Data Models & Structures](#data-models--structures)
8. [Error Handling](#error-handling)
9. [File System Operations](#file-system-operations)

---

## Quick Overview

**In Simple Terms:**
When you press "Start Practice", the app counts down 4 beats, then records you playing along with a metronome for 60 seconds. After recording, it analyzes your timing using sound wave analysis, generates personalized coaching feedback using AI, saves everything to your device, and shows you the results.

**Technical Summary:**
The button triggers a state machine transition orchestrated by `PracticeController`. It sequences: audio initialization → count-in playback → simultaneous recording+metronome → audio file processing via FFT onset detection → AI API call for coaching → persistence to SharedPreferences and file system → navigation to results screen.

---

## User Experience Flow (Layman's Terms)

### What the User Sees and Hears

1. **User Sets Tempo**: User adjusts the BPM slider (40-200) to set practice speed
2. **Presses "Start Practice"**: Button click initiates the session
3. **Count-In (4 seconds)**: Hears 4 metronome clicks (beep-beep-beep-beep) to prepare
4. **Recording Begins**:
   - Screen shows "Recording..." with countdown timer (60 seconds)
   - Metronome continues clicking (high pitch on beat 1, low pitch on beats 2-4)
   - User plays along with the metronome
5. **Recording Ends**: After 60 seconds, metronome stops
6. **Processing**: Screen shows "Processing..." while app analyzes the recording
7. **Results Display**: Navigates to results screen showing:
   - Timing statistics (average error, consistency)
   - Breakdown of early/late/on-time hits
   - AI-generated coaching feedback
   - Option to listen to the recording

**Total Duration**: ~70 seconds (4-beat count-in + 60s recording + ~5-10s processing)

---

## Technical Implementation Overview

### Architecture Pattern
**Layered Architecture with State Management**
- **Presentation Layer**: `PracticeScreen` (Flutter widget)
- **State Management**: `PracticeController` (ChangeNotifier pattern via Provider)
- **Service Layer**: `AudioService`, `RhythmAnalyzer`, `AICoachingService`, `SessionManager`
- **Persistence Layer**: SharedPreferences (metadata) + File System (audio files)

### Key Technologies
- **Flutter Sound**: Audio recording/playback using native Android APIs
- **FFT Analysis**: fftea library for frequency domain analysis
- **HTTP Client**: API calls to Claude/GPT
- **Provider**: Reactive state management

---

## Detailed Step-by-Step Flow

### Phase 1: Initialization & Count-In

#### Step 1.1: Button Press Detection
**File**: `ai_rhythm_coach/lib/widgets/practice_action_button.dart:16`

```dart
onPressed: () => controller.startSession(),
```

**What Happens**:
- User taps the "Start Practice" button
- Flutter's `onPressed` callback fires
- Calls `startSession()` method on `PracticeController`

---

#### Step 1.2: State Transition to Count-In
**File**: `ai_rhythm_coach/lib/controllers/practice_controller.dart:41-47`

```dart
Future<void> startSession() async {
  try {
    _setState(PracticeState.countIn);
    _errorMessage = null;

    await _audioService.initialize();
```

**What Happens**:
1. **State Change**: Sets state from `idle` → `countIn`
2. **UI Update**: `notifyListeners()` called, UI reacts to state change
3. **Error Reset**: Clears any previous error messages
4. **Audio Initialization**: Ensures `AudioService` is ready

**Layman's Terms**: App switches to "getting ready" mode and makes sure the microphone and speakers are working.

---

#### Step 1.3: Audio Service Initialization
**File**: `ai_rhythm_coach/lib/services/audio_service.dart:27-51`

```dart
Future<void> initialize() async {
  if (_isInitialized) return;

  final status = await Permission.microphone.request();
  if (!status.isGranted) {
    throw AudioRecordingException('Microphone permission denied...');
  }

  _recorder = FlutterSoundRecorder();
  _player = FlutterSoundPlayer();

  await _recorder!.openRecorder();
  await _player!.openPlayer();

  _clickHighPath = await _loadAssetToLocalFile('assets/audio/click_high.wav', ...);
  _clickLowPath = await _loadAssetToLocalFile('assets/audio/click_low.wav', ...);
```

**What Happens**:
1. **Skip if Ready**: Returns immediately if already initialized (optimization)
2. **Permission Check**: Requests Android microphone permission from user
3. **Recorder Setup**: Creates and opens `FlutterSoundRecorder` instance
4. **Player Setup**: Creates and opens `FlutterSoundPlayer` instance
5. **Load Click Sounds**:
   - Copies `click_high.wav` (800 Hz, 50ms) from app assets to temp directory
   - Copies `click_low.wav` (400 Hz, 50ms) from app assets to temp directory
   - These files are used for metronome clicks

**Layman's Terms**: App asks for permission to use your microphone, sets up the recording system, and loads the metronome sound files.

**Technical Details**:
- Uses `permission_handler` package for Android runtime permissions
- `flutter_sound` wraps native Android MediaRecorder/MediaPlayer
- Asset files are copied to temp storage because flutter_sound requires file paths, not asset bundles

---

#### Step 1.4: Play 4-Beat Count-In
**File**: `ai_rhythm_coach/lib/controllers/practice_controller.dart:49-50`

```dart
await _audioService.playCountIn(_bpm);
```

**Implementation**: `ai_rhythm_coach/lib/services/audio_service.dart:87-107`

```dart
Future<void> playCountIn(int bpm) async {
  final interval = Duration(milliseconds: (60000 / bpm).round());

  for (int i = 0; i < 4; i++) {
    await _player!.startPlayer(
      fromURI: _clickHighPath,
      codec: Codec.pcm16WAV,
      whenFinished: () {},
    );
    await Future.delayed(interval);
  }
}
```

**What Happens**:
1. **Calculate Timing**: `interval = 60,000ms / BPM`
   - Example: 120 BPM → 500ms per beat
   - Example: 60 BPM → 1000ms per beat
2. **Loop 4 Times**:
   - Play high-pitch click sound
   - Wait for `interval` duration
   - Repeat 3 more times
3. **Blocking Wait**: Entire count-in completes before proceeding

**Layman's Terms**: Plays 4 metronome beeps at the tempo you selected, giving you time to prepare to start playing.

**Technical Note**: This is a **synchronous** operation - the code waits for all 4 beats to complete before moving on. The `await` keyword ensures each click finishes playing before the delay starts.

---

### Phase 2: Recording Session

#### Step 2.1: State Transition to Recording
**File**: `ai_rhythm_coach/lib/controllers/practice_controller.dart:52-55`

```dart
_setState(PracticeState.recording);
await _audioService.startRecording();
await _audioService.startMetronome(_bpm);
```

**What Happens**:
1. **State Change**: `countIn` → `recording`
2. **UI Update**: Screen now shows "Recording..." with timer
3. **Start Recording**: Begins capturing microphone audio
4. **Start Metronome**: Begins continuous click track

**Layman's Terms**: App switches to recording mode and starts both recording your playing and playing the metronome simultaneously.

---

#### Step 2.2: Start Recording Audio
**File**: `ai_rhythm_coach/lib/services/audio_service.dart:110-127`

```dart
Future<void> startRecording() async {
  final directory = await getApplicationDocumentsDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  _currentRecordingPath = '${directory.path}/recording_$timestamp.wav';

  await _recorder!.startRecorder(
    toFile: _currentRecordingPath,
    codec: Codec.pcm16WAV,
  );
}
```

**What Happens**:
1. **Get Storage Location**: Finds app's private documents directory
   - Example: `/data/user/0/com.example.ai_rhythm_coach/app_flutter/`
2. **Generate Filename**: Creates unique filename with timestamp
   - Example: `recording_1700000000000.wav`
3. **Start Recorder**: Begins recording to WAV file
   - **Format**: PCM 16-bit WAV (uncompressed audio)
   - **Sample Rate**: 44,100 Hz (CD quality)
   - **Channels**: Mono (1 channel)

**Layman's Terms**: Creates a new audio file on your phone and starts recording everything your microphone hears into that file.

**Technical Details**:
- **WAV Format Chosen**: Uncompressed for easier processing (no codec decoding needed)
- **44.1 kHz Sample Rate**: Standard for audio analysis, provides good frequency resolution up to ~22 kHz
- **Timestamp in Filename**: Prevents filename collisions

---

#### Step 2.3: Start Metronome Click Track
**File**: `ai_rhythm_coach/lib/services/audio_service.dart:147-173`

```dart
Future<void> startMetronome(int bpm) async {
  final interval = Duration(milliseconds: (60000 / bpm).round());
  _beatCount = 0;

  _metronomeTimer = Timer.periodic(interval, (timer) async {
    _beatCount++;

    final clickFile = (_beatCount % 4 == 1)
        ? _clickHighPath
        : _clickLowPath;

    await _player!.startPlayer(
      fromURI: clickFile,
      codec: Codec.pcm16WAV,
      whenFinished: () {},
    );
  });
}
```

**What Happens**:
1. **Calculate Interval**: Same as count-in (60,000ms / BPM)
2. **Create Timer**: `Timer.periodic` fires callback every `interval`
3. **Beat Counter**: Tracks which beat number (1, 2, 3, 4, 1, 2, 3, 4...)
4. **Alternate Clicks**:
   - Beat 1 (downbeat): High-pitch click (800 Hz)
   - Beats 2, 3, 4: Low-pitch click (400 Hz)
5. **Play Click**: Plays appropriate click sound on each timer tick

**Layman's Terms**: Sets up a repeating timer that plays a metronome click at the right tempo. The first beat of each measure (1-2-3-4) gets a higher-pitched click so you can hear the rhythm pattern.

**Technical Details**:
- **Timer.periodic**: Dart's mechanism for repeated execution
- **Downbeat Emphasis**: Common in music (helps musicians stay oriented in the measure)
- **Asynchronous**: Timer runs in background, doesn't block other code
- **Error Handling**: Catches and ignores individual click failures to keep metronome running

---

#### Step 2.4: 60-Second Countdown Timer
**File**: `ai_rhythm_coach/lib/controllers/practice_controller.dart:57-63`

```dart
_recordingTimeRemaining = 60;
for (int i = 0; i < 60; i++) {
  await Future.delayed(const Duration(seconds: 1));
  _recordingTimeRemaining--;
  notifyListeners();
}
```

**What Happens**:
1. **Initialize Counter**: Set to 60 seconds
2. **Loop 60 Times**:
   - Wait 1 second
   - Decrement counter
   - Call `notifyListeners()` to update UI
3. **UI Updates**: Screen shows countdown: 60... 59... 58... ... 3... 2... 1... 0

**Layman's Terms**: Counts down from 60 to 0, updating the screen every second so you can see how much time is left.

**Technical Note**: This is a **blocking loop** - the code execution waits here for the full 60 seconds. Meanwhile, the metronome timer and recorder run independently in the background.

---

#### Step 2.5: Stop Recording and Metronome
**File**: `ai_rhythm_coach/lib/controllers/practice_controller.dart:65-67`

```dart
final audioFilePath = await _audioService.stopRecording();
await _audioService.stopMetronome();
```

**Stop Recording Implementation**: `ai_rhythm_coach/lib/services/audio_service.dart:130-144`

```dart
Future<String> stopRecording() async {
  await _recorder!.stopRecorder();
  if (_currentRecordingPath == null) {
    throw AudioRecordingException('No recording path available');
  }
  return _currentRecordingPath!;
}
```

**Stop Metronome Implementation**: `ai_rhythm_coach/lib/services/audio_service.dart:176-180`

```dart
Future<void> stopMetronome() async {
  _metronomeTimer?.cancel();
  _metronomeTimer = null;
  _beatCount = 0;
}
```

**What Happens**:
1. **Stop Recorder**: Finalizes WAV file, closes file handle
2. **Get File Path**: Returns path to completed audio file
3. **Cancel Timer**: Stops metronome timer (no more clicks)
4. **Reset Beat Counter**: Clears internal state

**Layman's Terms**: Stops recording and saves the audio file, then stops the metronome from clicking.

**Result**: We now have a complete 60-second WAV file containing the user's performance with the metronome clicks in the background.

---

### Phase 3: Audio Analysis (Rhythm Detection)

#### Step 3.1: Initiate Processing
**File**: `ai_rhythm_coach/lib/controllers/practice_controller.dart:70`

```dart
await _processSession(audioFilePath);
```

**Implementation**: `ai_rhythm_coach/lib/controllers/practice_controller.dart:77-79`

```dart
Future<void> _processSession(String audioFilePath) async {
  _setState(PracticeState.processing);

  final tapEvents = await _rhythmAnalyzer.analyzeAudio(
    audioFilePath: audioFilePath,
    bpm: _bpm,
    durationSeconds: 60,
  );
```

**What Happens**:
1. **State Change**: `recording` → `processing`
2. **UI Update**: Screen shows "Processing..."
3. **Call Analyzer**: Passes audio file to `RhythmAnalyzer`

**Layman's Terms**: App switches to analysis mode and starts examining the recording to figure out when you hit each beat.

---

#### Step 3.2: Load Audio File
**File**: `ai_rhythm_coach/lib/services/rhythm_analyzer.dart:13-40`

```dart
Future<List<TapEvent>> analyzeAudio({
  required String audioFilePath,
  required int bpm,
  required int durationSeconds,
}) async {
  final samples = await _loadAudioSamples(audioFilePath);
  final onsetTimes = _detectOnsets(samples);
  final expectedBeats = _generateExpectedBeats(bpm, durationSeconds);
  final tapEvents = _matchOnsetsToBeats(onsetTimes, expectedBeats);
  return tapEvents;
}
```

**Load Samples Implementation**: `ai_rhythm_coach/lib/services/rhythm_analyzer.dart:45-76`

```dart
Future<List<double>> _loadAudioSamples(String filePath) async {
  final file = File(filePath);
  final bytes = await file.readAsBytes();

  final samples = <double>[];
  final startIndex = min(1024, bytes.length); // Skip WAV header

  for (int i = startIndex; i < bytes.length - 1; i += 2) {
    final sample = (bytes[i] | (bytes[i + 1] << 8));
    final signed = sample > 32767 ? sample - 65536 : sample;
    final normalized = signed / 32768.0;
    samples.add(normalized);
  }

  return samples;
}
```

**What Happens**:
1. **Read File**: Loads entire WAV file into memory as bytes
2. **Skip Header**: First ~1024 bytes are WAV header metadata
3. **Parse Audio Data**:
   - Read 2 bytes at a time (16-bit samples)
   - Combine bytes: `byte1 | (byte2 << 8)` → 16-bit unsigned integer
   - Convert to signed: values > 32767 are negative (two's complement)
   - Normalize: Divide by 32768 to get range [-1.0, 1.0]
4. **Return Samples**: List of ~2.6 million samples (44,100 samples/sec × 60 sec)

**Layman's Terms**: Reads the audio file and converts it into a list of numbers representing the sound wave's amplitude (loudness) at each moment in time. It's like converting a recording into a graph of how loud the sound was at each millisecond.

**Technical Details**:
- **16-bit PCM**: Each sample is 2 bytes
- **Little-endian**: Low byte first, high byte second
- **Normalization**: Standard practice in audio processing (makes math easier)
- **Sample Count**: 44,100 Hz × 60 sec = 2,646,000 samples

---

#### Step 3.3: Onset Detection (FFT Analysis)
**File**: `ai_rhythm_coach/lib/services/rhythm_analyzer.dart:78-132`

This is the most complex part. Let me break it down:

**Constants**:
```dart
static const int fftSize = 2048;      // FFT window size
static const int hopSize = 512;       // Step size between windows
static const double sampleRate = 44100;
static const double onsetThreshold = 0.1;
```

**Main Onset Detection Loop**:
```dart
List<double> _detectOnsets(List<double> samples) {
  final onsets = <double>[];
  final fft = FFT(fftSize);
  List<double>? previousMagnitudes;

  // Sliding window FFT
  for (int i = 0; i < samples.length - fftSize; i += hopSize) {
    final window = samples.sublist(i, i + fftSize);
    final windowedSamples = _applyHanningWindow(window);
    final complexSpectrum = fft.realFft(windowedSamples);

    // Calculate magnitudes
    final magnitudes = <double>[];
    for (int j = 0; j < complexSpectrum.length; j++) {
      final real = complexSpectrum[j].x;
      final imag = complexSpectrum[j].y;
      magnitudes.add(sqrt(real * real + imag * imag));
    }

    // Calculate spectral flux
    if (previousMagnitudes != null) {
      double flux = 0.0;
      for (int j = 0; j < magnitudes.length; j++) {
        final diff = magnitudes[j] - previousMagnitudes[j];
        if (diff > 0) flux += diff;
      }

      // Detect onset if flux exceeds threshold
      if (flux > onsetThreshold) {
        final timeInSeconds = i / sampleRate;
        if (onsets.isEmpty || (timeInSeconds - onsets.last) > 0.05) {
          onsets.add(timeInSeconds);
        }
      }
    }

    previousMagnitudes = magnitudes;
  }

  return onsets;
}
```

**What Happens - Step by Step**:

1. **Sliding Window Setup**:
   - **Window Size**: 2048 samples (~46ms at 44.1 kHz)
   - **Hop Size**: 512 samples (~12ms step)
   - **Total Windows**: ~5,168 windows for 60-second file
   - Process: Analyze samples [0-2047], then [512-2559], then [1024-3071], etc.

2. **For Each Window**:

   a. **Apply Hanning Window** (`ai_rhythm_coach/lib/services/rhythm_analyzer.dart:135-145`)
   ```dart
   List<double> _applyHanningWindow(List<double> samples) {
     for (int i = 0; i < n; i++) {
       final window = 0.5 * (1 - cos(2 * pi * i / (n - 1)));
       windowed.add(samples[i] * window);
     }
   }
   ```
   - **Purpose**: Reduces spectral leakage (artifacts at window edges)
   - **Effect**: Smoothly fades samples to zero at window edges
   - **Formula**: Bell-shaped curve that's 0 at edges, 1 in middle

   b. **Perform FFT**:
   ```dart
   final complexSpectrum = fft.realFft(windowedSamples);
   ```
   - **Input**: 2048 real numbers (time domain)
   - **Output**: 1025 complex numbers (frequency domain)
   - **What it Does**: Converts time-domain audio into frequency components
   - **Result**: Shows which frequencies are present and their strengths

   c. **Calculate Magnitudes**:
   ```dart
   magnitudes.add(sqrt(real * real + imag * imag));
   ```
   - **Complex Number**: real + imaginary parts
   - **Magnitude**: Distance from origin = √(real² + imag²)
   - **Represents**: Energy/strength at each frequency
   - **Result**: 1025 magnitude values (one per frequency bin)

   d. **Calculate Spectral Flux**:
   ```dart
   double flux = 0.0;
   for (int j = 0; j < magnitudes.length; j++) {
     final diff = magnitudes[j] - previousMagnitudes[j];
     if (diff > 0) flux += diff;
   }
   ```
   - **Spectral Flux**: Measure of how much the frequency content changed
   - **Only Positive Diffs**: We only care about increases in energy (new sounds)
   - **Sum**: Total increase across all frequencies
   - **High Flux**: Indicates a new sound started (onset/attack)

   e. **Onset Detection**:
   ```dart
   if (flux > onsetThreshold) {
     final timeInSeconds = i / sampleRate;
     if (onsets.isEmpty || (timeInSeconds - onsets.last) > 0.05) {
       onsets.add(timeInSeconds);
     }
   }
   ```
   - **Threshold Check**: Flux > 0.1 indicates likely onset
   - **Calculate Time**: Convert sample index to seconds
   - **Debouncing**: Ignore onsets < 50ms apart (prevents duplicates)
   - **Record Onset**: Add timestamp to list

3. **Result**: List of onset times in seconds
   - Example: `[0.123, 0.623, 1.098, 1.623, ...]`
   - Each number is when a beat was detected

**Layman's Terms**:

The app analyzes the recording in tiny 46-millisecond chunks, shifting forward by 12 milliseconds each time. For each chunk, it:
1. Converts the sound wave into its frequency components (like a prism splitting light into colors)
2. Measures how much each frequency changed compared to the previous chunk
3. When there's a big increase in energy (like when you hit a drum), it marks that moment as a "detected beat"
4. Records the exact time that beat occurred

**Why This Works**: When you hit a drum or tap, there's a sudden burst of sound energy across many frequencies. This shows up as a spike in "spectral flux" (the change in frequency content). By detecting these spikes, we can find when beats occurred.

**Technical Deep Dive**:
- **FFT (Fast Fourier Transform)**: Converts time-domain signal to frequency domain in O(n log n) time
- **2048 Samples @ 44.1kHz**:
  - Time resolution: ~46ms (good for rhythm)
  - Frequency resolution: 44100/2048 = 21.5 Hz per bin
  - Frequency range: 0 Hz to 22,050 Hz (Nyquist)
- **Hop Size 512**: 75% overlap between windows (improves temporal accuracy)
- **Hanning Window**: Reduces spectral leakage by ~31 dB
- **Spectral Flux**: Standard onset detection algorithm in Music Information Retrieval (MIR)

---

#### Step 3.4: Generate Expected Beat Times
**File**: `ai_rhythm_coach/lib/services/rhythm_analyzer.dart:148-157`

```dart
List<double> _generateExpectedBeats(int bpm, int durationSeconds) {
  final beats = <double>[];
  final beatInterval = 60.0 / bpm; // Seconds per beat

  for (double time = 0; time < durationSeconds; time += beatInterval) {
    beats.add(time);
  }

  return beats;
}
```

**What Happens**:
1. **Calculate Beat Interval**: 60 seconds / BPM
   - Example (120 BPM): 60 / 120 = 0.5 seconds per beat
   - Example (80 BPM): 60 / 80 = 0.75 seconds per beat
2. **Generate Timeline**: Start at 0, increment by interval
3. **Result**: List of when beats *should* occur

**Example Output (120 BPM, 5 seconds)**:
```
[0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5]
```

**Layman's Terms**: Creates a list of the exact times when each metronome beat happened. If you set 120 BPM, beats should occur every 0.5 seconds: 0, 0.5, 1.0, 1.5, etc.

---

#### Step 3.5: Match Detected Onsets to Expected Beats
**File**: `ai_rhythm_coach/lib/services/rhythm_analyzer.dart:159-186`

```dart
List<TapEvent> _matchOnsetsToBeats(
  List<double> onsetTimes,
  List<double> expectedBeats,
) {
  final tapEvents = <TapEvent>[];

  for (final expectedTime in expectedBeats) {
    final nearestOnset = _findNearestOnset(
      onsetTimes,
      expectedTime,
      maxDistance: 0.3, // 300ms tolerance
    );

    if (nearestOnset != null) {
      final error = (nearestOnset - expectedTime) * 1000; // Convert to ms

      tapEvents.add(TapEvent(
        actualTime: nearestOnset,
        expectedTime: expectedTime,
        error: error,
      ));
    }
  }

  return tapEvents;
}
```

**Find Nearest Onset Implementation**: `ai_rhythm_coach/lib/services/rhythm_analyzer.dart:188-206`

```dart
double? _findNearestOnset(
  List<double> onsets,
  double targetTime, {
  required double maxDistance,
}) {
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
```

**What Happens**:

1. **For Each Expected Beat**:
   - Search all detected onsets
   - Find the closest onset within ±300ms window
   - If found, create a `TapEvent` with timing error

2. **Calculate Timing Error**:
   - `error = (actual - expected) × 1000` (convert to milliseconds)
   - **Positive error**: User played late (after the metronome)
   - **Negative error**: User played early (before the metronome)
   - **Zero error**: Perfect timing

3. **Example Matching**:
   ```
   Expected beat: 1.000s
   Detected onset: 1.015s
   Error: +15ms (late)

   Expected beat: 2.000s
   Detected onset: 1.985s
   Error: -15ms (early)
   ```

4. **Tolerance Window**: ±300ms
   - If no onset within this window, beat is considered "missed"
   - Prevents matching to wrong beats

**Layman's Terms**: For each metronome beat, finds the closest drum hit in the recording (within a 300ms window). Calculates how early or late each hit was in milliseconds. If you hit exactly on the beat, error is 0. If you hit 20ms late, error is +20. If you hit 15ms early, error is -15.

**Result**: List of `TapEvent` objects, one for each successfully matched beat.

---

#### Step 3.6: Calculate Performance Metrics
**File**: `ai_rhythm_coach/lib/controllers/practice_controller.dart:94-96`

```dart
final averageError = RhythmAnalyzer.calculateAverageError(tapEvents);
final consistency = RhythmAnalyzer.calculateConsistency(tapEvents);
```

**Average Error Implementation**: `ai_rhythm_coach/lib/services/rhythm_analyzer.dart:209-214`

```dart
static double calculateAverageError(List<TapEvent> tapEvents) {
  if (tapEvents.isEmpty) return 0.0;

  final sum = tapEvents.fold<double>(0.0, (sum, event) => sum + event.error.abs());
  return sum / tapEvents.length;
}
```

**Consistency Implementation**: `ai_rhythm_coach/lib/services/rhythm_analyzer.dart:217-230`

```dart
static double calculateConsistency(List<TapEvent> tapEvents) {
  if (tapEvents.isEmpty) return 0.0;

  final errors = tapEvents.map((e) => e.error).toList();
  final mean = errors.reduce((a, b) => a + b) / errors.length;

  final variance = errors.fold<double>(
    0.0,
    (sum, error) => sum + pow(error - mean, 2),
  ) / errors.length;

  return sqrt(variance);
}
```

**What Happens**:

1. **Average Error** (Mean Absolute Error):
   ```
   averageError = (|error1| + |error2| + ... + |errorN|) / N
   ```
   - Takes absolute value of each error (treats +20ms and -20ms the same)
   - Sums all absolute errors
   - Divides by count
   - **Example**: Errors [+10, -5, +15, -8] → (10+5+15+8)/4 = 9.5ms average
   - **Meaning**: On average, how far off were you from the beat?

2. **Consistency** (Standard Deviation):
   ```
   mean = (error1 + error2 + ... + errorN) / N
   variance = ((error1-mean)² + (error2-mean)² + ... + (errorN-mean)²) / N
   consistency = √variance
   ```
   - Calculates mean error (with signs, not absolute)
   - Measures how much errors vary from the mean
   - Square root of variance = standard deviation
   - **Example**: Errors [+10, +12, +9, +11] → Low std dev (consistent, but all late)
   - **Example**: Errors [+50, -40, +30, -60] → High std dev (inconsistent)
   - **Meaning**: How consistent was your timing, regardless of accuracy?

**Layman's Terms**:
- **Average Error**: Tells you how accurate you were on average. Lower is better.
- **Consistency**: Tells you how steady your rhythm was. Low consistency means you're playing with a steady rhythm (even if early/late). High consistency means your timing is erratic and unpredictable.

**Example Scenarios**:
```
Scenario 1: All hits +10ms late
  Average Error: 10ms (not super accurate)
  Consistency: 0ms (perfectly consistent!)

Scenario 2: Hits vary [-20, +15, -30, +25, -10]
  Average Error: 20ms
  Consistency: ~22ms (very inconsistent)

Scenario 3: Professional drummer
  Average Error: 3ms
  Consistency: 2ms (both accurate AND consistent)
```

---

### Phase 4: AI Coaching Generation

#### Step 4.1: Call AI Coaching Service
**File**: `ai_rhythm_coach/lib/controllers/practice_controller.dart:98-104`

```dart
final coachingText = await _aiCoachingService.generateCoaching(
  bpm: _bpm,
  tapEvents: tapEvents,
  averageError: averageError,
  consistency: consistency,
);
```

---

#### Step 4.2: Build AI Prompt
**File**: `ai_rhythm_coach/lib/services/ai_coaching_service.dart:46-82`

```dart
String _buildPrompt({
  required int bpm,
  required List<TapEvent> tapEvents,
  required double averageError,
  required double consistency,
}) {
  final earlyCount = tapEvents.where((t) => t.isEarly).length;
  final lateCount = tapEvents.where((t) => t.isLate).length;
  final onTimeCount = tapEvents.where((t) => t.isOnTime).length;

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
```

**What Happens**:

1. **Calculate Additional Metrics**:
   - **Early Count**: How many hits were < 0ms (before the beat)
   - **Late Count**: How many hits were > 0ms (after the beat)
   - **On-Time Count**: How many hits within ±10ms (essentially perfect)

2. **Sample Timing Errors**: First 10 beats
   - Gives AI concrete examples of timing patterns
   - Example: "-5.2, 3.1, -8.7, 12.4, ..."

3. **Format Prompt**: Structured prompt with:
   - Context (professional rhythm coach)
   - Session statistics
   - Specific instructions for response format
   - Tone guidance (positive, motivational)

**Example Prompt Output**:
```
You are a professional rhythm coach analyzing a drummer's practice session.

Session Details:
- Tempo: 120 BPM
- Total beats detected: 118
- Average timing error: 8.45ms
- Consistency (std dev): 12.30ms
- Early hits: 45
- Late hits: 58
- On-time hits (±10ms): 15

Timing Errors (first 10 beats, in milliseconds):
-5.2, 12.4, -3.1, 18.7, -8.9, 5.6, -12.3, 22.1, -6.7, 9.8

Provide encouraging, actionable coaching feedback (2-3 sentences) focusing on:
1. What they did well
2. Primary area for improvement
3. Specific practice suggestion

Keep the tone positive and motivational.
```

**Layman's Terms**: Creates a detailed summary of your performance and formats it as a question to an AI rhythm coach, asking for personalized feedback.

---

#### Step 4.3: Call AI API (Claude or GPT)
**File**: `ai_rhythm_coach/lib/services/ai_coaching_service.dart:35-39`

```dart
if (AIConfig.provider == AIProvider.anthropic) {
  return await _callClaudeAPI(prompt);
} else {
  return await _callOpenAIAPI(prompt);
}
```

**Claude API Implementation**: `ai_rhythm_coach/lib/services/ai_coaching_service.dart:85-121`

```dart
Future<String> _callClaudeAPI(String prompt) async {
  if (AIConfig.anthropicApiKey == 'YOUR_ANTHROPIC_API_KEY_HERE') {
    return _getMockCoachingResponse();
  }

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
    throw AIServiceException('Claude API error (${response.statusCode}): ${response.body}');
  }
}
```

**What Happens**:

1. **API Key Check**: If not configured, returns mock response
2. **HTTP POST Request**:
   - **Endpoint**: `https://api.anthropic.com/v1/messages`
   - **Headers**:
     - `x-api-key`: Your Anthropic API key
     - `anthropic-version`: API version (required by Claude)
   - **Body**: JSON with model, max tokens, and messages
3. **Model**: `claude-3-5-sonnet-20241022` (configurable)
4. **Max Tokens**: 300 (enough for 2-3 sentences)
5. **Parse Response**: Extracts text from `content[0].text`

**OpenAI API Implementation**: `ai_rhythm_coach/lib/services/ai_coaching_service.dart:124-164`
(Similar structure, different endpoint and format)

**Example API Response from Claude**:
```json
{
  "content": [
    {
      "text": "Nice work maintaining a steady tempo throughout! Your consistency is solid with most hits landing close to the beat. Focus on anticipating the click slightly less - you're rushing by 8-12ms on average. Try subdividing the beat in your mind (counting 1-and-2-and) to lock in more precisely with the metronome."
    }
  ],
  "model": "claude-3-5-sonnet-20241022",
  "usage": {
    "input_tokens": 245,
    "output_tokens": 67
  }
}
```

**Layman's Terms**: Sends your performance data to Claude AI (or ChatGPT) over the internet and receives back personalized coaching advice tailored to your specific mistakes and strengths.

**Cost**:
- Claude: ~$0.003 per coaching session (245 input tokens + 67 output tokens × $3/$15 per million)
- Only charged when generating coaching (no monthly fees)

---

### Phase 5: Save Session

#### Step 5.1: Create Session Object
**File**: `ai_rhythm_coach/lib/controllers/practice_controller.dart:106-117`

```dart
_currentSession = Session(
  id: const Uuid().v4(),
  timestamp: DateTime.now(),
  bpm: _bpm,
  durationSeconds: 60,
  audioFilePath: audioFilePath,
  tapEvents: tapEvents,
  averageError: averageError,
  consistency: consistency,
  coachingText: coachingText,
);
```

**What Happens**:
1. **Generate UUID**: Unique identifier (e.g., `"a3f5b2c4-..."`)
2. **Current Timestamp**: Exact date/time of session
3. **Collect All Data**:
   - BPM setting
   - Audio file path
   - All tap events
   - Calculated metrics
   - AI coaching text

**Example Session Object**:
```dart
Session(
  id: "a3f5b2c4-1e3f-4a5b-8c9d-0e1f2a3b4c5d",
  timestamp: DateTime(2024, 11, 26, 14, 30, 45),
  bpm: 120,
  durationSeconds: 60,
  audioFilePath: "/data/.../recording_1700000000000.wav",
  tapEvents: [...], // List of 118 TapEvent objects
  averageError: 8.45,
  consistency: 12.30,
  coachingText: "Nice work maintaining...",
)
```

---

#### Step 5.2: Persist Session
**File**: `ai_rhythm_coach/lib/controllers/practice_controller.dart:120`

```dart
await _sessionManager.saveSession(_currentSession!);
```

**Implementation**: `ai_rhythm_coach/lib/services/session_manager.dart:15-31`

```dart
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
```

**What Happens**:

1. **Load Existing Sessions**: Reads from SharedPreferences
2. **Add to Front**: New session becomes first in list (chronological order)
3. **Enforce Limit**: Maximum 10 sessions
4. **Delete Old Audio**: If > 10, removes oldest session and deletes its audio file
5. **Serialize to JSON**: Converts all sessions to JSON format
6. **Save to SharedPreferences**: Stores JSON string

**Storage Breakdown**:
- **Metadata (SharedPreferences)**: Session info, metrics, tap events (~5-10 KB per session)
- **Audio File (File System)**: WAV recording (~60 MB per session at 44.1kHz mono 16-bit)

**Example JSON in SharedPreferences**:
```json
[
  {
    "id": "a3f5b2c4-...",
    "timestamp": "2024-11-26T14:30:45.000Z",
    "bpm": 120,
    "durationSeconds": 60,
    "audioFilePath": "/data/.../recording_1700000000000.wav",
    "tapEvents": [
      {"actualTime": 0.123, "expectedTime": 0.0, "error": 123.0},
      {"actualTime": 0.512, "expectedTime": 0.5, "error": 12.0},
      ...
    ],
    "averageError": 8.45,
    "consistency": 12.30,
    "coachingText": "Nice work maintaining..."
  },
  ...more sessions (up to 10 total)
]
```

**Layman's Terms**: Saves all the session data to your phone's storage. It keeps the last 10 practice sessions. If you already have 10 saved, it deletes the oldest one (including its audio file) to make room.

---

#### Step 5.3: Complete Processing
**File**: `ai_rhythm_coach/lib/controllers/practice_controller.dart:122`

```dart
_setState(PracticeState.completed);
```

**What Happens**:
1. **State Change**: `processing` → `completed`
2. **UI Update**: Triggers navigation to results screen

---

### Phase 6: Display Results

#### Step 6.1: Auto-Navigation
**File**: `ai_rhythm_coach/lib/screens/practice_screen.dart:23-32`

```dart
if (controller.state == PracticeState.completed) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ResultsScreen(),
      ),
    ).then((_) => controller.reset());
  });
}
```

**What Happens**:
1. **Detect Completion**: UI widget sees state is `completed`
2. **Post-Frame Callback**: Waits for current frame to finish rendering
3. **Navigate**: Pushes `ResultsScreen` onto navigation stack
4. **Reset on Return**: When user goes back, calls `controller.reset()`

**Layman's Terms**: As soon as processing finishes, automatically navigates you to the results page. When you go back to the practice screen, it resets everything for the next session.

---

#### Step 6.2: Results Screen Display
**File**: `ai_rhythm_coach/lib/screens/results_screen.dart`

The results screen shows:
1. **Statistics Cards**:
   - Average Error (ms)
   - Consistency (ms)
   - Tempo (BPM)
2. **Timing Breakdown**:
   - Early hits count
   - On-time hits count
   - Late hits count
3. **AI Coaching Feedback**: Personalized coaching text
4. **Practice Again Button**: Returns to practice screen

**Data Source**: Reads from `controller.currentSession`

**Layman's Terms**: Shows you detailed statistics about your performance, breaks down how many hits were early/late/on-time, and displays the AI coach's personalized feedback and advice.

---

## State Machine Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      PRACTICE FLOW                          │
└─────────────────────────────────────────────────────────────┘

    ┌──────────┐
    │   IDLE   │  ← Initial state, ready to start
    └────┬─────┘
         │
         │ User presses "Start Practice"
         │ controller.startSession()
         ▼
    ┌──────────┐
    │ COUNT_IN │  ← Playing 4-beat count-in
    └────┬─────┘    Duration: ~2-6 seconds (depends on BPM)
         │
         │ Count-in complete
         │ Start recording + metronome
         ▼
    ┌──────────┐
    │RECORDING │  ← Recording user + playing metronome
    └────┬─────┘    Duration: 60 seconds
         │
         │ 60 seconds elapsed
         │ Stop recording + metronome
         ▼
    ┌──────────┐
    │PROCESSING│  ← Analyzing audio + generating coaching
    └────┬─────┘    Duration: ~5-10 seconds
         │
         │ Analysis complete + session saved
         ▼
    ┌──────────┐
    │COMPLETED │  ← Results ready, navigate to results
    └────┬─────┘
         │
         │ User views results and goes back
         │ controller.reset()
         ▼
    ┌──────────┐
    │   IDLE   │  ← Ready for next session
    └──────────┘


    ERROR HANDLING:

    Any State ──Error──► ┌───────┐
                          │ ERROR │  ← Display error message
                          └───┬───┘
                              │
                              │ User presses "Start Practice" again
                              │ controller.startSession()
                              ▼
                          ┌──────────┐
                          │   IDLE   │
                          └──────────┘
```

---

## Code Execution Path

### Complete Call Stack (Start to Finish)

```
1. User Interaction
   └─ PracticeActionButton.onPressed()
      └─ ai_rhythm_coach/lib/widgets/practice_action_button.dart:16

2. Start Session
   └─ PracticeController.startSession()
      ├─ ai_rhythm_coach/lib/controllers/practice_controller.dart:41
      │
      ├─ _setState(PracticeState.countIn)
      │  └─ ai_rhythm_coach/lib/controllers/practice_controller.dart:43
      │
      ├─ AudioService.initialize()
      │  ├─ ai_rhythm_coach/lib/services/audio_service.dart:27
      │  ├─ Permission.microphone.request()
      │  ├─ FlutterSoundRecorder.openRecorder()
      │  ├─ FlutterSoundPlayer.openPlayer()
      │  └─ _loadAssetToLocalFile() × 2
      │
      ├─ AudioService.playCountIn(bpm)
      │  ├─ ai_rhythm_coach/lib/services/audio_service.dart:87
      │  └─ Loop 4 times:
      │     ├─ FlutterSoundPlayer.startPlayer()
      │     └─ Future.delayed(interval)
      │
      ├─ _setState(PracticeState.recording)
      │  └─ ai_rhythm_coach/lib/controllers/practice_controller.dart:53
      │
      ├─ AudioService.startRecording()
      │  ├─ ai_rhythm_coach/lib/services/audio_service.dart:110
      │  ├─ getApplicationDocumentsDirectory()
      │  └─ FlutterSoundRecorder.startRecorder()
      │
      ├─ AudioService.startMetronome(bpm)
      │  ├─ ai_rhythm_coach/lib/services/audio_service.dart:147
      │  └─ Timer.periodic() → plays click every interval
      │
      ├─ 60-second countdown loop
      │  ├─ ai_rhythm_coach/lib/controllers/practice_controller.dart:58-63
      │  └─ Future.delayed(1 sec) × 60 with notifyListeners()
      │
      ├─ AudioService.stopRecording()
      │  ├─ ai_rhythm_coach/lib/services/audio_service.dart:130
      │  └─ FlutterSoundRecorder.stopRecorder()
      │
      ├─ AudioService.stopMetronome()
      │  ├─ ai_rhythm_coach/lib/services/audio_service.dart:176
      │  └─ Timer.cancel()
      │
      └─ _processSession(audioFilePath)
         └─ ai_rhythm_coach/lib/controllers/practice_controller.dart:77

3. Process Session
   └─ PracticeController._processSession()
      ├─ ai_rhythm_coach/lib/controllers/practice_controller.dart:77
      │
      ├─ _setState(PracticeState.processing)
      │  └─ ai_rhythm_coach/lib/controllers/practice_controller.dart:79
      │
      ├─ RhythmAnalyzer.analyzeAudio()
      │  ├─ ai_rhythm_coach/lib/services/rhythm_analyzer.dart:13
      │  │
      │  ├─ _loadAudioSamples(audioFilePath)
      │  │  ├─ ai_rhythm_coach/lib/services/rhythm_analyzer.dart:45
      │  │  ├─ File.readAsBytes()
      │  │  └─ Parse bytes → normalized samples
      │  │
      │  ├─ _detectOnsets(samples)
      │  │  ├─ ai_rhythm_coach/lib/services/rhythm_analyzer.dart:79
      │  │  └─ Sliding window loop (~5,168 iterations):
      │  │     ├─ _applyHanningWindow()
      │  │     ├─ FFT.realFft()
      │  │     ├─ Calculate magnitudes
      │  │     ├─ Calculate spectral flux
      │  │     └─ Detect onsets (if flux > threshold)
      │  │
      │  ├─ _generateExpectedBeats(bpm, 60)
      │  │  └─ ai_rhythm_coach/lib/services/rhythm_analyzer.dart:148
      │  │
      │  └─ _matchOnsetsToBeats(onsetTimes, expectedBeats)
      │     ├─ ai_rhythm_coach/lib/services/rhythm_analyzer.dart:160
      │     └─ For each expected beat:
      │        └─ _findNearestOnset() → Create TapEvent
      │
      ├─ RhythmAnalyzer.calculateAverageError(tapEvents)
      │  └─ ai_rhythm_coach/lib/services/rhythm_analyzer.dart:209
      │
      ├─ RhythmAnalyzer.calculateConsistency(tapEvents)
      │  └─ ai_rhythm_coach/lib/services/rhythm_analyzer.dart:217
      │
      ├─ AICoachingService.generateCoaching()
      │  ├─ ai_rhythm_coach/lib/services/ai_coaching_service.dart:19
      │  │
      │  ├─ _buildPrompt()
      │  │  └─ ai_rhythm_coach/lib/services/ai_coaching_service.dart:46
      │  │
      │  └─ _callClaudeAPI(prompt) OR _callOpenAIAPI(prompt)
      │     ├─ ai_rhythm_coach/lib/services/ai_coaching_service.dart:85/124
      │     ├─ http.Client.post()
      │     └─ Parse JSON response
      │
      ├─ Create Session object
      │  ├─ ai_rhythm_coach/lib/controllers/practice_controller.dart:107
      │  └─ Uuid().v4() for ID
      │
      ├─ SessionManager.saveSession(session)
      │  ├─ ai_rhythm_coach/lib/services/session_manager.dart:15
      │  ├─ getSessions()
      │  ├─ sessions.insert(0, session)
      │  ├─ Trim to max 10 (delete oldest audio if needed)
      │  ├─ Session.toJson() for each session
      │  └─ SharedPreferences.setString()
      │
      └─ _setState(PracticeState.completed)
         └─ ai_rhythm_coach/lib/controllers/practice_controller.dart:122

4. Display Results
   └─ PracticeScreen detects completed state
      ├─ ai_rhythm_coach/lib/screens/practice_screen.dart:23
      ├─ Navigator.push(ResultsScreen)
      └─ Display session data from controller.currentSession
```

---

## Data Models & Structures

### TapEvent
**File**: `ai_rhythm_coach/lib/models/tap_event.dart`

```dart
class TapEvent {
  final double actualTime;    // Seconds from start (e.g., 1.523)
  final double expectedTime;  // Seconds from start (e.g., 1.500)
  final double error;         // Milliseconds (e.g., +23.0 = 23ms late)

  bool get isEarly => error < 0;      // Negative error
  bool get isLate => error > 0;       // Positive error
  bool get isOnTime => error.abs() < 10.0;  // ±10ms tolerance
}
```

**Example**:
```dart
TapEvent(
  actualTime: 1.523,     // Beat occurred at 1.523 seconds
  expectedTime: 1.500,   // Should have been at 1.500 seconds
  error: 23.0,          // 23ms late
  // isEarly: false
  // isLate: true
  // isOnTime: false
)
```

### Session
**File**: `ai_rhythm_coach/lib/models/session.dart`

```dart
class Session {
  final String id;                    // UUID (e.g., "a3f5b2c4-...")
  final DateTime timestamp;           // When session occurred
  final int bpm;                      // Tempo (40-200)
  final int durationSeconds;          // Always 60
  final String audioFilePath;         // Full path to WAV file
  final List<TapEvent> tapEvents;     // All matched beats
  final double averageError;          // Mean absolute error (ms)
  final double consistency;           // Std dev of errors (ms)
  final String coachingText;          // AI feedback
}
```

**Example**:
```dart
Session(
  id: "a3f5b2c4-1e3f-4a5b-8c9d-0e1f2a3b4c5d",
  timestamp: DateTime(2024, 11, 26, 14, 30, 45),
  bpm: 120,
  durationSeconds: 60,
  audioFilePath: "/data/user/0/com.example.ai_rhythm_coach/app_flutter/recording_1700000000000.wav",
  tapEvents: [TapEvent(...), TapEvent(...), ...],  // ~120 events
  averageError: 8.45,
  consistency: 12.30,
  coachingText: "Nice work maintaining a steady tempo! Your consistency is solid..."
)
```

### PracticeState Enum
**File**: `ai_rhythm_coach/lib/models/practice_state.dart`

```dart
enum PracticeState {
  idle,        // Ready to start
  countIn,     // Playing 4-beat count-in
  recording,   // Recording + metronome active
  processing,  // Analyzing audio + generating coaching
  completed,   // Results ready
  error,       // Error occurred
}
```

---

## Error Handling

### Custom Exception Types

**AudioRecordingException**:
```dart
class AudioRecordingException implements Exception {
  final String message;
}
```

**Thrown when**:
- Microphone permission denied
- Audio service initialization fails
- Recording start/stop fails
- Playback fails

**AIServiceException**:
```dart
class AIServiceException implements Exception {
  final String message;
}
```

**Thrown when**:
- API key missing/invalid
- Network request fails
- API returns error status code
- JSON parsing fails

### Error Handling Flow

**File**: `ai_rhythm_coach/lib/controllers/practice_controller.dart:71-73, 152-164`

```dart
try {
  // ... session code ...
} catch (e) {
  _handleError(e);
}

void _handleError(dynamic error) {
  _state = PracticeState.error;

  if (error is AudioRecordingException) {
    _errorMessage = error.message;
  } else if (error is AIServiceException) {
    _errorMessage = error.message;
  } else {
    _errorMessage = 'An unexpected error occurred: ${error.toString()}';
  }

  notifyListeners();
}
```

**What Happens on Error**:
1. State changes to `error`
2. Error message is extracted and stored
3. UI is notified and displays error message
4. User can tap "Start Practice" again to retry

**Common Error Messages**:
- `"Microphone permission denied. Please enable it in settings."`
- `"Failed to initialize audio: ..."`
- `"No beats detected. Please tap louder or check microphone."`
- `"Claude API error (401): Invalid API key"`
- `"Failed to generate coaching: Network error"`

---

## File System Operations

### Audio Files

**Location**: App's private documents directory
- **Android Path**: `/data/user/0/com.example.ai_rhythm_coach/app_flutter/`
- **Obtained via**: `getApplicationDocumentsDirectory()` from `path_provider`

**Naming Convention**: `recording_<timestamp>.wav`
- Example: `recording_1700000000000.wav`
- Timestamp: Milliseconds since Unix epoch

**Format**: PCM 16-bit WAV
- **Codec**: Uncompressed PCM
- **Bit Depth**: 16-bit
- **Sample Rate**: 44,100 Hz
- **Channels**: Mono (1 channel)
- **File Size**: ~5.3 MB per minute
- **60-second file**: ~5.3 MB

**Lifecycle**:
1. Created during `AudioService.startRecording()`
2. Written to during 60-second recording
3. Finalized during `AudioService.stopRecording()`
4. Read during `RhythmAnalyzer.analyzeAudio()`
5. Deleted when session is removed (exceeds 10-session limit)

### Click Sound Files

**Location**: App's temporary directory
- **Obtained via**: `getTemporaryDirectory()` from `path_provider`

**Files**:
- `click_high.wav` - 800 Hz tone, 50ms duration (downbeat)
- `click_low.wav` - 400 Hz tone, 50ms duration (other beats)

**Lifecycle**:
1. Copied from assets during `AudioService.initialize()`
2. Reused across all sessions
3. May be cleared by OS when storage is low

### SharedPreferences

**Key**: `"sessions"`
**Value**: JSON-encoded string containing array of up to 10 Session objects

**Example Storage**:
```json
{
  "sessions": "[{\"id\":\"...\",\"timestamp\":\"2024-11-26T14:30:45.000Z\",\"bpm\":120,...}]"
}
```

**Size**: ~5-10 KB per session × 10 = ~50-100 KB total

---

## Performance Characteristics

### Time Breakdown

**Total Duration**: ~75-80 seconds

1. **Count-In**: Variable (depends on BPM)
   - 40 BPM: 6 seconds (1.5s per beat × 4)
   - 120 BPM: 2 seconds (0.5s per beat × 4)
   - 200 BPM: 1.2 seconds (0.3s per beat × 4)

2. **Recording**: 60 seconds (fixed)

3. **Processing**: ~5-10 seconds
   - Load audio: ~0.5s
   - FFT onset detection: ~2-4s
   - AI API call: ~2-5s (network latency)
   - Save session: ~0.1s

### Memory Usage

**Peak Memory**: ~70-80 MB

1. **Audio Sample Array**: ~21 MB
   - 2,646,000 samples × 8 bytes (double) = ~21 MB

2. **FFT Buffers**: ~2 MB
   - Multiple windows and magnitude arrays

3. **Session Data**: <1 MB
   - ~120 TapEvent objects
   - Metadata strings

4. **Flutter Framework**: ~40-50 MB baseline

### CPU Usage

**Intensive Phases**:
1. **FFT Processing**: High CPU (2-4 seconds)
   - ~5,168 FFT operations (2048-point each)
   - Single-threaded (Dart isolate)

2. **API Call**: Network I/O (2-5 seconds)
   - CPU idle during network wait

**Battery Impact**: Low (one-time processing, not continuous)

---

## Summary

When you press "Start Practice", the app:

1. **Prepares** (1-6s): Checks permissions, loads sounds, plays count-in
2. **Records** (60s): Captures your performance with simultaneous metronome
3. **Analyzes** (2-4s): Uses FFT to detect beat timings and calculate accuracy
4. **Coaches** (2-5s): Sends data to AI for personalized feedback
5. **Saves** (<1s): Stores session to device (max 10 sessions)
6. **Displays**: Shows results with statistics and coaching

The entire flow is orchestrated by `PracticeController` using a state machine pattern, with four specialized services handling audio, analysis, AI, and persistence. All data is stored locally on your device, with only coaching requests sent to AI APIs (pay-per-use, no subscription).
