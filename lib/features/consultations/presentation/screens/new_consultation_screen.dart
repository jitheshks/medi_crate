import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/models/consultation_model.dart';
import '../providers/consultation_form_providers.dart';
import '../widgets/consultation_attachments_section.dart';
import '../widgets/form/consultation_appointment_section.dart';
import '../widgets/form/consultation_clinical_section.dart';
import '../widgets/form/consultation_doctor_hospital_section.dart';
import '../widgets/form/consultation_follow_up_section.dart';
import '../widgets/form/consultation_form_handler.dart';
import '../widgets/form/consultation_profile_banner.dart';
import '../widgets/form/consultation_save_button_bar.dart';
import '../widgets/form/consultation_tags_expense_section.dart';
import '../widgets/form/consultation_visit_section.dart';

/// NewConsultationScreen presents the consultation form for creating or editing records.
class NewConsultationScreen extends ConsumerStatefulWidget {
  final String? consultationIdToEdit;
  final ConsultationModel? initialConsultation;

  const NewConsultationScreen({
    super.key,
    this.consultationIdToEdit,
    this.initialConsultation,
  });

  @override
  ConsumerState<NewConsultationScreen> createState() =>
      _NewConsultationScreenState();
}

class _NewConsultationScreenState extends ConsumerState<NewConsultationScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _chiefComplaintController;
  late final TextEditingController _diagnosisController;
  late final TextEditingController _clinicalNotesController;
  late final TextEditingController _tagsController;
  late final TextEditingController _feeController;
  late final TextEditingController _followUpNotesController;

  bool _isSaving = false;
  bool _isInitialized = false;
  bool _isLoadingConsultation = false;
  bool _hasLoadedConsultation = false;
  ConsultationModel? _originalConsultation;
  List<String> _parsedTags = [];

  @override
  void initState() {
    super.initState();
    _chiefComplaintController = TextEditingController();
    _diagnosisController = TextEditingController();
    _clinicalNotesController = TextEditingController();
    _tagsController = TextEditingController();
    _feeController = TextEditingController();
    _followUpNotesController = TextEditingController();

    _tagsController.addListener(_updateParsedTags);

    if (widget.initialConsultation != null) {
      _originalConsultation = widget.initialConsultation;
      _hasLoadedConsultation = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized && mounted) {
        _isInitialized = true;
        _loadInitialConsultation();
      }
    });
  }

  Future<void> _loadInitialConsultation() async {
    if (widget.initialConsultation != null) {
      ConsultationFormHandler.populateInitialData(
        ref: ref,
        consultationIdToEdit: widget.consultationIdToEdit,
        initialConsultation: widget.initialConsultation,
        chiefComplaintController: _chiefComplaintController,
        diagnosisController: _diagnosisController,
        clinicalNotesController: _clinicalNotesController,
        tagsController: _tagsController,
        feeController: _feeController,
        followUpNotesController: _followUpNotesController,
        isMounted: () => mounted,
      );
      if (mounted) {
        setState(() {
          _originalConsultation = widget.initialConsultation;
          _hasLoadedConsultation = true;
        });
      }
      return;
    }

    if (widget.consultationIdToEdit != null) {
      setState(() => _isLoadingConsultation = true);
      try {
        final loaded = await ConsultationFormHandler.populateInitialData(
          ref: ref,
          consultationIdToEdit: widget.consultationIdToEdit,
          initialConsultation: widget.initialConsultation,
          chiefComplaintController: _chiefComplaintController,
          diagnosisController: _diagnosisController,
          clinicalNotesController: _clinicalNotesController,
          tagsController: _tagsController,
          feeController: _feeController,
          followUpNotesController: _followUpNotesController,
          isMounted: () => mounted,
        );
        if (mounted) {
          setState(() {
            _originalConsultation = loaded;
            _hasLoadedConsultation = true;
            _isLoadingConsultation = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _hasLoadedConsultation = true;
            _isLoadingConsultation = false;
          });
        }
      }
    }
  }

  late ProviderContainer _container;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context);
  }

  void _updateParsedTags() {
    final text = _tagsController.text.trim();
    if (text.isEmpty) {
      if (_parsedTags.isNotEmpty) {
        setState(() => _parsedTags = []);
      }
    } else {
      final tags = text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      setState(() => _parsedTags = tags);
    }
  }

  @override
  void dispose() {
    final container = _container;
    Future.microtask(() => resetConsultationFormContainer(container));
    _tagsController.removeListener(_updateParsedTags);
    _chiefComplaintController.dispose();
    _diagnosisController.dispose();
    _clinicalNotesController.dispose();
    _tagsController.dispose();
    _feeController.dispose();
    _followUpNotesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSaving) return;
    await ConsultationFormHandler.submit(
      context: context,
      ref: ref,
      formKey: _formKey,
      chiefComplaintController: _chiefComplaintController,
      diagnosisController: _diagnosisController,
      clinicalNotesController: _clinicalNotesController,
      tagsController: _tagsController,
      feeController: _feeController,
      followUpNotesController: _followUpNotesController,
      consultationIdToEdit: widget.consultationIdToEdit,
      initialConsultation: _originalConsultation ?? widget.initialConsultation,
      onSavingChanged: (saving) {
        if (mounted) setState(() => _isSaving = saving);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeProfileProvider, (prev, next) {
      if (widget.consultationIdToEdit != null &&
          !_hasLoadedConsultation &&
          next != null) {
        _loadInitialConsultation();
      }
    });

    final activeProfile = ref.watch(activeProfileProvider);
    final isEditing =
        widget.consultationIdToEdit != null ||
        widget.initialConsultation != null;
    final colorScheme = Theme.of(context).colorScheme;
    final currentAttachments = ref.watch(consultationAttachmentsProvider);

    if (widget.consultationIdToEdit != null && _isLoadingConsultation) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            tooltip: 'Back',
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            'Edit Consultation',
            style: AppTypography.h1.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.consultationIdToEdit != null &&
        _hasLoadedConsultation &&
        _originalConsultation == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            tooltip: 'Back',
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            'Edit Consultation',
            style: AppTypography.h1.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
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
                'Consultation not found',
                style: AppTypography.h3.copyWith(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Back to Consultations'),
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
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          isEditing ? 'Edit Consultation' : 'New Consultation',
          style: AppTypography.h1.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          final horizontalPadding = isWide ? 24.0 : 16.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: horizontalPadding,
                    right: horizontalPadding,
                    top: 16,
                    bottom: 120,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConsultationProfileBanner(profile: activeProfile),
                      ConsultationAppointmentSection(
                        feeController: _feeController,
                        isEditing: isEditing,
                      ),
                      const SizedBox(height: 20),
                      ConsultationDoctorHospitalSection(
                        profileId: activeProfile?.profileId ?? '',
                      ),
                      const SizedBox(height: 20),
                      const ConsultationVisitSection(),
                      const SizedBox(height: 20),
                      ConsultationClinicalSection(
                        chiefComplaintController: _chiefComplaintController,
                        diagnosisController: _diagnosisController,
                        clinicalNotesController: _clinicalNotesController,
                      ),
                      const SizedBox(height: 20),
                      ConsultationFollowUpSection(
                        followUpNotesController: _followUpNotesController,
                      ),
                      const SizedBox(height: 20),
                      ConsultationTagsExpenseSection(
                        tagsController: _tagsController,
                        feeController: _feeController,
                        parsedTags: _parsedTags,
                      ),
                      const SizedBox(height: 24),
                      ConsultationAttachmentsSection(
                        attachments: currentAttachments,
                        profileId: activeProfile?.profileId,
                        onAttachmentsChanged: (updated) {
                          ref
                                  .read(
                                    consultationAttachmentsProvider.notifier,
                                  )
                                  .state =
                              updated;
                        },
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomSheet: ConsultationSaveButtonBar(
        isSaving: _isSaving,
        isEditing: isEditing,
        onSave: _handleSubmit,
      ),
    );
  }
}
