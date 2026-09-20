import 'dart:typed_data';

import 'package:gal/gal.dart';

class GalleryPermissionDeniedException implements Exception {
  @override
  String toString() => 'GalleryPermissionDeniedException';
}

abstract class GallerySaverService {
  Future<void> saveGif(Uint8List gifBytes);
}

class GalGallerySaverService implements GallerySaverService {
  const GalGallerySaverService();

  static const _album = 'GifMaker';

  @override
  Future<void> saveGif(Uint8List gifBytes) async {
    final hasAccess = await Gal.hasAccess(toAlbum: true) || await Gal.requestAccess(toAlbum: true);
    if (!hasAccess) {
      throw GalleryPermissionDeniedException();
    }

    await Gal.putImageBytes(
      gifBytes,
      album: _album,
      name: 'gifmaker_${DateTime.now().millisecondsSinceEpoch}.gif',
    );
  }
}
