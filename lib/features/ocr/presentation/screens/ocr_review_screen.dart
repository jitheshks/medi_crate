// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
// import '../../../../app/routes/app_routes.dart';
// import '../../../../core/constants/app_radius.dart';
// import '../../../../core/constants/app_typography.dart';
// import '../../../../core/extensions/build_context_extensions.dart';
// import '../../../medicines/presentation/providers/medicine_providers.dart';
// import '../../../profile/presentation/providers/profile_providers.dart';
// import '../../../reports/presentation/providers/reports_providers.dart';
// import '../../data/models/ocr_medicine_item_draft.dart';
// import '../providers/ocr_providers.dart';
// import '../widgets/ocr_extracted_medicines_section.dart';
// import '../widgets/ocr_form_fields.dart';
// import '../widgets/ocr_review_widgets.dart';

// /// Screen allowing users to review, edit, confirm, or discard extracted OCR fields.
// class OcrReviewScreen extends ConsumerStatefulWidget {
//   const OcrReviewScreen({super.key});

//   @override
//   ConsumerState<OcrReviewScreen> createState() => _OcrReviewScreenState();
// }

// class _OcrReviewScreenState extends ConsumerState<OcrReviewScreen> {
//   late TextEditingController _titleController;
//   late TextEditingController _doctorController;
//   late TextEditingController _hospitalController;
//   late TextEditingController _notesController;
//   bool _createMedicineSchedules = false;

//   @override
//   void initState() {
//     super.initState();
//     final draft = ref.read(ocrScanControllerProvider).value;
//     _titleController = TextEditingController(
//       text: draft?.extractedTitle ?? 'Prescription',
//     );
//     _doctorController = TextEditingController(
//       text: draft?.extractedDoctorName ?? '',
//     );
//     _hospitalController = TextEditingController(
//       text: draft?.extractedHospitalName ?? '',
//     );
//     _notesController = TextEditingController(text: draft?.notes ?? '');
//   }

//   @override
//   void dispose() {
//     _titleController.dispose();
//     _doctorController.dispose();
//     _hospitalController.dispose();
//     _notesController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final activeProfile = ref.watch(activeProfileProvider);
//     final ocrState = ref.watch(ocrScanControllerProvider);
//     final draft = ocrState.value;

//     if (draft == null) {
//       return Scaffold(
//         appBar: AppBar(title: const Text('Review Prescription')),
//         body: const Center(child: Text('No active draft to review.')),
//       );
//     }

//     final colorScheme = Theme.of(context).colorScheme;
//     final isProfileMismatch =
//         activeProfile != null && activeProfile.profileId != draft.profileId;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Review Extracted Details'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.delete_outline, color: colorScheme.error),
//             tooltip: 'Discard Draft',
//             onPressed: () => _handleDiscard(context),
//           ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(20.0),
//         child: Center(
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 600),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const OcrReviewDisclaimerBanner(),
//                 const SizedBox(height: 16),
//                 if (isProfileMismatch) ...[
//                   Container(
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: Theme.of(context).colorScheme.errorContainer,
//                       borderRadius: BorderRadius.circular(AppRadius.input),
//                       border: Border.all(
//                         color: Theme.of(context).colorScheme.error,
//                       ),
//                     ),
//                     child: Text(
//                       'Warning: Active profile changed! This draft belongs to another profile. Switch back or discard.',
//                       style: AppTypography.caption.copyWith(
//                         color: Theme.of(context).colorScheme.onErrorContainer,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                 ],
//                 if (draft.imagePath.isNotEmpty &&
//                     File(draft.imagePath).existsSync())
//                   ClipRRect(
//                     borderRadius: BorderRadius.circular(AppRadius.card),
//                     child: Container(
//                       height: 160,
//                       width: double.infinity,
//                       decoration: BoxDecoration(
//                         color: colorScheme.surfaceContainerHighest.withValues(
//                           alpha: 0.3,
//                         ),
//                         borderRadius: BorderRadius.circular(AppRadius.card),
//                       ),
//                       child: Image.file(
//                         File(draft.imagePath),
//                         fit: BoxFit.cover,
//                       ),
//                     ),
//                   ),
//                 const SizedBox(height: 20),
//                 OcrFormFields(
//                   titleController: _titleController,
//                   doctorController: _doctorController,
//                   hospitalController: _hospitalController,
//                   notesController: _notesController,
//                 ),
//                 const SizedBox(height: 20),
//                 OcrExtractedMedicinesSection(
//                   medicines: draft.extractedMedicines,
//                   onAddMedicine: _addMedicineTile,
//                   onUpdateMedicine: (updated) {
//                     ref
//                         .read(ocrScanControllerProvider.notifier)
//                         .updateMedicineItem(updated);
//                   },
//                   onRemoveMedicine: (id) {
//                     ref
//                         .read(ocrScanControllerProvider.notifier)
//                         .removeMedicineItem(id);
//                   },
//                 ),
//                 const SizedBox(height: 16),
//                 CheckboxListTile(
//                   value: _createMedicineSchedules,
//                   onChanged: (val) =>
//                       setState(() => _createMedicineSchedules = val ?? false),
//                   title: const Text('Also add medicines to active schedule'),
//                   subtitle: const Text(
//                     'Creates separate medication entries in your Medicines tab',
//                   ),
//                   controlAffinity: ListTileControlAffinity.leading,
//                   contentPadding: EdgeInsets.zero,
//                 ),
//                 const SizedBox(height: 12),
//                 OcrRawTextSection(rawText: draft.rawText),
//                 const SizedBox(height: 28),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: OutlinedButton(
//                         onPressed: () => _handleDiscard(context),
//                         style: OutlinedButton.styleFrom(
//                           minimumSize: const Size(0, 48),
//                         ),
//                         child: const Text('DISCARD'),
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: ElevatedButton(
//                         onPressed: isProfileMismatch
//                             ? null
//                             : () => _handleSave(context),
//                         style: ElevatedButton.styleFrom(
//                           minimumSize: const Size(0, 48),
//                         ),
//                         child: const Text('CONFIRM & SAVE'),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   void _addMedicineTile() {
//     final newItem = OcrMedicineItemDraft(
//       id: 'draft_med_${DateTime.now().millisecondsSinceEpoch}',
//       medicationName: 'New Medication',
//       dosage: '',
//       frequency: 'Once daily',
//     );
//     ref.read(ocrScanControllerProvider.notifier).addMedicineItem(newItem);
//   }

//   Future<void> _handleDiscard(BuildContext context) async {
//     await ref.read(ocrScanControllerProvider.notifier).discardDraft();
//     if (context.mounted) {
//       context.pop();
//     }
//   }

//   Future<void> _handleSave(BuildContext context) async {
//     final activeProfile = ref.read(activeProfileProvider);
//     if (activeProfile == null) return;

//     final draft = ref.read(ocrScanControllerProvider).value;
//     if (draft == null) return;

//     final updatedDraft = draft.copyWith(
//       extractedTitle: _titleController.text.trim(),
//       extractedDoctorName: _doctorController.text.trim(),
//       extractedHospitalName: _hospitalController.text.trim(),
//       notes: _notesController.text.trim(),
//     );

//     ref.read(ocrScanControllerProvider.notifier).updateDraft(updatedDraft);

//     final reportRepo = ref.read(reportRepositoryProvider);
//     final medicineRepo = ref.read(medicineRepositoryProvider);

//     try {
//       await ref
//           .read(ocrScanControllerProvider.notifier)
//           .saveDraftAsReport(
//             activeProfile: activeProfile,
//             reportRepository: reportRepo,
//             medicineRepository: medicineRepo,
//             createMedicineSchedules: _createMedicineSchedules,
//           );

//       ref.invalidate(reportsListNotifierProvider);

//       if (context.mounted) {
//         context.showSnackBar('Prescription report saved successfully.');
//         context.go(AppRoutes.reports);
//       }
//     } catch (e) {
//       if (context.mounted) {
//         context.showErrorSnackBar(e.toString().replaceAll('StateError: ', ''));
//       }
//     }
//   }
// }
