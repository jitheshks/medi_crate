import 'package:flutter/material.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';

/// TermsPrivacyScreen provides full-page text reader for Terms & Privacy Policy.
class TermsPrivacyScreen extends StatelessWidget {
  const TermsPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Terms & Privacy Policy',
          style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
        ),
        backgroundColor: colorScheme.surface,
        leading: IconButton(
          icon: Icon(AppIcons.arrowLeft, color: colorScheme.onSurface),
          onPressed: () => context.popOrGo(AppRoutes.login),
        ),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy & Data Ownership',
              style: AppTypography.h1.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            Text(
              'Last updated: August 2026',
              style: AppTypography.caption.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '1. Patient Ownership\nAll health records, consultations, doctor notes, and medical measurements entered into MediCrate remain exclusively patient-owned. MediCrate does not sell, market, or share health data with third-party insurers or data brokers.\n\n'
              '2. Local Encryption & Syncing\nYour health vault data is saved locally using high-performance Hive database storage. When online, your records are automatically synchronized with our encrypted backend API service.\n\n'
              '3. Account Security\nStrong encryption and authentication safeguard your vault. You can manage access settings at any time from the Account Settings screen.',
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
