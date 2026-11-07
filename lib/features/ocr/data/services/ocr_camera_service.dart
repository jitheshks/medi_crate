import 'dart:io';
import 'package:image_picker/image_picker.dart';

/// Camera and file picker abstraction for prescription document scanning.
class OcrCameraService {
  final ImagePicker _picker;

  OcrCameraService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  /// Captures an image using device camera and returns temporary path.
  Future<String?> captureFromCamera() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      return file?.path;
    } catch (_) {
      return null;
    }
  }

  /// Picks an existing document image from photo gallery.
  Future<String?> pickFromGallery() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      return file?.path;
    } catch (_) {
      return null;
    }
  }

  /// Safely deletes a temporary image file if it exists.
  Future<void> deleteTemporaryImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
