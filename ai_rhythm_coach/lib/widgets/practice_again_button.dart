import 'package:flutter/material.dart';

class PracticeAgainButton extends StatelessWidget {
  const PracticeAgainButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => Navigator.pop(context),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18),
      ),
      child: const Text('Practice Again'),
    );
  }
}
