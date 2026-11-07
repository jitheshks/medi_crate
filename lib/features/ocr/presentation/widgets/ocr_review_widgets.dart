import 'package:flutter/material.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/app_semantic_colors.dart';

/// Warning banner highlighting OCR potential inaccuracy to prompt manual review.
class OcrReviewDisclaimerBanner extends StatelessWidget {
  const OcrReviewDisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final bgColor = semantic.warningContainer;
    final borderColor = semantic.warningBorder;
    final textColor = semantic.onWarningContainer;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: textColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'OCR results may be inaccurate. Review and edit all fields before saving.',
              style: AppTypography.caption.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Collapsible raw text viewer widget for inspecting untransformed OCR output.
class OcrRawTextSection extends StatefulWidget {
  final String rawText;

  const OcrRawTextSection({super.key, required this.rawText});

  @override
  State<OcrRawTextSection> createState() => _OcrRawTextSectionState();
}

class _OcrRawTextSectionState extends State<OcrRawTextSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ExpansionTile(
      title: Text(
        _isExpanded ? 'Hide Raw OCR Text' : 'View Raw Extracted Text',
        style: AppTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      onExpansionChanged: (val) => setState(() => _isExpanded = val),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: colorScheme.outline),
          ),
          child: Text(
            widget.rawText.isEmpty
                ? 'No text detected from image.'
                : widget.rawText,
            style: AppTypography.caption.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
