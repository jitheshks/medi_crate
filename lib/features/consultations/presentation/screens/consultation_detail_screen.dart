import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_currency.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/detail/detail_widgets.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/pulsing_vault_logo.dart';
import '../../../doctors/data/models/doctor_hospital_relation.dart';
import '../providers/consultation_providers.dart';
import '../widgets/detail/consultation_delete_handler.dart';
import '../widgets/detail/consultation_detail_attachments_section.dart';
import '../widgets/detail/consultation_detail_follow_up_card.dart';
import '../widgets/detail/consultation_detail_medicines_section.dart';
import '../widgets/detail/consultation_detail_reports_section.dart';
import '../widgets/detail/consultation_detail_visit_card.dart';

/// ConsultationDetailScreen presents the full details of a clinical consultation record.
class ConsultationDetailScreen extends ConsumerStatefulWidget {
  final String consultationId;

  const ConsultationDetailScreen({super.key, required this.consultationId});

  @override
  ConsumerState<ConsultationDetailScreen> createState() =>
      _ConsultationDetailScreenState();
}

class _ConsultationDetailScreenState
    extends ConsumerState<ConsultationDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _medicinesKey = GlobalKey();
  final GlobalKey _reportsKey = GlobalKey();
  String? _highlightedSection;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToFirstDependency(EntityDependencies deps) {
    GlobalKey? targetKey;
    String? section;
    if (deps.medicines > 0) {
      targetKey = _medicinesKey;
      section = 'medicines';
    } else if (deps.reports > 0) {
      targetKey = _reportsKey;
      section = 'reports';
    }

    if (targetKey != null) {
      if (mounted) {
        setState(() => _highlightedSection = section);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetContext = targetKey?.currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOut,
            alignment: 0.05,
          );
        }
      });
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) {
          setState(() => _highlightedSection = null);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final consultationAsync = ref.watch(
      consultationDetailProvider(widget.consultationId),
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        shape: Border(bottom: BorderSide(color: colorScheme.outline, width: 1)),
        leading: Center(
          child: InkWell(
            onTap: () => context.popOrGo(AppRoutes.consultations),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back,
                size: 19,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
        title: Text(
          'Consultation',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: consultationAsync.when(
        loading: () => const Center(child: PulsingVaultLogo()),
        error: (err, stack) => AppErrorState(
          error: err,
          title: 'Unable to Load Consultation',
          onRetry: () =>
              ref.invalidate(consultationDetailProvider(widget.consultationId)),
        ),
        data: (consultation) {
          if (consultation == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_off_outlined,
                    size: 48,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Consultation record not found.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.popOrGo(AppRoutes.consultations),
                    child: const Text('Back to Consultations'),
                  ),
                ],
              ),
            );
          }

          final visitDateStr = DateFormat('dd MMM yyyy')
              .format(consultation.visitDate);

          return DetailScreenScaffold(
            scrollController: _scrollController,
            hero: DetailHero(
              icon: AppIcons.stethoscope,
              iconColor: colorScheme.primary,
              iconBackground: colorScheme.primaryContainer,
              title: consultation.diagnosis.isNotEmpty
                  ? consultation.diagnosis
                  : 'Clinical Consultation',
              subtitle: visitDateStr,
            ),
            sections: [
              // 1. Visit Details
              DetailSection(
                title: 'VISIT DETAILS',
                topPadding: 16,
                child: ConsultationDetailVisitCard(consultation: consultation),
              ),

              // 2. Chief Complaint
              DetailSection(
                title: 'CHIEF COMPLAINT',
                child: DetailNoteBox(
                  notes: consultation.chiefComplaint,
                  fallbackText: 'Not recorded.',
                ),
              ),

              // 3. Clinical Notes
              DetailSection(
                title: 'CLINICAL NOTES',
                child: DetailNoteBox(
                  notes: consultation.clinicalNotes,
                  fallbackText: 'No notes added.',
                ),
              ),

              // 4. Prescribed Medicines Section
              DetailSection(
                key: _medicinesKey,
                title: 'PRESCRIBED MEDICINES',
                isHighlighted: _highlightedSection == 'medicines',
                child: ConsultationDetailMedicinesSection(
                  consultation: consultation,
                ),
              ),

              // 5. Follow-up
              DetailSection(
                title: 'FOLLOW-UP',
                child: ConsultationDetailFollowUpCard(
                  consultation: consultation,
                ),
              ),

              // 6. Tags (Conditional)
              if (consultation.tags.isNotEmpty)
                DetailSection(
                  title: 'TAGS',
                  child: DetailChipList(chips: consultation.tags),
                ),

              // 7. Expense (Conditional)
              if (consultation.consultationFee != null &&
                  consultation.consultationFee! > 0)
                DetailSection(
                  title: 'EXPENSE',
                  child: DetailExpenseCard(
                    amountText:
                        '${AppCurrency.getSymbol(consultation.currency)} ${consultation.consultationFee!.toStringAsFixed(0)}',
                    category: 'Consultation fee',
                    status: 'PAID',
                  ),
                ),

              // 8. Reports Section
              DetailSection(
                key: _reportsKey,
                title: 'REPORTS',
                isHighlighted: _highlightedSection == 'reports',
                child: ConsultationDetailReportsSection(
                  consultation: consultation,
                ),
              ),

              // 9. Attachments Section (Read-only)
              DetailSection(
                title: 'ATTACHMENTS (${consultation.attachments.length})',
                child: ConsultationDetailAttachmentsSection(
                  consultation: consultation,
                ),
              ),
            ],
            actions: DetailActionRow(
              onEdit: () => context.pushGuarded(
                AppRoutes.editConsultation(consultation.id),
              ),
              onDelete: () => ConsultationDeleteHandler.confirmDelete(
                context: context,
                ref: ref,
                consultation: consultation,
                onScrollToDependency: _scrollToFirstDependency,
              ),
            ),
          );
        },
      ),
    );
  }
}
