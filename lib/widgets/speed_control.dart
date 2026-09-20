import 'package:flutter/cupertino.dart';

/// Lets the user set the GIF's per-frame delay (its playback speed).
class SpeedControl extends StatelessWidget {
  const SpeedControl({
    super.key,
    required this.frameDelayMs,
    required this.onChanged,
    this.minMs = 50,
    this.maxMs = 1000,
  });

  final int frameDelayMs;
  final ValueChanged<int> onChanged;
  final int minMs;
  final int maxMs;

  @override
  Widget build(BuildContext context) {
    final fps = 1000 / frameDelayMs;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Speed — ${frameDelayMs}ms/frame (~${fps.toStringAsFixed(1)} fps)',
            style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
          ),
          CupertinoSlider(
            value: frameDelayMs.toDouble().clamp(minMs.toDouble(), maxMs.toDouble()),
            min: minMs.toDouble(),
            max: maxMs.toDouble(),
            divisions: (maxMs - minMs) ~/ 10,
            onChanged: (value) => onChanged(value.round()),
          ),
        ],
      ),
    );
  }
}
