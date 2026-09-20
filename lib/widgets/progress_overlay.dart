import 'package:flutter/cupertino.dart';

/// Blocking overlay shown while the GIF is being encoded off the UI thread.
class ProgressOverlay extends StatelessWidget {
  const ProgressOverlay({super.key, this.message = 'Creating your GIF…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CupertinoColors.black.withValues(alpha: 0.4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(radius: 14),
              const SizedBox(height: 12),
              Text(message, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
