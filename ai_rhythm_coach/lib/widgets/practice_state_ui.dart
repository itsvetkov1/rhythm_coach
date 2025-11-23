import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/practice_controller.dart';
import '../models/practice_state.dart';

class PracticeStateUI extends StatelessWidget {
  const PracticeStateUI({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PracticeController>(
      builder: (context, controller, child) {
        switch (controller.state) {
          case PracticeState.idle:
            return Column(
              children: [
                Icon(
                  Icons.music_note,
                  size: 100,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Ready to Practice',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Set your tempo and tap Start when ready',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            );

          case PracticeState.countIn:
            return Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text(
                  'Count-in...',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Get ready! Starting in 4 beats',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            );

          case PracticeState.recording:
            return Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: controller.recordingTimeRemaining / 60,
                        strokeWidth: 8,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      '${controller.recordingTimeRemaining}s',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Recording...',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'Playing at ${controller.bpm} BPM',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            );

          case PracticeState.processing:
            return Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text(
                  'Analyzing Performance...',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Generating your coaching feedback',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            );

          case PracticeState.completed:
            return const SizedBox.shrink();

          case PracticeState.error:
            return Column(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 100,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Oops! Something went wrong',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            );
        }
      },
    );
  }
}
