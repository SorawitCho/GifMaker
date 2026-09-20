import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import '../services/gallery_saver_service.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({
    super.key,
    required this.gifBytes,
    required this.gallerySaverService,
  });

  final Uint8List gifBytes;
  final GallerySaverService gallerySaverService;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool _isSaving = false;
  bool _savedSuccessfully = false;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.gallerySaverService.saveGif(widget.gifBytes);
      if (!mounted) return;
      setState(() => _savedSuccessfully = true);
      await showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Saved!'),
          content: const Text('Your GIF has been saved to Photos.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } on GalleryPermissionDeniedException {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Permission needed'),
          content: const Text(
            'GifMaker needs permission to save photos. You can enable this in Settings.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Couldn\'t save'),
          content: const Text('Something went wrong while saving the GIF. Please try again.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Preview')),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(widget.gifBytes, gaplessPlayback: true),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                      : Text(_savedSuccessfully ? 'Saved ✓' : 'Save to Photos'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
