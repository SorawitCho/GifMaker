import 'package:flutter/widgets.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class PhotoPermissionDeniedException implements Exception {
  @override
  String toString() => 'PhotoPermissionDeniedException';
}

/// Wraps the photo library picker. The picker UI itself shows a numbered
/// badge on each photo as the user taps it, and returns the assets in that
/// same tap order — this is what lets the rest of the app know and display
/// the eventual GIF's frame sequence.
abstract class PhotoPickerService {
  Future<List<AssetEntity>> pickPhotos(
    BuildContext context, {
    List<AssetEntity> previouslySelected,
  });
}

class WeChatPhotoPickerService implements PhotoPickerService {
  const WeChatPhotoPickerService();

  @override
  Future<List<AssetEntity>> pickPhotos(
    BuildContext context, {
    List<AssetEntity> previouslySelected = const [],
  }) async {
    try {
      final result = await AssetPicker.pickAssets(
        context,
        pickerConfig: AssetPickerConfig(
          requestType: RequestType.image,
          selectedAssets: previouslySelected,
          maxAssets: 40,
        ),
      );
      return result ?? previouslySelected;
    } on StateError {
      // Thrown internally by the picker when the photo-library permission
      // is not authorized/limited.
      throw PhotoPermissionDeniedException();
    }
  }
}
