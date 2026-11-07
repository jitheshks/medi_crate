// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
// import '../../../../app/routes/app_routes.dart';
// import '../../../../core/constants/app_icons.dart';
// import '../../../../core/constants/app_radius.dart';
// import '../../../../core/constants/app_typography.dart';
// import '../../../../core/extensions/build_context_extensions.dart';
// import '../../../../core/permissions/app_permission_service.dart';
// import '../../../profile/presentation/providers/profile_providers.dart';
// import '../providers/ocr_providers.dart';

// /// Screen allowing camera capture or gallery import of prescription images.
// class ScanPrescriptionScreen extends ConsumerWidget {
//   const ScanPrescriptionScreen({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final activeProfile = ref.watch(activeProfileProvider);
//     final ocrState = ref.watch(ocrScanControllerProvider);
//     final isLoading = ocrState.isLoading;

//     return Scaffold(
//       appBar: AppBar(title: const Text('Scan Prescription'), centerTitle: true),
//       body: SingleChildScrollView(
//         child: Center(
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 600),
//             child: Padding(
//               padding: const EdgeInsets.all(24.0),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   // Icon Header
//                   Container(
//                     width: 90,
//                     height: 90,
//                     alignment: Alignment.center,
//                     decoration: BoxDecoration(
//                       color: Theme.of(
//                         context,
//                       ).colorScheme.primary.withValues(alpha: 0.1),
//                       shape: BoxShape.circle,
//                     ),
//                     child: Icon(
//                       Icons.document_scanner_outlined,
//                       size: 48,
//                       color: Theme.of(context).colorScheme.primary,
//                     ),
//                   ),
//                   const SizedBox(height: 24),

//                   // Title & Subtitle
//                   Text(
//                     'Scan Physical Prescription',
//                     textAlign: TextAlign.center,
//                     style: AppTypography.h2.copyWith(
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     'Photograph or upload your prescription to extract medicines, doctor details, and report notes automatically.',
//                     textAlign: TextAlign.center,
//                     style: AppTypography.bodyMedium.copyWith(
//                       color: Theme.of(context).colorScheme.onSurfaceVariant,
//                     ),
//                   ),
//                   const SizedBox(height: 12),

//                   // Active Profile Target Chip
//                   if (activeProfile != null)
//                     Center(
//                       child: Chip(
//                         avatar: const Icon(AppIcons.userCheck, size: 16),
//                         label: Text(
//                           'Target Profile: ${activeProfile.fullName}',
//                           style: AppTypography.caption.copyWith(
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                         backgroundColor: Theme.of(
//                           context,
//                         ).colorScheme.primary.withValues(alpha: 0.08),
//                       ),
//                     ),

//                   const SizedBox(height: 36),

//                   if (isLoading)
//                     Column(
//                       children: [
//                         const CircularProgressIndicator(),
//                         const SizedBox(height: 16),
//                         Text(
//                           'Processing image with on-device OCR...',
//                           style: AppTypography.bodyMedium.copyWith(
//                             fontWeight: FontWeight.w500,
//                             color: Theme.of(
//                               context,
//                             ).colorScheme.onSurfaceVariant,
//                           ),
//                         ),
//                       ],
//                     )
//                   else ...[
//                     // Camera Capture Button
//                     ElevatedButton.icon(
//                       onPressed: () =>
//                           _handleScan(context, ref, isCamera: true),
//                       icon: const Icon(Icons.camera_alt_outlined),
//                       label: const Text('TAKE PHOTO WITH CAMERA'),
//                       style: ElevatedButton.styleFrom(
//                         minimumSize: const Size(double.infinity, 52),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(AppRadius.pill),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 14),

//                     // Gallery Import Button
//                     OutlinedButton.icon(
//                       onPressed: () =>
//                           _handleScan(context, ref, isCamera: false),
//                       icon: const Icon(Icons.photo_library_outlined),
//                       label: const Text('SELECT FROM GALLERY'),
//                       style: OutlinedButton.styleFrom(
//                         minimumSize: const Size(double.infinity, 52),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(AppRadius.pill),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _handleScan(
//     BuildContext context,
//     WidgetRef ref, {
//     required bool isCamera,
//   }) async {
//     if (isCamera) {
//       final hasPermission = await AppPermissionService.requestCameraPermission(
//         context,
//         featureName: 'scan a prescription with your camera',
//       );
//       if (!hasPermission) return;
//     } else {
//       final hasPermission = await AppPermissionService.requestPhotoPermission(
//         context,
//         featureName: 'import a prescription from gallery',
//       );
//       if (!hasPermission) return;
//     }

//     if (!context.mounted) return;
//     final activeProfile = ref.read(activeProfileProvider);
//     if (activeProfile == null) {
//       context.showSnackBar('Please select an active profile before scanning.');
//       return;
//     }

//     final controller = ref.read(ocrScanControllerProvider.notifier);
//     final success = isCamera
//         ? await controller.startCameraScan(activeProfile.profileId)
//         : await controller.startGalleryScan(activeProfile.profileId);

//     if (context.mounted && success) {
//       context.push(AppRoutes.ocrReview);
//     } else if (context.mounted && !success) {
//       final state = ref.read(ocrScanControllerProvider);
//       if (state.hasError) {
//         context.showSnackBar(
//           'Unable to access image or camera. Please try again.',
//         );
//       }
//     }
//   }
// }
