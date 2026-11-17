# MediCrate

MediCrate is a cross-platform, offline-first personal health record and clinical management application built with Flutter.

---

## Overview

MediCrate empowers patients and families to securely organize, track, and export their comprehensive medical records—including consultations, active prescriptions, appointments, diagnostic lab reports, doctor profiles, hospital visits, and vital measurements—with a strict offline-first architecture and managed cloud synchronization.

---

## Key Features

- **Offline-First Persistence**: High-performance local storage powered by Hive. Records are cached and manipulated locally, ensuring zero-latency responsiveness and full functionality without active network connectivity.
- **Family Profile Management**: Manage multiple medical records across individual family members with dedicated profiles and archival protection.
- **Clinical Modules**:
  - **Consultations & Diagnoses**: Track medical visits, doctor recommendations, and clinical histories.
  - **Doctor & Hospital Directory**: Maintain verified contact details, departments, and linked visits.
  - **Appointments & Reminders**: Schedule upcoming appointments with local notification reminders.
  - **Active Medications**: Record dosage schedules, active courses, and intake logs.
  - **Diagnostic Lab Reports**: Store report metadata and file attachments.
  - **Vital Signs Tracking**: Log blood pressure, heart rate, temperature, blood glucose, weight, and SpO2 with interactive trend visualization.
- **Confidential Summary Export**: Client-side generation of formatted, confidential PDF medical summaries for clinical consultations.
- **Data Privacy & Security**: Device-level encryption, path-traversal sanitization for document attachments, and Row Level Security on the cloud backend.

---

## Technology Stack

- **Framework**: Flutter 3.50+ / Dart 3.14+ (SDK `^3.13.7`)
- **State Management**: [Flutter Riverpod](https://pub.dev/packages/flutter_riverpod) (v3.5.0) using modern `Notifier` and `AsyncNotifier` patterns
- **Routing**: [GoRouter](https://pub.dev/packages/go_router) (v18.1.3) with declarative navigation and authentication redirection guards
- **Local Persistence**: [Hive](https://pub.dev/packages/hive) & [Hive Flutter](https://pub.dev/packages/hive_flutter)
- **Cloud Backend**: [Supabase](https://pub.dev/packages/supabase_flutter) (`supabase_flutter` v2.18.3) providing Auth, PostgreSQL database with RLS, and Cloud Storage
- **Notifications**: `flutter_local_notifications` with timezone-aware scheduling
- **Charts & Document Generation**: `fl_chart`, `pdf`, and `printing`
- **Launcher Icons**: `flutter_launcher_icons` (v0.14.4)

---

## Architecture Overview

MediCrate follows a modular, layered architecture:

```
lib/
├── app/                  # Application root, routing configuration, and themes
├── core/                 # Cross-cutting concerns (constants, exceptions, security, sync)
│   ├── constants/        # Theme tokens, typography, spacing, semantic colors
│   ├── security/         # Cryptographic helpers, path sanitization
│   ├── storage/          # Local Hive boxes and remote Supabase storage services
│   ├── supabase/         # Supabase client configuration and initialization
│   └── sync/             # Offline queue, foreground sync, and rollout management
├── features/             # Domain modules (Appointments, Consultations, Doctors,
│                         # Hospitals, Medicines, Profile, Reports, Vitals, Auth)
│   ├── data/             # Models, Hive repositories, Supabase data sources
│   └── presentation/     # UI screens, Riverpod providers, and module widgets
└── shared/               # Shared reusable widgets, dialogs, forms, and attachments
```

---

## Offline-First Functionality

1. **Immediate Local Mutation**: When a user creates or updates a record, it is immediately written to local Hive storage. The UI updates instantly without blocking on network requests.
2. **Persistent Mutation Queue**: Offline actions are tracked in a persistent local queue.
3. **Optimistic Local Reads**: All screen queries read directly from local Hive boxes, guaranteeing full read/write usability in offline environments.

---

## Authentication & Security Architecture

- **Supabase Authentication**: User authentication is handled through Supabase Auth (Email/Password and OAuth exchange).
- **Client Key Isolation**: The application strictly uses the public `SUPABASE_ANON_KEY`. The privileged `service_role` key is **never** embedded or used in client code.
- **Row Level Security (RLS)**: Every database table in PostgreSQL enforces strict RLS policies ensuring that users can only access and modify their own records (`auth.uid() = user_id`).
- **Secure Storage**: Authentication session tokens and critical credentials are encrypted using `flutter_secure_storage`.
- **Sanitized Logging**: Application loggers automatically redact sensitive tokens, passwords, and clinical identifiers from debug output.

---

## Synchronization Architecture & Current Rollout Status

MediCrate uses a controlled, foreground-only synchronization model:

- **Foreground Synchronization**: Synchronization runs during foreground app usage via manual triggers or controlled reconciliation.
- **Background Sync Disabled**: Background synchronization via `workmanager` is **not enabled**; legacy background worker tasks have been cancelled to ensure absolute data consistency and prevent unmonitored background battery drain.
- **Rollout & Safety Controls (`SyncRolloutConfig`)**:
  - **Global Rollout Pause**: Central switch to halt all synchronization immediately.
  - **Authorized Tester Whitelist**: UUID-based gating for experimental sync features.
  - **User Self Opt-Out**: Local preference allowing users to disable cloud synchronization.
  - **Client Emergency Kill Switch**: Client-side circuit breaker halting sync on repeated errors.

---

## Project Directory Structure

```
medi_crate/
├── android/              # Native Android configuration, Gradle wrapper, and icons
├── assets/
│   ├── certs/            # Public root certificates (SSL.com Root CA)
│   ├── icon/             # Generated launcher icons (app_icon.png, adaptive foreground)
│   ├── icons/            # Vector assets (SVG icons)
│   └── logo/             # Master logo asset (icon.jpg)
├── docs/                 # Architectural reports, migration guides, and gap analysis
├── ios/                  # Native iOS project, AppIcon asset catalog, Runner scheme
├── lib/                  # Dart application source code
├── supabase/             # PostgreSQL database migrations, seed data, and SQL tests
├── test/                 # Unit, widget, and integration test suites
├── pubspec.yaml          # Package configuration and dependencies
└── README.md             # Project documentation
```

---

## Prerequisites

- **Flutter SDK**: `>= 3.47.0` (Recommended: `3.50.0` or later)
- **Dart SDK**: `>= 3.13.7` (Recommended: `3.14.0` or later)
- **Android Studio / Android SDK**: For Android builds (compileSdk 36, minSdk 24)
- **Xcode**: For iOS/macOS builds (macOS host required)

---

## Installation & Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/jitheshks/medi_crate.git
   cd medi_crate
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

---

## Environment Configuration

1. Create a `.env` file in the project root by copying the template:
   ```bash
   cp .env.example .env
   ```

2. Configure your own Supabase project credentials in `.env`:
   ```env
   # Supabase Configuration
   SUPABASE_URL=https://your-project-id.supabase.co
   SUPABASE_ANON_KEY=your_supabase_anon_public_key_here

   # Google OAuth Web Client ID (Optional)
   GOOGLE_WEB_CLIENT_ID=your-google-web-client-id.apps.googleusercontent.com
   ```

> **Security Note:** Never commit `.env` or production credentials to version control. Only use the public anonymous key (`SUPABASE_ANON_KEY`) in client configurations.

### Setting Up a Supabase Project

To run MediCrate with your own cloud backend:
1. Create a project at [supabase.com](https://supabase.com).
2. Apply the database migrations located in [`supabase/migrations/`](supabase/migrations/) sequentially to set up the schema and RLS policies.
3. Optionally run [`supabase/seed.sql`](supabase/seed.sql) to seed authoritative medical department reference data.
4. Obtain your Project URL and Public Anon Key from the Supabase Project Dashboard (**Settings > API**).

---

## Running the Application

Launch on a connected device, emulator, or simulator:

```bash
flutter run
```

To run on a specific target:
```bash
flutter run -d chrome      # Web
flutter run -d android     # Android device or emulator
flutter run -d ios         # iOS Simulator
```

---

## Running Tests & Static Analysis

Execute static analysis and verification:

```bash
# Static analysis
flutter analyze

# Run unit and widget test suites
flutter test
```

---

## Building the Application

### Android (Debug APK)
```bash
flutter build apk --debug
```

### Android (Release Bundle)
```bash
flutter build appbundle --release
```

---

## Application Launcher Icons

MediCrate launcher icons are generated using `flutter_launcher_icons`:
- **Main Square Icon**: `assets/icon/app_icon.png` (1024 × 1024, RGB, solid `#FFFFFF` background, no alpha channel).
- **Android Adaptive Icon**: Foreground asset `assets/icon/adaptive_icon_foreground.png` with safe-area padding and `#FFFFFF` background color.
- Configured in `pubspec.yaml` under `flutter_launcher_icons`.

---

## Current Limitations & Development Status

- **Phase 3 Transition**: The application has completed isolation from legacy APIs and is transitioning to the unified Supabase-first persistence model.
- **Synchronization Rollout**: Synchronization operates strictly in controlled foreground mode. Automatic background synchronization via OS job schedulers is intentionally paused.

---

## License

Private and confidential. All rights reserved.
