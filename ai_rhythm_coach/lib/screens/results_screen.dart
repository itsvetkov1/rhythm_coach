import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/practice_controller.dart';
import '../widgets/stat_card.dart';
import '../widgets/timing_breakdown.dart';
import '../widgets/coaching_feedback.dart';
import '../widgets/practice_again_button.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PracticeController>();
    final session = controller.currentSession;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Results'),
        ),
        body: const Center(
          child: Text('No session data available'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Results'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Practice Complete!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tempo: ${session.bpm} BPM',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Duration: ${session.durationSeconds}s${session.durationSeconds < 60 ? ' (stopped early)' : ''}',
              style: TextStyle(
                fontSize: 16,
                color: session.durationSeconds < 60
                    ? Colors.orange
                    : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Statistics Cards
            StatCard(
              label: 'Average Error',
              value: '${session.averageError.toStringAsFixed(1)} ms',
              icon: _getErrorIcon(session.averageError),
              color: _getErrorColor(session.averageError),
            ),
            const SizedBox(height: 16),
            StatCard(
              label: 'Consistency',
              value: '${session.consistency.toStringAsFixed(1)} ms',
              icon: _getConsistencyIcon(session.consistency),
              color: _getConsistencyColor(session.consistency),
            ),
            const SizedBox(height: 16),
            StatCard(
              label: 'Beats Detected',
              value: '${session.tapEvents.length}',
              icon: Icons.music_note,
              color: Colors.blue,
            ),

            const SizedBox(height: 32),

            // Timing Breakdown
            TimingBreakdown(session: session),

            const SizedBox(height: 32),

            // AI Coaching Feedback
            CoachingFeedback(coachingText: session.coachingText),

            const SizedBox(height: 32),

            // Action Button
            const PracticeAgainButton(),
          ],
        ),
      ),
    );
  }

  IconData _getErrorIcon(double averageError) {
    if (averageError < 20) return Icons.star;
    if (averageError < 50) return Icons.thumb_up;
    return Icons.trending_up;
  }

  Color _getErrorColor(double averageError) {
    if (averageError < 20) return Colors.green;
    if (averageError < 50) return Colors.orange;
    return Colors.red;
  }

  IconData _getConsistencyIcon(double consistency) {
    if (consistency < 20) return Icons.star;
    if (consistency < 50) return Icons.thumb_up;
    return Icons.trending_up;
  }

  Color _getConsistencyColor(double consistency) {
    if (consistency < 20) return Colors.green;
    if (consistency < 50) return Colors.orange;
    return Colors.red;
  }
}
