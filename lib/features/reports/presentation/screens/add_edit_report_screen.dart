import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../consultations/presentation/providers/consultation_providers.dart';
import '../../../doctors/presentation/providers/doctors_providers.dart';
import '../../../hospitals/presentation/providers/hospitals_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../../shared/utils/form_submit_runner.dart';
import '../../data/models/report_model.dart';
import '../providers/reports_providers.dart';
import '../widgets/form/report_form_content.dart';
import '../widgets/form/report_form_controller.dart';
import '../widgets/form/report_form_save_helper.dart';
import '../widgets/form/report_save_bottom_bar.dart';

class AddEditReportScreen extends ConsumerStatefulWidget {
  final String? reportIdToEdit;

  const AddEditReportScreen({super.key, this.reportIdToEdit});

  @override
  ConsumerState<AddEditReportScreen> createState() =>
      _AddEditReportScreenState();
}

class _AddEditReportScreenState extends ConsumerState<AddEditReportScreen> {
  final ReportFormController _formCtrl = ReportFormController();

  bool _isSaving = false;
  bool _isLoadingReport = false;
  bool _hasLoaded = false;
  bool _isEdit = false;
  ReportModel? _originalReport;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.reportIdToEdit != null;
    if (_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadReportForEditing();
      });
    }
  }

  Future<void> _loadReportForEditing() async {
    setState(() => _isLoadingReport = true);
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile != null && widget.reportIdToEdit != null) {
      try {
        final repo = ref.read(reportRepositoryProvider);
        final report = await repo.getReportById(
          activeProfile.profileId,
          widget.reportIdToEdit!,
        );

        if (mounted) {
          _originalReport = report;
          if (report != null) {
            _formCtrl.populateFromReport(report);

            if (report.consultationId != null &&
                (_formCtrl.doctorId == null || _formCtrl.hospitalId == null)) {
              final consultRepo = ref.read(consultationRepositoryProvider);
              final linkedConsult = await consultRepo.getConsultationById(
                activeProfile.profileId,
                report.consultationId!,
              );
              if (linkedConsult != null) {
                _formCtrl.doctorId ??= linkedConsult.doctorId;
                _formCtrl.doctorName ??= linkedConsult.doctorName;
                _formCtrl.hospitalId ??= linkedConsult.hospitalId;
                _formCtrl.hospitalName ??= linkedConsult.hospitalName;
              }
            }
          }
          _hasLoaded = true;
          _isLoadingReport = false;
        }
      } catch (_) {
        if (mounted) {
          _hasLoaded = true;
          _isLoadingReport = false;
        }
      }
    } else if (mounted) {
      setState(() => _isLoadingReport = false);
    }
  }

  @override
  void dispose() {
    _formCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveReport() async {
    if (_formCtrl.attachments.isEmpty) {
      context.showErrorSnackBar(
        'Please upload at least one report document or attachment.',
      );
      return;
    }

    await FormSubmitRunner.run<ReportModel?>(
      context: context,
      isMounted: () => mounted,
      setLoading: (val) => setState(() => _isSaving = val),
      formKey: _formCtrl.formKey,
      defaultErrorMessage: "Couldn't save report. Please try again.",
      action: () async {
        final activeProfile = ref.read(activeProfileProvider);
        if (activeProfile == null) {
          throw Exception('No active profile selected.');
        }

        if (_isEdit && _originalReport == null) {
          throw Exception(
            'Cannot update report: target record could not be resolved.',
          );
        }

        final report = ReportFormSaveHelper.buildReportModel(
          reportIdToEdit: widget.reportIdToEdit,
          isEdit: _isEdit,
          profileId: activeProfile.profileId,
          title: _formCtrl.titleController.text,
          selectedCategory: _formCtrl.selectedCategory,
          selectedDate: _formCtrl.selectedDate,
          consultationId: _formCtrl.consultationId,
          consultationTitle: _formCtrl.consultationTitle,
          doctorId: _formCtrl.doctorId,
          doctorName: _formCtrl.doctorName,
          hospitalId: _formCtrl.hospitalId,
          hospitalName: _formCtrl.hospitalName,
          notes: _formCtrl.notesController.text,
          attachments: _formCtrl.attachments,
          enableExpense: _formCtrl.enableExpense,
          expenseAmountText: _formCtrl.expenseAmountController.text,
          expenseStatus: _formCtrl.expenseStatus,
          expenseDescText: _formCtrl.expenseDescController.text,
          expenseCurrency:
              _formCtrl.expenseCurrency ?? ref.read(appCurrencyProvider),
          clientUuid: _originalReport?.clientUuid ?? _formCtrl.clientUuid,
        );

        return await ref
            .read(reportsListNotifierProvider.notifier)
            .saveReport(report);
      },
      onSuccess: (saved) {
        if (saved != null) {
          context.showSuccessSnackBar(
            _isEdit
                ? 'Report updated successfully.'
                : 'Report saved successfully.',
          );
          context.popOrGo(AppRoutes.reports);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeProfileProvider, (prev, next) {
      if (_isEdit && !_hasLoaded && next != null) {
        _loadReportForEditing();
      }
    });

    final colorScheme = Theme.of(context).colorScheme;
    final activeProfile = ref.watch(activeProfileProvider);

    final consultationsAsync = ref.watch(consultationsListNotifierProvider);
    final doctorsAsync = ref.watch(doctorsListProvider);
    final hospitalsAsync = ref.watch(hospitalsListProvider);

    if (_isEdit && _isLoadingReport) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(AppIcons.arrowLeft),
            onPressed: () => context.popOrGo(AppRoutes.reports),
          ),
          title: Text(
            'Edit Report',
            style: AppTypography.h3.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_isEdit && _hasLoaded && _originalReport == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(AppIcons.arrowLeft),
            onPressed: () => context.popOrGo(AppRoutes.reports),
          ),
          title: Text(
            'Edit Report',
            style: AppTypography.h3.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Report not found',
                style: AppTypography.h3.copyWith(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.popOrGo(AppRoutes.reports),
                child: const Text('Back to Reports'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(AppIcons.arrowLeft),
          onPressed: () => context.popOrGo(AppRoutes.reports),
        ),
        title: Text(
          _isEdit ? 'Edit Report' : 'Upload Report',
          style: AppTypography.h3.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formCtrl.formKey,
                  child: ReportFormContent(
                    activeProfile: activeProfile,
                    controller: _formCtrl,
                    onStateChanged: () => setState(() {}),
                    consultationsAsync: consultationsAsync,
                    doctorsAsync: doctorsAsync,
                    hospitalsAsync: hospitalsAsync,
                  ),
                ),
              ),
            ),

            // STICKY SAVE BUTTON
            ReportSaveBottomBar(
              isSaving: _isSaving,
              isEdit: _isEdit,
              onSave: _saveReport,
            ),
          ],
        ),
      ),
    );
  }
}
