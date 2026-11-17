# MediCrate – Phase 3B.4.3.0: Runtime Screenshot & Screen Verification Checklist

> **Document Status:** Complete & Ready for User Execution  
> **Target System:** Running MediVault Reference Application  
> **Purpose:** Provides a structured, step-by-step checklist for the USER to inspect screens, expand dropdowns, test interactions, and capture reference screenshots from the operational MediVault app.  
> **Privacy Mandate:** **STRICTLY ZERO PII.** Never capture or submit screenshots containing real patient names, real email addresses, actual medical test results, or personal phone numbers. Use test or sample accounts only.  

---

## 1. Verification Strategy & Priority Tiers

Because source-code analysis cannot completely convey dynamic animations, platform dialog styling, or live server latency states, this checklist guides the user in verifying the operational MediVault reference implementation.

```
┌────────────────────────────────────────────────────────────────────────┐
│                   RUNTIME VERIFICATION PRIORITY TIERS                  │
├────────────────────────────────────────────────────────────────────────┤
│ TIER 1 (CRITICAL): Server-Loaded Reference Data & Dependent Pickers     │
│    • Medical Department Picker Sheet (MD1: Server Reference)          │
│    • Doctor Picker Sheet (Browse vs Inline Create View)                │
│    • Hospital Picker Sheet (Browse vs Inline Create View)              │
│    • Practicing Hospitals Multi-Select Checklist                       │
│    • Polymorphic Vitals Form & BMI Snapshot Log                        │
│                                                                        │
│ TIER 2 (HIGH): Clinical Encounter Forms & Dropdown Expansion          │
│    • New Consultation Form (Follow-up toggles & date/time pickers)     │
│    • Add/Edit Appointment Form (Status tabs & reschedule sheet)        │
│    • Upload Report Form (Category choice chips & file attachment)      │
│    • Add Medicine Form (Form chips, frequency chips, consult picker)   │
│    • Profile Form Dialog (Relationship & blood group dropdowns)        │
│                                                                        │
│ TIER 3 (MEDIUM): Aggregate Feeds & Analytical Dashboards               │
│    • Home Dashboard (Health score gauge, quick vitals, cards)          │
│    • Insights Screen (7 vitals trend charts, score breakdown)          │
│    • Timeline Screen (Longitudinal feed & date range filters)          │
│    • Doctor Summary Screen (Sanitized PDF preview & module filters)    │
│    • Global Search Sheet (Cross-entity live queries)                   │
│                                                                        │
│ TIER 4 (LOW): Application Shell, Authentication & Settings             │
│    • Splash & Sign In / Sign Up screens                                │
│    • Settings screens (Appearance theme selector, currency selector)   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Screen-by-Screen Inspection & Screenshot Checklist

### Screen 1: Medical Department Picker Sheet (TIER 1 - CRITICAL)
- **Route / Trigger:** Inside `NewConsultationScreen` or `AddEditAppointmentScreen` -> Tap **"Select Medical Department"** tile.
- **What to Inspect:**
  - Verify that the list loads dynamically from `GET /api/v1/medical-departments` (`MD1`).
  - Observe whether there is a search bar at the top of the bottom sheet.
  - Check whether `'OTHERS'` is positioned at the very bottom of the department list.
  - Verify that there is **NO "+ Add Department"** action (departments are a fixed server reference).
- **Interactive Test:**
  - Type `"Cardio"` in the search field; confirm real-time filtering to `"CARDIOLOGY"`.
  - Clear the search and scroll to the bottom.
- **Recommended Screenshot:**
  - `01_medical_department_picker_expanded.png` (Modal bottom sheet expanded, showing search field and top 5-6 departments).
- **Code Status:** `[SRC-VERIFIED]` in `medical_department_picker_sheet.dart#L16-L80`. Runtime capture confirms live backend department names.

---

### Screen 2: Doctor Picker Sheet (Browse vs. Create View) (TIER 1 - CRITICAL)
- **Route / Trigger:** Inside `NewConsultationScreen` -> Tap **"DOCTOR *"** selection field.
- **What to Inspect:**
  - **Browse Mode:** Verify list of existing doctors scoped to active profile.
  - Check the **"+ Add New Doctor"** action button at the top/bottom of the sheet.
  - Tap **"+ Add New Doctor"**; verify view toggles smoothly to `DoctorPickerCreateView` without popping the bottom sheet.
  - In `DoctorPickerCreateView`, check input fields: Doctor Name, Specialty, Phone, and Hospital affiliation picker.
- **Interactive Test:**
  - Enter test clinician name (e.g. `"Dr. Alan Turing"`, Specialty: `"Neurology"`).
  - Tap **"Save & Select"**; verify sheet closes and populates the consultation form with both `doctorId` and `"Dr. Alan Turing"`.
- **Recommended Screenshots:**
  - `02a_doctor_picker_browse_view.png` (List of existing clinicians with "+ Add New Doctor" button).
  - `02b_doctor_picker_inline_create_view.png` (Inline creation form inside the bottom sheet).
- **Code Status:** `[SRC-VERIFIED]` in `doctor_picker_sheet.dart#L10-L70`.

---

### Screen 3: Hospital Picker Sheet (Browse vs. Create View) (TIER 1 - CRITICAL)
- **Route / Trigger:** Inside `NewConsultationScreen` -> Tap **"HOSPITAL / CLINIC"** selection field.
- **What to Inspect:**
  - **Browse Mode:** Verify list of hospitals scoped to active profile.
  - Check the **"+ Add New Hospital"** button.
  - In `HospitalPickerCreateView`, check input fields: Facility Name, Facility Type dropdown, Location/Address, Phone.
  - Expand the **FACILITY TYPE** dropdown; verify options: `'Hospital'`, `'Clinic'`, `'Lab'`, `'Diagnostic Center'`.
- **Interactive Test:**
  - Select `'Diagnostic Center'`. Confirm dropdown closes and displays the selected value.
- **Recommended Screenshots:**
  - `03a_hospital_picker_browse_view.png` (Existing facilities list).
  - `03b_hospital_picker_type_dropdown_expanded.png` (Facility type dropdown expanded showing all 4 options).
- **Code Status:** `[SRC-VERIFIED]` in `hospital_picker_sheet.dart` and `hospital_form_fields.dart#L10-L70`.

---

### Screen 4: Practicing Hospitals Multi-Select Checklist (TIER 1 - CRITICAL)
- **Route / Trigger:** `DoctorsListScreen` -> Tap **"+ Add Doctor"** -> Tap **"HOSPITALS WHERE DOCTOR PRACTICES"**.
- **What to Inspect:**
  - Verify bottom sheet opens with a multi-select checkbox list of all saved hospitals for the profile.
  - Verify doctors can be affiliated with zero, one, or multiple hospitals simultaneously.
  - Check whether selected hospitals appear as chips or list tiles upon closing the sheet.
- **Recommended Screenshot:**
  - `04_doctor_practicing_hospitals_multiselect.png` (Multi-select sheet with checkboxes checked).
- **Code Status:** `[SRC-VERIFIED]` in `add_edit_doctor_screen.dart#L147-L155`.

---

### Screen 5: Vitals Selection & Client-Calculated BMI Log (TIER 1 - CRITICAL)
- **Route / Trigger:** `HomeScreen` -> Quick Create FAB -> **"Log Vitals"** (`AddMeasurementTypeScreen`).
- **What to Inspect:**
  - Verify the 7 vital cards in the selection grid: Blood Pressure, Blood Glucose, Heart Rate, SpO₂, Temperature, Respiratory Rate, Body Mass Index (BMI).
  - Tap **"Body Mass Index (BMI)"**; verify `AddMeasurementFormScreen` displays current profile height, weight, and calculated BMI value.
  - Check the prominent **"LOG CURRENT BMI"** button.
  - Tap **"LOG CURRENT BMI"**; verify snapshot is committed immediately to Hive without asking the user to manually enter a numeric value.
  - Tap **"Blood Glucose"**; verify **FASTING** and **RANDOM** choice chips render below the value input.
- **Recommended Screenshots:**
  - `05a_vital_types_grid.png` (7 vital cards on `AddMeasurementTypeScreen`).
  - `05b_bmi_calculated_snapshot_form.png` (BMI calculation view with "LOG CURRENT BMI" button).
  - `05c_glucose_context_chips.png` (Blood glucose form with Fasting/Random chips).
- **Code Status:** `[SRC-VERIFIED]` in `add_measurement_form_screen.dart` and `blood_glucose_input_field.dart`.

---

### Screen 6: Add / Edit Family Profile Dialog (TIER 2 - HIGH)
- **Route / Trigger:** Profile Screen -> **"Manage Family Profiles"** -> Tap **"+ Add Profile"** (`ProfileFormDialog`).
- **What to Inspect:**
  - Expand the **RELATIONSHIP** dropdown.
  - Verify that `'Self'` is **NOT** present in the options list (reserved for primary user profile).
  - Confirm options: `Father, Mother, Spouse, Son, Daughter, Brother, Sister, Grandfather, Grandmother, Guardian, Other`.
  - Select `'Other'`; verify an additional text field **"Specify Relationship"** immediately appears.
  - Expand the **GENDER** dropdown; confirm: `Male, Female, Others`.
  - Expand the **BLOOD GROUP** dropdown; confirm: `A+, A-, B+, B-, AB+, AB-, O+, O-`.
- **Recommended Screenshots:**
  - `06a_profile_relationship_dropdown_expanded.png` (Relationship dropdown menu expanded).
  - `06b_profile_blood_group_dropdown_expanded.png` (Blood group dropdown menu expanded).
- **Code Status:** `[SRC-VERIFIED]` in `profile_form_dialog.dart#L65-L75` and `profile_demographics_input_section.dart#L13-L22`.

---

### Screen 7: New Consultation Screen & Follow-up Controls (TIER 2 - HIGH)
- **Route / Trigger:** Quick Create FAB -> **"New Consultation"** (`NewConsultationScreen`).
- **What to Inspect:**
  - Check required fields: Visit Date, Doctor Name, Diagnosis.
  - Verify optional fields: Hospital Name, Department, Appointment Link, Fee / Amount.
  - Toggle the **"Follow-up Required"** switch; verify `FollowUpSection` expands, exposing:
    - Follow-up Date picker
    - Follow-up Time picker
    - Follow-up Notes field
- **Recommended Screenshot:**
  - `07_consultation_form_with_followup_expanded.png` (Full form showing selected doctor, hospital, and expanded follow-up fields).
- **Code Status:** `[SRC-VERIFIED]` in `new_consultation_screen.dart`.

---

### Screen 8: Upload Diagnostic Report Screen (TIER 2 - HIGH)
- **Route / Trigger:** Quick Create FAB -> **"Upload Report"** (`UploadReportScreen`).
- **What to Inspect:**
  - Check the **REPORT CATEGORY** choice chips:
    - `LAB TEST`, `IMAGING`, `PRESCRIPTION`, `DISCHARGE`, `CERTIFICATE`, `VACCINATION`, `REFERRAL`, `OTHER`.
  - Verify multiple attachments can be selected (PDF, PNG, JPG).
  - Check the **EMBEDDED EXPENSE** section (Cost amount, currency, Paid/Pending toggle).
- **Recommended Screenshot:**
  - `08_upload_report_form_chips.png` (Category chips and attachment upload area).
- **Code Status:** `[SRC-VERIFIED]` in `upload_report_screen.dart` and `report_category_chips.dart`.

---

### Screen 9: Add Medicine Form (TIER 2 - HIGH)
- **Route / Trigger:** Quick Create FAB -> **"Add Medicine"** (`AddEditMedicineScreen`).
- **What to Inspect:**
  - Check **FORM** choice chips: `Tablet, Capsule, Syrup, Inhaler, Injection, Cream, Drops, Other`.
  - Check **FREQUENCY** choice chips: `Once daily, Twice daily, Three times daily, As needed, Other`.
  - Check date range pickers (Start Date, End Date, or Ongoing).
  - Check **"LINK TO CONSULTATION"** picker tile.
- **Recommended Screenshot:**
  - `09_add_medicine_chips_selector.png` (Form chips and frequency chips visible).
- **Code Status:** `[SRC-VERIFIED]` in `medicine_chips_selector.dart#L5-L23`.

---

### Screen 10: Home Dashboard & Health Score Gauge (TIER 3 - MEDIUM)
- **Route / Trigger:** Bottom Navigation -> **Home** tab (`HomeScreen`).
- **What to Inspect:**
  - Active profile header with avatar, name, and relationship badge.
  - **Health Vault Completeness Score (0-100)** circular or linear gauge with progress bar.
  - **Quick Vitals Snapshot Grid:** BP, Glucose, Heart Rate, SpO₂, Temperature, BMI cards.
  - **Upcoming Appointments Card** and **Active Medications Card**.
- **Recommended Screenshot:**
  - `10_home_dashboard_overview.png` (Full dashboard screen with live profile loaded).
- **Code Status:** `[SRC-VERIFIED]` in `home_screen.dart`.

---

### Screen 11: Health Insights & Vitals Trend Curves (TIER 3 - MEDIUM)
- **Route / Trigger:** Bottom Navigation -> **Insights** tab (`InsightsScreen`).
- **What to Inspect:**
  - Health Vault Completeness Score breakdown (Vitals 40, Profile 20, Consults 20, Reports 20).
  - Vitals Overview Grid with status indicators (Normal, Elevated, Low).
  - Interactive vital trend line/bar charts (`fl_chart`).
  - Healthcare expense breakdown chart (Category, Doctor, Facility distributions).
- **Recommended Screenshot:**
  - `11_insights_vitals_trends.png` (Insights screen showing score and trend graph).
- **Code Status:** `[SRC-VERIFIED]` in `insights_screen.dart`.

---

### Screen 12: Doctor Summary Export Screen (TIER 3 - MEDIUM)
- **Route / Trigger:** Profile Screen -> **"Doctor Summary"** (`DoctorSummaryScreen`).
- **What to Inspect:**
  - Date Filter bar: `ALL TIME`, `LAST 30 DAYS`, `LAST 3 MONTHS`, `LAST 6 MONTHS`, `THIS YEAR`.
  - Module selection checklist: Consultations, Medicines, Vitals, Reports.
  - Prominent **"GENERATE SANITIZED SUMMARY (PDF)"** button.
  - Verify all fee/billing data is explicitly stripped from the generated document.
- **Recommended Screenshot:**
  - `12_doctor_summary_builder.png` (Screen showing selected date range and module checkboxes).
- **Code Status:** `[SRC-VERIFIED]` in `doctor_summary_screen.dart`.

---

### Screen 13: Longitudinal Health Timeline (TIER 3 - MEDIUM)
- **Route / Trigger:** Bottom Navigation -> **Timeline** tab (`TimelineScreen`).
- **What to Inspect:**
  - Category filter chips: `ALL`, `Consultations`, `Reports`, `Medicines`, `Measurements`, `Appointments`, `Expenses`, `Doctors`, `Hospitals`.
  - Date range dropdown button: `All Time`, `Last 7 Days`, `Last 30 Days`, `Last 3 Months`, `Last 6 Months`, `This Year`.
  - Connector-rail cards grouped chronologically by date.
- **Recommended Screenshot:**
  - `13_timeline_feed_with_filters.png` (Timeline screen showing category chips and day-grouped cards).
- **Code Status:** `[SRC-VERIFIED]` in `timeline_screen.dart`.

---

### Screen 14: Settings & Preferences (TIER 4 - LOW)
- **Route / Trigger:** Profile Screen -> Settings Icon (`SettingsScreen`).
- **What to Inspect:**
  - **Appearance Screen:** Theme mode options (`System Default`, `Light Mode`, `Dark Mode`).
  - **Currency Screen:** Currency selection (`INR`, `USD`, `EUR`, `GBP`, `AED`, `SAR`).
  - **Data & Sync Screen:** Display of local queue count and sync state.
- **Recommended Screenshot:**
  - `14_appearance_theme_settings.png` (Theme options screen).
- **Code Status:** `[SRC-VERIFIED]` in `appearance_settings_screen.dart`.

---

## 3. Submission Guidelines for User Screenshots

When providing screenshots after reviewing this checklist:
1. **Resolution:** Standard smartphone or emulator portrait screenshots (PNG or JPG).
2. **Naming:** Please name files according to the recommendations above (e.g. `01_medical_department_picker_expanded.png`).
3. **Location:** Place screenshots in `/home/blackhat/Documents/medi_crate/docs/screenshots/` or provide them directly in the conversation.
4. **Data Privacy Confirmation:** Verify that no real personal health information (PHI) or personal identifiable information (PII) is visible. Sample/fictional records (e.g. "Dr. Test", "City Clinic", "Jane Doe") should be used.
