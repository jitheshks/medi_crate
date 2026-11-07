# MediCrate

MediCrate is a cross-platform, offline-first personal health record and clinical management application built with Flutter.

## Overview

MediCrate empowers patients and families to securely store, organize, track, and export their comprehensive medical history, consultations, prescriptions, lab reports, doctor profiles, hospital visits, and vital measurements.

### Key Features

- **Offline-First Architecture**: High-performance local storage powered by Hive, with an automated background sync engine that safely buffers mutations and reconciles data with remote backends.
- **Family Profiles**: Manage medical records across multiple family members with dedicated profiles.
- **Clinical Modules**:
  - Consultations & Clinical Diagnoses
  - Doctor & Hospital Relationships
  - Appointments & Reminders
  - Active Medications & Dosage Schedules
  - Diagnostic Lab Reports & Document Attachments
  - Vital Signs & Health Trends with Interactive Visualizations
- **Doctor Summary Export**: Client-side generation of confidential PDF medical summaries for clinical visits.
- **Privacy & Security**: End-to-end encrypted storage on-device, path traversal protection, sanitization of sensitive logs, and zero third-party data tracking.

## Technology Stack

- **Framework**: Flutter 3.47+ / Dart 3.13+
- **State Management**: Riverpod (AsyncNotifier & Providers)
- **Routing**: GoRouter with authentication guards
- **Local Database**: Hive / Hive Flutter
- **HTTP Client**: Dio with SSL pinning context, rate limiting, and sanitized request/response logging
- **Local Notifications**: `flutter_local_notifications` with timezone awareness
- **Charts & PDF**: `fl_chart`, `pdf`, `printing`

## Getting Started

### Prerequisites

- Flutter SDK (>= 3.47.0)
- Dart SDK (>= 3.13.7)

### Environment Configuration

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
2. Configure your API keys in `.env` (never commit this file to version control).

### Running the App

```bash
# Fetch dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run unit and widget tests
flutter test

# Run application
flutter run
```

## License

Private and confidential. All rights reserved.
