import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

/// A photo the user has picked, paired with a cached thumbnail for display.
///
/// Order is never stored on this model — the position of a [SelectedPhoto]
/// inside its containing list IS its sequence position in the final GIF.
class SelectedPhoto {
  SelectedPhoto({required this.asset, required this.thumbBytes});

  final AssetEntity asset;
  final Uint8List thumbBytes;

  String get id => asset.id;
}
