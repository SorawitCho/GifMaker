import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_reorderable_grid_view/widgets/reorderable_builder.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/selected_photo.dart';
import '../services/gallery_saver_service.dart';
import '../services/gif_encoder_service.dart';
import '../services/photo_picker_service.dart';
import '../widgets/photo_grid_tile.dart';
import '../widgets/progress_overlay.dart';
import '../widgets/speed_control.dart';
import 'preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.photoPickerService = const WeChatPhotoPickerService(),
    this.gallerySaverService = const GalGallerySaverService(),
  });

  final PhotoPickerService photoPickerService;
  final GallerySaverService gallerySaverService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SelectedPhoto> _selected = [];
  int _frameDelayMs = 200;
  bool _isEncoding = false;

  Future<void> _pickPhotos() async {
    try {
      final assets = await widget.photoPickerService.pickPhotos(
        context,
        previouslySelected: _selected.map((p) => p.asset).toList(),
      );

      final byId = {for (final p in _selected) p.id: p};
      final updated = <SelectedPhoto>[];
      for (final asset in assets) {
        final existing = byId[asset.id];
        if (existing != null) {
          updated.add(existing);
          continue;
        }
        final thumb = await asset.thumbnailDataWithSize(const ThumbnailSize.square(300));
        if (thumb != null) {
          updated.add(SelectedPhoto(asset: asset, thumbBytes: thumb));
        }
      }

      if (!mounted) return;
      setState(() => _selected = updated);
    } on PhotoPermissionDeniedException {
      if (!mounted) return;
      _showAlert(
        title: 'Permission needed',
        message: 'GifMaker needs photo library access so you can pick photos.',
      );
    }
  }

  void _removeAt(int index) {
    setState(() {
      final updated = List<SelectedPhoto>.of(_selected)..removeAt(index);
      _selected = updated;
    });
  }

  Future<void> _createGif() async {
    setState(() => _isEncoding = true);
    try {
      final frameBytes = <Uint8List>[];
      for (final photo in _selected) {
        final bytes = await photo.asset.originBytes;
        if (bytes != null) frameBytes.add(bytes);
      }

      final gifBytes = await compute(
        encodeGifIsolateEntry,
        GifEncodeRequest(frames: frameBytes, frameDelayMs: _frameDelayMs),
      );

      if (!mounted) return;
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => PreviewScreen(
            gifBytes: gifBytes,
            gallerySaverService: widget.gallerySaverService,
          ),
        ),
      );
    } on GifEncodeException catch (e) {
      if (!mounted) return;
      _showAlert(title: "Couldn't create GIF", message: e.message);
    } catch (_) {
      if (!mounted) return;
      _showAlert(
        title: "Couldn't create GIF",
        message: 'Something went wrong while creating the GIF. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isEncoding = false);
    }
  }

  void _showAlert({required String title, required String message}) {
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = _selected.length >= 2 && !_isEncoding;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('GifMaker'),
        trailing: GestureDetector(
          onTap: _isEncoding ? null : _pickPhotos,
          child: const Icon(CupertinoIcons.add_circled_solid),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _selected.isEmpty ? _buildEmptyState() : _buildGrid(),
                ),
                SpeedControl(
                  frameDelayMs: _frameDelayMs,
                  onChanged: (value) => setState(() => _frameDelayMs = value),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: canCreate ? _createGif : null,
                      child: const Text('Create GIF'),
                    ),
                  ),
                ),
              ],
            ),
            if (_isEncoding) const ProgressOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.photo_on_rectangle,
            size: 56,
            color: CupertinoColors.systemGrey,
          ),
          const SizedBox(height: 16),
          const Text('No photos selected', style: TextStyle(fontSize: 17)),
          const SizedBox(height: 4),
          const Text(
            'Choose at least 2 photos to build a GIF',
            style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
          ),
          const SizedBox(height: 20),
          CupertinoButton.filled(onPressed: _pickPhotos, child: const Text('Choose Photos')),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return ReorderableBuilder<SelectedPhoto>(
      onReorder: (reorderedListFunction) {
        setState(() => _selected = reorderedListFunction(_selected));
      },
      children: [
        for (var i = 0; i < _selected.length; i++)
          PhotoGridTile(
            key: ValueKey(_selected[i].id),
            photo: _selected[i],
            index: i,
            onRemove: () => _removeAt(i),
          ),
      ],
      builder: (children) {
        return GridView.count(
          padding: const EdgeInsets.all(12),
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: children,
        );
      },
    );
  }
}
