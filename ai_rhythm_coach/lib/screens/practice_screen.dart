import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/practice_controller.dart';
import '../models/practice_state.dart';
import 'results_screen.dart';
import '../widgets/practice_state_ui.dart';
import '../widgets/bpm_controls.dart';
import '../widgets/practice_action_button.dart';
import '../widgets/headphones_warning_dialog.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  bool _hasShownHeadphonesWarning = false;

  @override
  void initState() {
    super.initState();
    // Show headphones warning dialog after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showHeadphonesWarning();
    });
  }

  Future<void> _showHeadphonesWarning() async {
    if (!_hasShownHeadphonesWarning && mounted) {
      _hasShownHeadphonesWarning = true;
      await HeadphonesWarningDialog.show(context);
    }
  }

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
