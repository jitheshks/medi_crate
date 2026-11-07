// import 'dart:io';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:path_provider/path_provider.dart';
// import '../../../insights/presentation/providers/insights_providers.dart';
// import '../../../medicines/data/repositories/medicine_repository.dart';
// import '../../../profile/data/models/profile_model.dart';
// import '../../../reports/data/models/report_model.dart';
// import '../../../reports/data/repositories/report_repository.dart';
// import '../../../reports/presentation/providers/reports_providers.dart';
// import '../../data/models/ocr_medicine_item_draft.dart';
// import '../../data/models/prescription_ocr_draft.dart';
// import '../../data/services/ocr_camera_service.dart';
// import '../../data/services/ocr_service.dart';
// import '../../data/services/ocr_text_parser.dart';

// final ocrCameraServiceProvider = Provider<OcrCameraService>((ref) {
//   return OcrCameraService();
// });

// final ocrServiceProvider = Provider<OcrService>((ref) {
//   final service = OcrService();
//   ref.onDispose(() => service.dispose());
//   return service;
// });

// final ocrTextParserProvider = Provider<OcrTextParser>((ref) {
//   return const OcrTextParser();
// });

// /// Controller managing OCR scanning, draft editing, profile validation, and persistence.
// class OcrScanController
//     extends StateNotifier<AsyncValue<PrescriptionOcrDraft?>> {
//   final Ref ref;

//   OcrScanController(this.ref) : super(const AsyncValue.data(null));

//   OcrCameraService get _cameraService => ref.read(ocrCameraServiceProvider);
//   OcrService get _ocrService => ref.read(ocrServiceProvider);
//   OcrTextParser get _parser => ref.read(ocrTextParserProvider);

//   /// Captures image via camera and runs offline OCR parser.
//   Future<bool> startCameraScan(String profileId) async {
//     return _processScan(() => _cameraService.captureFromCamera(), profileId);
//   }

//   /// Selects document image from gallery and runs offline OCR parser.
//   Future<bool> startGalleryScan(String profileId) async {
//     return _processScan(() => _cameraService.pickFromGallery(), profileId);
//   }

//   Future<bool> _processScan(
//     Future<String?> Function() sourcePicker,
//     String profileId,
//   ) async {
//     state = const AsyncValue.loading();
//     try {
//       final imagePath = await sourcePicker();
//       if (imagePath == null) {
//         state = const AsyncValue.data(null);
//         return false;
//       }

//       final rawText = await _ocrService.processImage(imagePath);
//       final draft = _parser.parse(
//         rawText: rawText,
//         profileId: profileId,
//         imagePath: imagePath,
//       );

//       state = AsyncValue.data(draft);
//       return true;
//     } catch (e, st) {
//       state = AsyncValue.error(e, st);
//       return false;
//     }
//   }

//   void updateDraft(PrescriptionOcrDraft updated) {
//     state = AsyncValue.data(updated);
//   }

//   void updateMedicineItem(OcrMedicineItemDraft updatedItem) {
//     final draft = state.value;
//     if (draft == null) return;
//     final medicines = draft.extractedMedicines.map((m) {
//       return m.id == updatedItem.id ? updatedItem : m;
//     }).toList();
//     state = AsyncValue.data(draft.copyWith(extractedMedicines: medicines));
//   }

//   void addMedicineItem(OcrMedicineItemDraft newItem) {
//     final draft = state.value;
//     if (draft == null) return;
//     final medicines = [...draft.extractedMedicines, newItem];
//     state = AsyncValue.data(draft.copyWith(extractedMedicines: medicines));
//   }

//   void removeMedicineItem(String itemId) {
//     final draft = state.value;
//     if (draft == null) return;
//     final medicines = draft.extractedMedicines
//         .where((m) => m.id != itemId)
//         .toList();
//     state = AsyncValue.data(draft.copyWith(extractedMedicines: medicines));
//   }

//   /// Cleans up temporary image cache and discards draft.
//   Future<void> discardDraft() async {
//     final draft = state.value;
//     if (draft != null) {
//       await _cameraService.deleteTemporaryImage(draft.imagePath);
//     }
//     state = const AsyncValue.data(null);
//   }

//   /// Confirms draft and persists profile-scoped ReportModel to local storage.
//   Future<ReportModel> saveDraftAsReport({
//     required ProfileModel activeProfile,
//     required ReportRepository reportRepository,
//     MedicineRepository? medicineRepository,
//     bool createMedicineSchedules = false,
//   }) async {
//     final draft = state.value;
//     if (draft == null) {
//       throw StateError('No active OCR draft available to save.');
//     }

//     // Profile Safety Enforcement: Prevent cross-profile leakage
//     if (draft.profileId != activeProfile.profileId) {
//       throw StateError(
//         'Profile Mismatch: Draft belongs to another family profile. Operation aborted for safety.',
//       );
//     }

//     // 1. Copy temporary image to app documents directory
//     final appDir = await getApplicationDocumentsDirectory();
//     final profileDir = Directory(
//       '${appDir.path}/profiles/${draft.profileId}/attachments',
//     );
//     if (!await profileDir.exists()) {
//       await profileDir.create(recursive: true);
//     }

//     final timestamp = DateTime.now().millisecondsSinceEpoch;
//     final permanentPath = '${profileDir.path}/prescription_$timestamp.jpg';

//     final tempFile = File(draft.imagePath);
//     if (await tempFile.exists()) {
//       await tempFile.copy(permanentPath);
//       // Clean up temp file
//       await tempFile.delete();
//     }

//     final fileSizeKb = (await File(permanentPath).exists())
//         ? (await File(permanentPath).length() / 1024).round()
//         : 0;

//     // 2. Create Attachment and Report models
//     final attachment = ReportAttachmentModel(
//       id: 'att_$timestamp',
//       name: 'prescription_$timestamp.jpg',
//       size: '$fileSizeKb KB',
//       filePath: permanentPath,
//       fileType: 'image/jpeg',
//     );

//     final report = ReportModel(
//       id: 'r_ocr_$timestamp',
//       profileId: draft.profileId,
//       title: draft.extractedTitle.trim().isNotEmpty
//           ? draft.extractedTitle
//           : 'Prescription',
//       category: 'PRESCRIPTION',
//       date: draft.extractedDate,
//       doctorName: draft.extractedDoctorName,
//       hospitalName: draft.extractedHospitalName,
//       notes: draft.notes,
//       attachments: [attachment],
//       createdAt: DateTime.now(),
//     );

//     // 3. Save through ReportRepository and notify list notifier & insights
//     final savedReport = await reportRepository.saveReport(
//       draft.profileId,
//       report,
//     );

//     // 4. Optionally create Medicine schedule records if user requested
//     if (createMedicineSchedules && medicineRepository != null) {
//       for (final med in draft.extractedMedicines) {
//         if (med.medicationName.trim().isNotEmpty) {
//           await medicineRepository.saveMedicine(draft.profileId, {
//             'medication_name': med.medicationName,
//             'dosage': med.dosage,
//             'frequency': med.frequency,
//             'duration_days': med.durationDays,
//             'timing': med.timing,
//             'is_active': true,
//           });
//         }
//       }
//     }

//     // 5. Invalidate reports and insights list providers
//     ref.read(reportsListNotifierProvider.notifier).refreshReports();
//     ref.invalidate(insightsSummaryProvider);

//     state = const AsyncValue.data(null);
//     return savedReport;
//   }
// }

// final ocrScanControllerProvider =
//     StateNotifierProvider<OcrScanController, AsyncValue<PrescriptionOcrDraft?>>(
//       (ref) => OcrScanController(ref),
//     );
