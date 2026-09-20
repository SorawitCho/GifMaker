import 'package:flutter/cupertino.dart';

import '../models/selected_photo.dart';

/// A single thumbnail in the selection grid: the photo itself, a numbered
/// badge showing its position in the GIF sequence, and a remove control.
class PhotoGridTile extends StatelessWidget {
  const PhotoGridTile({
    super.key,
    required this.photo,
    required this.index,
    required this.onRemove,
  });

  final SelectedPhoto photo;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(photo.thumbBytes, fit: BoxFit.cover),
          Positioned(top: 6, left: 6, child: _SequenceBadge(number: index + 1)),
          Positioned(top: 4, right: 4, child: _RemoveButton(onTap: onRemove)),
        ],
      ),
    );
  }
}

class _SequenceBadge extends StatelessWidget {
  const _SequenceBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CupertinoColors.activeBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: CupertinoColors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          CupertinoIcons.xmark,
          size: 14,
          color: CupertinoColors.white,
        ),
      ),
    );
  }
}
