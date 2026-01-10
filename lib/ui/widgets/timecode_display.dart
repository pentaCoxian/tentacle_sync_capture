import 'package:flutter/material.dart';

class TimecodeDisplay extends StatelessWidget {
  final String timecode;
  final int confidence;
  final bool isConfirmed;

  const TimecodeDisplay({
    super.key,
    required this.timecode,
    this.confidence = 0,
    this.isConfirmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final confidenceColor = isConfirmed
        ? Colors.green
        : confidence >= 70
            ? Colors.green
            : confidence >= 50
                ? Colors.orange
                : Colors.red;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isConfirmed
                  ? Colors.green.withAlpha(100)
                  : Theme.of(context).colorScheme.outline.withAlpha(50),
              width: 2,
            ),
          ),
          child: Text(
            timecode,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  fontSize: 48,
                ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: confidenceColor.withAlpha(50),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isConfirmed ? Icons.verified : Icons.analytics,
                    size: 16,
                    color: confidenceColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isConfirmed ? 'Confirmed' : 'Confidence: $confidence%',
                    style: TextStyle(
                      color: confidenceColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
