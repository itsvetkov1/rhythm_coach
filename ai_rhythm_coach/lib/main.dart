import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'controllers/practice_controller.dart';
import 'services/audio_service.dart';
import 'services/rhythm_analyzer.dart';
import 'services/ai_coaching_service.dart';

import 'services/session_manager.dart';
import 'services/calibration_service.dart';
import 'screens/practice_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  const MyApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Service Providers
        Provider<AudioService>(
          create: (_) => AudioService(),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<RhythmAnalyzer>(
          create: (_) => RhythmAnalyzer(),
        ),
        Provider<AICoachingService>(
          create: (_) => AICoachingService(http.Client()),
        ),
        Provider<SessionManager>(
          create: (_) => SessionManager(prefs),
        ),
        Provider<CalibrationService>(
          create: (_) => CalibrationService(),
          dispose: (_, service) => service.dispose(),
        ),

        // Controller Provider
        ChangeNotifierProvider<PracticeController>(
          create: (context) => PracticeController(
            audioService: context.read<AudioService>(),
            rhythmAnalyzer: context.read<RhythmAnalyzer>(),
            aiCoachingService: context.read<AICoachingService>(),
            aiCoachingService: context.read<AICoachingService>(),
            sessionManager: context.read<SessionManager>(),
            calibrationService: context.read<CalibrationService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'AI Rhythm Coach',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const PracticeScreen(),
      ),
    );
  }
}
