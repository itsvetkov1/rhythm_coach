import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/practice_controller.dart';
import '../models/practice_state.dart';
import 'results_screen.dart';
import '../widgets/practice_state_ui.dart';
import '../widgets/bpm_controls.dart';
import '../widgets/practice_action_button.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Rhythm Coach'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<PracticeController>(
        builder: (context, controller, child) {
          // Navigate to results screen when completed
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

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // State-dependent UI
                  const PracticeStateUI(),

                  const SizedBox(height: 40),

                  // BPM Controls (only show when idle)
                  if (controller.state == PracticeState.idle)
                    const BpmControls(),

                  const SizedBox(height: 40),

                  // Action Button
                  const PracticeActionButton(),

                  // Error Message
                  if (controller.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        controller.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
