import 'package:flutter/material.dart';
import '../models/session.dart';

class TimingBreakdown extends StatelessWidget {
  final Session session;

  const TimingBreakdown({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final earlyCount = session.tapEvents.where((t) => t.isEarly).length;
    final lateCount = session.tapEvents.where((t) => t.isLate).length;
    final onTimeCount = session.tapEvents.where((t) => t.isOnTime).length;
    final total = session.tapEvents.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Timing Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildTimingRow('On Time (±10ms)', onTimeCount, total, Colors.green),
          const SizedBox(height: 8),
          _buildTimingRow('Early', earlyCount, total, Colors.orange),
          const SizedBox(height: 8),
          _buildTimingRow('Late', lateCount, total, Colors.red),
        ],
      ),
    );
  }

  Widget _buildTimingRow(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey.shade200,
            color: color,
            minHeight: 8,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          child: Text(
            '${percentage.toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
