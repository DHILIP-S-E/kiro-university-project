import 'dart:io';
import 'package:image_picker/image_picker.dart';

/// Wraps image_picker for camera and gallery access.
/// All capture actions return a [File] or null if the user cancelled.
class CameraService {
  static final ImagePicker _picker = ImagePicker();

  /// Open the device camera and take a photo.
  static Future<File?> capturePhoto() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1080,
    );
    if (xfile == null) return null;
    return File(xfile.path);
  }

  /// Open the gallery and pick a single photo.
  static Future<File?> pickFromGallery() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xfile == null) return null;
    return File(xfile.path);
  }

  /// Pick multiple photos from the gallery at once.
  static Future<List<File>> pickMultipleFromGallery() async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    return files.map((f) => File(f.path)).toList();
  }

  /// Pick a video from the gallery (future use).
  static Future<File?> pickVideo() async {
    final xfile = await _picker.pickVideo(source: ImageSource.gallery);
    if (xfile == null) return null;
    return File(xfile.path);
  }
}
