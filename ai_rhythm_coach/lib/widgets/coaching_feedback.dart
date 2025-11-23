import 'package:flutter/material.dart';

class CoachingFeedback extends StatelessWidget {
  final String coachingText;

  const CoachingFeedback({super.key, required this.coachingText});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.blue.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Coach\'s Feedback',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            coachingText,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
