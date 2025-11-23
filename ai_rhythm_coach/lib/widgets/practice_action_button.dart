import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/practice_controller.dart';
import '../models/practice_state.dart';

class PracticeActionButton extends StatelessWidget {
  const PracticeActionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PracticeController>(
      builder: (context, controller, child) {
        if (controller.state == PracticeState.idle ||
            controller.state == PracticeState.error) {
          return ElevatedButton(
            onPressed: () => controller.startSession(),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
              textStyle: const TextStyle(fontSize: 20),
            ),
            child: const Text('Start Practice'),
          );
        } else if (controller.state == PracticeState.recording) {
          return ElevatedButton(
            onPressed: () => controller.stopSession(),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
              textStyle: const TextStyle(fontSize: 20),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Stop'),
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }
}
