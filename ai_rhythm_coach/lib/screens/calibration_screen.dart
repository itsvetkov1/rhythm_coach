import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/calibration_service.dart';
import '../services/rhythm_analyzer.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  bool _isCalibrating = false;
  int? _latencyResult;
  String _statusMessage = 'This tool measures audio latency to ensure accuracy.\n\nTap "Start", listen to the beat, and tap along exactly when you hear the click.';
  int _currentStep = 0; // 0: Idle, 1: Calibrating, 2: Finished, 3: Error

  @override
  void initState() {
    super.initState();
    _loadCurrentLatency();
  }

  Future<void> _loadCurrentLatency() async {
    final service = context.read<CalibrationService>();
    final latency = await service.getLatency();
    if (mounted) {
      setState(() {
        _latencyResult = latency;
      });
    }
  }

  Future<void> _startCalibration() async {
    setState(() {
      _isCalibrating = true;
      _currentStep = 1;
      _statusMessage = 'Get ready...';
    });

    try {
      final calibrationService = context.read<CalibrationService>();
      final rhythmAnalyzer = context.read<RhythmAnalyzer>();
      
      // initialize
      await calibrationService.initialize();
      
      setState(() {
        _statusMessage = 'Tap with the beat!';
      });
      
      final recordingPath = await calibrationService.startCalibration();
      
      // Wait for the calibration duration
      final durationMs = (60000 / calibrationService.calibrationBpm * calibrationService.calibrationBeats).round() + 500;
      
      await Future.delayed(Duration(milliseconds: durationMs));
      
      if (!mounted || !_isCalibrating) return;

      final actualPath = await calibrationService.stopCalibration();

      setState(() {
        _statusMessage = 'Analyzing...';
      });

      // Analyze
      final tapEvents = await rhythmAnalyzer.analyzeAudio(
        audioFilePath: actualPath,
        bpm: calibrationService.calibrationBpm,
        durationSeconds: (durationMs / 1000).ceil(),
        latencyOffsetMs: 0, // We want raw offset
      );
      
      if (tapEvents.isEmpty) {
        throw Exception('No taps detected. Please tap louder or check microphone.');
      }
      
      // We ignore the first few taps (count-in)
      // The analyzed beats match expected beats. 
      // If we tapped perfectly to what we heard, the error is the latency.
      
      final meanError = RhythmAnalyzer.calculateMeanSignedError(tapEvents);
      final latency = meanError.round();
      
      // Sanity check
      if (latency < 0) {
        // Negative latency means we tapped BEFORE the expected time (anticipation)
        // or the system reported time weirdly.
        // Usually latency is positive.
        // However, aggressive anticipation can cause negative results.
        // We'll record it as is, but maybe warn?
      }

      await calibrationService.saveLatency(latency);

      if (mounted) {
        setState(() {
          _latencyResult = latency;
          _isCalibrating = false;
          _currentStep = 2;
          _statusMessage = 'Calibration complete!\nLatency: ${latency}ms\n\nThis value has been saved.';
        });
      }
      
      // Cleanup file
      try {
        await File(actualPath).delete();
      } catch (e) {
        print('Error cleaning up calibration file: $e');
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isCalibrating = false;
          _currentStep = 3;
          _statusMessage = 'Error: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    // Ensure we stop if user leaves mid-calibration
    if (_isCalibrating) {
      // We can't await here, so we fire and forget or use a detached cleaner
      // Ideally CalibrationService.dispose() handles it
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Calibration'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _currentStep == 2 ? Icons.check_circle_outline : Icons.tune,
                size: 80,
                color: _currentStep == 2 
                    ? Colors.green 
                    : (_currentStep == 3 ? Colors.red : Theme.of(context).primaryColor),
              ),
              const SizedBox(height: 32),
              
              if (_latencyResult != null && _currentStep != 2)
                Text(
                  'Current Latency: ${_latencyResult}ms',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                
              const SizedBox(height: 24),
              
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              
              const SizedBox(height: 48),
              
              if (_currentStep == 1)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _startCalibration,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(_currentStep == 0 ? 'Start Calibration' : 'Recalibrate'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                    if (_currentStep == 2 || _currentStep == 3) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Back'),
                      ),
                    ]
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
