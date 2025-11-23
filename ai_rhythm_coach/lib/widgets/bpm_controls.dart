import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/practice_controller.dart';

class BpmControls extends StatelessWidget {
  const BpmControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PracticeController>(
      builder: (context, controller, child) {
        return Column(
          children: [
            const Text(
              'Tempo (BPM)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => controller.setBpm(controller.bpm - 5),
                  icon: const Icon(Icons.remove_circle_outline),
                  iconSize: 40,
                ),
                const SizedBox(width: 20),
                Container(
                  width: 100,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${controller.bpm}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 20),
                IconButton(
                  onPressed: () => controller.setBpm(controller.bpm + 5),
                  icon: const Icon(Icons.add_circle_outline),
                  iconSize: 40,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Range: 40-200 BPM',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        );
      },
    );
  }
}
