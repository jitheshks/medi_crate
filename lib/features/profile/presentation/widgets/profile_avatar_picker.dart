import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/permissions/app_permission_service.dart';
import '../../../../shared/widgets/sheets/app_bottom_sheet.dart';
import '../providers/profile_providers.dart';

class ProfileAvatarPicker extends ConsumerWidget {
  final String? photoPath;
  final String profileId;
  final ValueChanged<String?> onPhotoChanged;
  final ImagePicker? picker;
  final ImageCropper? cropper;

  const ProfileAvatarPicker({
    super.key,
    required this.photoPath,
    required this.profileId,
    required this.onPhotoChanged,
    this.picker,
    this.cropper,
  });

  Future<void> _pickImage(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;

    // 1. Contextually verify permissions before launching picker
    if (source == ImageSource.camera) {
      final hasPermission = await AppPermissionService.requestCameraPermission(
        context,
        featureName: 'take a profile photo',
      );
      if (!hasPermission) return;
    } else if (source == ImageSource.gallery) {
      final hasPermission = await AppPermissionService.requestPhotoPermission(
        context,
        featureName: 'choose a profile photo',
      );
      if (!hasPermission) return;
    }

    try {
      final imgPicker = picker ?? ImagePicker();
      XFile? pickedFile = await imgPicker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile == null && !kIsWeb && Platform.isAndroid) {
        final LostDataResponse response = await imgPicker.retrieveLostData();
        if (!response.isEmpty && response.file != null) {
          pickedFile = response.file;
        }
      }

      if (pickedFile == null) return;

      final imgCropper = cropper ?? ImageCropper();
      final CroppedFile? croppedFile = await imgCropper.cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Photo',
            toolbarColor: colorScheme.primary,
            toolbarWidgetColor: colorScheme.onPrimary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'Crop Profile Photo',
            aspectRatioLockEnabled: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );

      if (croppedFile == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final profileDir = Directory(
        '${appDir.path}/profiles/$profileId/profile',
      );
      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
      }

      final ext = croppedFile.path.split('.').last;
      final targetPath =
          '${profileDir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final savedFile = await File(croppedFile.path).copy(targetPath);

      // Attempt remote upload if profileId is a persisted profile
      if (profileId.isNotEmpty &&
          !profileId.startsWith('prof_primary_') &&
          !profileId.startsWith('temp_')) {
        try {
          final updated = await ref
              .read(profilesListProvider.notifier)
              .uploadPhoto(profileId, savedFile);
          if (updated.photo != null && updated.photo!.isNotEmpty) {
            onPhotoChanged(updated.photo);
            return;
          }
        } catch (_) {
          // Fallback to local image path
        }
      }

      if (photoPath != null &&
          photoPath != savedFile.path &&
          !photoPath!.startsWith('http') &&
          File(photoPath!).existsSync()) {
        try {
          await File(photoPath!).delete();
        } catch (_) {}
      }

      onPhotoChanged(savedFile.path);
    } catch (_) {
      if (context.mounted) {
        context.showSnackBar(
          "We couldn't load this photo. Please check permissions and try again.",
        );
      }
    }
  }

  Future<void> _removePhoto() async {
    if (photoPath != null &&
        !photoPath!.startsWith('http') &&
        File(photoPath!).existsSync()) {
      try {
        await File(photoPath!).delete();
      } catch (_) {}
    }
    onPhotoChanged(null);
  }

  void _showPhotoOptions(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    AppBottomSheet.show(
      context: context,
      builder: (ctx) => AppBottomSheet(
        title: 'Profile Photo',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.camera_alt_outlined,
                color: colorScheme.primary,
              ),
              title: Text(
                'Take Photo',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(context, ref, ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library_outlined,
                color: colorScheme.primary,
              ),
              title: Text(
                'Choose from Gallery',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(context, ref, ImageSource.gallery);
              },
            ),
            if (photoPath != null && photoPath!.isNotEmpty)
              ListTile(
                leading: Icon(Icons.delete_outline, color: colorScheme.error),
                title: Text(
                  'Remove Photo',
                  style: TextStyle(color: colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _removePhoto();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPhoto = photoPath != null && photoPath!.isNotEmpty;
    final isNetwork =
        hasPhoto &&
        (photoPath!.startsWith('http://') || photoPath!.startsWith('https://'));
    final file = (!isNetwork && hasPhoto) ? File(photoPath!) : null;
    final fileExists = file != null && file.existsSync();
    final colorScheme = Theme.of(context).colorScheme;

    ImageProvider? imageProvider;
    if (isNetwork) {
      imageProvider = NetworkImage(photoPath!);
    } else if (fileExists) {
      imageProvider = FileImage(file);
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () => _showPhotoOptions(context, ref),
          child: CircleAvatar(
            radius: 48,
            backgroundColor: colorScheme.outline.withValues(alpha: 0.3),
            backgroundImage: imageProvider,
            onBackgroundImageError: imageProvider != null
                ? (exception, stackTrace) {}
                : null,
            child: imageProvider == null
                ? Icon(
                    Icons.person_outline,
                    size: 48,
                    color: colorScheme.primary,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _showPhotoOptions(context, ref),
          child: Text(
            'Upload photo',
            style: AppTypography.button.copyWith(
              fontSize: 14,
              color: colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
