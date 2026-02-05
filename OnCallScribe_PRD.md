# PRODUCT REQUIREMENTS DOCUMENT: OnCall Scribe

**Version:** 1.0  
**Date:** February 5, 2026  
**Author:** Geffrey Klein, MD  
**Status:** Draft  
**Platform:** iOS (iPhone) — Native SwiftUI

---

## 1. Executive Summary

OnCall Scribe is a native iOS application designed for on-call physicians to capture, organize, search, and share triage messages received during call shifts. The app addresses the universal problem faced by on-call doctors: inbound text messages from answering services arrive as unstructured, poorly formatted text blobs that are difficult to reference, search, or document after the fact.

The physician copies an incoming triage message, pastes it into the app, and OnCall Scribe intelligently parses the message into structured fields (patient name, DOB, callback number, attending physician, chief complaint). The physician then adds their clinical advice, disposition, and any notes. All records are stored locally on-device with full CRUD functionality, searchable by any field, and exportable via the iOS share sheet for end-of-shift handoff documentation.

All data is stored exclusively on-device using SwiftData to eliminate HIPAA compliance concerns associated with cloud storage or third-party servers. No data ever leaves the device except when the user explicitly exports via the share sheet.

---

## 2. Problem Statement

### 2.1 User Pain Points

- On-call triage messages arrive as unstructured text blobs via SMS with inconsistent formatting, abbreviations, missing spaces, and concatenated fields
- No systematic way to log clinical advice given during phone triage, creating medicolegal exposure
- End-of-shift handoff requires manually reconstructing which patients were seen, what advice was given, and what follow-up is needed
- Searching prior call records (e.g., "Did I talk to this patient last weekend?") requires scrolling through hundreds of text messages
- Existing EHR systems do not accommodate phone triage documentation in a quick, mobile-friendly way

### 2.2 Target User

On-call physicians (OBGYN, family medicine, internal medicine, pediatrics, or any specialty using answering service triage) who receive patient callback messages via text and need a fast, HIPAA-conscious way to document their clinical encounters during call shifts.

### 2.3 Sample Input Message

The following is a real-world example of the type of message the app must parse:

```
DR LABERGE PATIENT NAME REDACTED. ,§713-854-9439,,DOB:06/30/1993NOT OBCONCERNS FOR MASTITIST,SEVEREPAIN ,POST PARTUM 1WKS,--
```

Note the inconsistent spacing, comma-delimited fields, special characters (§), missing delimiters between fields, misspellings, and lack of standardized structure. The parser must handle this gracefully.

---

## 3. Goals and Success Metrics

### 3.1 Primary Goals

1. Enable physicians to capture and document on-call triage encounters in under 30 seconds per message
2. Intelligently parse unstructured triage messages into searchable, structured records
3. Provide full-text and field-specific search across all historical records
4. Support end-of-shift export of records for handoff documentation via share sheet
5. Maintain strict local-only data storage for HIPAA compliance

### 3.2 Success Metrics

- Time to document: < 30 seconds from paste to saved record
- Parse accuracy: > 85% correct field extraction on first attempt (user can edit)
- Search latency: < 500ms for any query across up to 10,000 records
- Export generation: < 3 seconds for a full weekend shift compilation
- Zero data transmitted off-device (verifiable by network audit)

---

## 4. Features and Requirements

### 4.1 Message Capture & Parsing

This is the core interaction: the physician copies a text message, opens the app, and pastes it.

**Input:** Single large text field with a "Paste from Clipboard" convenience button.

**Smart Parser:** On paste, the app runs a local parsing engine that attempts to extract the following fields from the unstructured text:

| Field | Type | Parsing Strategy |
|-------|------|-----------------|
| Attending Doctor | String | Look for "DR" or "DR." prefix followed by surname |
| Patient Name | String | Text following doctor name, before phone/DOB patterns |
| Callback Number | Phone | Regex for phone patterns: (###) ###-####, ###-###-####, with optional § prefix |
| Date of Birth | Date | Look for "DOB" or "DOB:" followed by date in MM/DD/YYYY or similar formats |
| OB Status | Bool/String | Check for "OB", "NOT OB", "POSTPARTUM", "PREGNANT", gestational age patterns |
| Chief Complaint | String | Remaining text after known fields extracted; normalize spacing and punctuation |

**Editable Fields:** After parsing, all fields are displayed in an editable form so the physician can correct any parsing errors before saving.

**Fallback:** If parsing fails or is uncertain, dump the entire raw text into the Chief Complaint field and leave other fields blank for manual entry. Never silently discard text.

### 4.2 Physician Documentation Fields

After the parsed triage data is displayed, the physician adds their clinical response:

- **My Advice / Plan:** Free-text field for the physician's clinical recommendation (e.g., "Start warm compresses, ibuprofen 600mg q6h, call back if fever > 101.5")
- **Disposition:** Picker with common options — "Advised home care", "Sent to ER/L&D", "Scheduled office visit", "Called in Rx", "Referred to specialist", "Other (free text)"
- **Callback Completed:** Toggle (yes/no) with optional timestamp
- **Follow-up Needed:** Toggle with optional free-text note
- **Priority/Urgency:** Segmented control — Routine / Urgent / Emergent
- **Tags:** Optional free-text tags for custom categorization (e.g., "mastitis", "postpartum", "medication question")

### 4.3 Auto-Generated Metadata

- **Record ID:** Auto-generated UUID
- **Date & Time Received:** Auto-captured at time of paste/creation
- **Date & Time Saved:** Auto-captured when record is saved
- **On-Call Physician:** Defaults to the physician's name from Settings (user-configurable); editable per record if covering for another provider
- **Last Modified:** Updated on any edit

### 4.4 CRUD Operations

**Create:** New record from pasted message or manual entry. The "+" button should be prominently accessible from the main list view. A blank form option should be available for cases where the physician wants to manually document a call without a text message.

**Read:** Main list view shows all records in reverse chronological order. Each row displays: date/time, patient name, chief complaint snippet (first ~50 characters), and priority badge. Tapping a row opens the full record detail view.

**Update:** All fields remain editable after save. The record tracks a "last modified" timestamp. An edit history is not required for v1 but the data model should not preclude adding it later.

**Delete:** Swipe-to-delete with confirmation alert. Deleted records are permanently removed (no recycle bin in v1). Confirmation text: "This will permanently delete this triage record. This cannot be undone."

### 4.5 Search & Filtering

The search system must support both quick full-text search and advanced field-specific filtering.

**Global Search Bar:** Persistent search bar at the top of the main list view. Searches across all text fields (patient name, doctor name, chief complaint, advice, tags, disposition). Results update as the user types (debounced at 300ms).

**Advanced Filters (accessible via filter icon):**

- Date range picker (start date – end date)
- Attending doctor (dropdown of known doctors from records)
- On-call physician (dropdown)
- Priority level (Routine / Urgent / Emergent)
- Disposition type
- OB status
- Follow-up needed (yes/no)

Filters should be combinable (AND logic). Active filters should be visually indicated with a badge on the filter icon.

### 4.6 Export & Share Sheet

The export system generates formatted summaries of selected records for handoff documentation.

**Selection:** User can select records for export by:

- Date range (most common: "this weekend", "last 24 hours", custom range)
- Manual multi-select from the list view
- Current search/filter results ("Export all matching records")

**Export Format:** A clean, readable text document structured as:

```
ON-CALL TRIAGE LOG
Dr. Geffrey Klein | February 1–2, 2026 | 12 encounters

---
ENCOUNTER 1 | 02/01/2026 10:47 PM | URGENT
Patient: Jane Doe | DOB: 06/30/1993
Attending: Dr. LaBerge | Callback: 713-854-9439
OB Status: Not OB | Postpartum 1 week
Chief Complaint: Concerns for mastitis, severe pain
Advice: Start warm compresses, ibuprofen 600mg q6h...
Disposition: Advised home care
Follow-up: Yes — Recheck in office Monday AM
---
```

**Share Sheet Destinations:** Standard iOS share sheet supporting: Messages (iMessage/SMS), Mail, Copy to clipboard, Save to Files, AirDrop, and any third-party apps the user has configured (e.g., Notes, Word, Google Docs).

**File Formats:** Plain text (.txt) as default. Future versions may add PDF export.

---

## 5. Technical Architecture

### 5.1 Platform & Framework

- iOS 17+ (iPhone only for v1; iPad layout not required)
- SwiftUI for all UI
- Swift 5.9+ with @Observable macro (Observation framework)
- Xcode 15+ build target

### 5.2 Data Storage

**Primary:** SwiftData (Apple's native persistence framework, successor to Core Data)

- All data stored in the app's local sandbox
- No CloudKit sync, no iCloud backup of database (explicitly opt out)
- No network calls whatsoever — the app should function fully in airplane mode
- Database file stored in Application Support directory with iOS data protection (NSFileProtectionComplete)

**Data Model — TriageRecord:**

| Property | Type | Required | Notes |
|----------|------|----------|-------|
| id | UUID | Auto | Primary key, auto-generated |
| rawMessage | String | Yes | Original pasted text, never modified |
| dateReceived | Date | Auto | Timestamp at record creation |
| dateSaved | Date | Auto | Timestamp when first saved |
| lastModified | Date | Auto | Updated on every edit |
| attendingDoctor | String? | No | Parsed from message |
| patientName | String? | No | Parsed from message |
| callbackNumber | String? | No | Formatted phone number |
| dateOfBirth | Date? | No | Parsed DOB |
| obStatus | String? | No | "OB", "Not OB", "Postpartum Xwks", etc. |
| chiefComplaint | String? | No | Parsed or full raw text fallback |
| advice | String? | No | Physician's documented plan |
| disposition | String? | No | From picker or free text |
| priority | Priority | Default: Routine | Enum: routine, urgent, emergent |
| callbackCompleted | Bool | Default: false | |
| callbackTime | Date? | No | When callback was made |
| followUpNeeded | Bool | Default: false | |
| followUpNote | String? | No | Free text follow-up details |
| tags | [String] | Default: [] | User-defined tags |
| onCallPhysician | String | Yes | From Settings, editable per record |

### 5.3 Message Parsing Engine

The parser is a critical component and must be resilient to the wide variety of message formats from different answering services. Implementation strategy:

1. **Normalize input:** Strip special characters (§, --, extra commas), normalize whitespace, uppercase for pattern matching
2. **Extract doctor name:** Regex for `/DR\.?\s+([A-Z]+)/` at start of message
3. **Extract phone number:** Regex for common US phone patterns, strip non-numeric decorators
4. **Extract DOB:** Regex for `/DOB:?\s*(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})/`
5. **Extract OB status:** Pattern match for "OB", "NOT OB", "POSTPARTUM", "PP", gestational age patterns (e.g., "32WKS", "32 WEEKS")
6. **Extract patient name:** Heuristic — text between doctor name and first recognized field (phone, DOB)
7. **Remaining text becomes chief complaint:** Clean up, normalize spacing, fix obvious abbreviations

The parser should be implemented as a standalone, testable Swift class (MessageParser) with unit tests covering at least 10 real-world message formats. Parsing should happen synchronously on paste — performance target is < 50ms.

### 5.4 Project Structure

```
OnCallScribe/
  App/
    OnCallScribeApp.swift
    ContentView.swift
  Models/
    TriageRecord.swift
    Priority.swift
    Disposition.swift
  Views/
    RecordListView.swift
    RecordDetailView.swift
    RecordFormView.swift        // shared create/edit form
    SearchFilterView.swift
    ExportView.swift
    SettingsView.swift
  Managers/
    MessageParser.swift
    ExportManager.swift
    DataManager.swift
  Resources/
    Assets.xcassets
  Tests/
    MessageParserTests.swift
    ExportManagerTests.swift
```

---

## 6. User Interface Design

### 6.1 Navigation

Simple NavigationStack-based architecture. No tab bar — the app's primary function is linear (list → detail) with a settings gear icon in the toolbar.

### 6.2 Screen Flow

1. **Record List (home screen):** Reverse-chronological list with search bar, filter button, and "+" new record button. Each row shows date/time, patient name (or "Unknown Patient"), chief complaint snippet, and colored priority dot (green/yellow/red).
2. **New Record / Paste View:** Large text area with "Paste from Clipboard" button. On paste, shows parsed fields in editable form below. Physician documentation fields follow. Save button at bottom.
3. **Record Detail View:** Full read view of all fields. Edit button in toolbar to switch to edit mode. Delete button with confirmation.
4. **Search & Filter:** Sheet/modal with date range pickers and filter dropdowns. "Apply" button returns to filtered list.
5. **Export View:** Date range selector, preview of records to export, "Share" button invoking iOS share sheet.
6. **Settings:** On-call physician name (persisted in UserDefaults), app version info, and option to export all data as JSON backup.

### 6.3 Design Principles

- **Speed over polish:** The user is on-call and possibly exhausted. Every interaction should minimize taps.
- **One-handed usability:** All primary actions reachable with thumb on iPhone.
- **Dark mode support:** On-call work often happens at night.
- **Large tap targets:** Minimum 44pt touch targets per Apple HIG.
- **System fonts and colors:** Use iOS system styling for familiarity and accessibility.

---

## 7. HIPAA and Privacy Considerations

This app is designed specifically to avoid HIPAA-regulated data transmission:

1. **No network access:** The app makes zero network calls. No analytics, no crash reporting, no telemetry. It should be possible to verify this by running the app with airplane mode on — full functionality is expected.
2. **No cloud sync:** SwiftData is configured without CloudKit. iCloud backup of the app's data container should be disabled via the appropriate Info.plist setting.
3. **On-device encryption:** Leverage iOS file protection (NSFileProtectionComplete) so the database is encrypted when the device is locked.
4. **Export is user-initiated:** Data only leaves the device when the user explicitly taps Share. The app never transmits data autonomously.
5. **No third-party SDKs:** No Firebase, no analytics, no ad networks, no crash reporters. Zero third-party dependencies beyond Apple frameworks.
6. **App Lock (v1 stretch goal):** Optional Face ID / Touch ID gate on app launch for additional security.

While this architecture does not require a Business Associate Agreement (BAA) since no data is transmitted to any third party, it is the physician's responsibility to ensure that any exported records are handled in compliance with their institution's HIPAA policies.

---

## 8. Development Phases

### 8.1 Phase 1 — MVP (Target: Build in 1–2 Claude Code sessions)

- Message paste and basic parsing (doctor name, phone, DOB, chief complaint)
- Physician advice and disposition fields
- SwiftData persistence with CRUD
- List view with basic search
- Simple text export via share sheet
- Settings screen with on-call physician name

### 8.2 Phase 2 — Enhanced Parsing & Filtering

- Advanced parser handling more message formats and edge cases
- OB status parsing and gestational age extraction
- Advanced filter UI (date range, doctor, priority, disposition)
- Tags system
- Improved export formatting with date range selection

### 8.3 Phase 3 — Polish & Hardening

- Face ID / Touch ID app lock
- JSON full-data backup and restore
- Unit test suite for MessageParser (10+ test cases)
- Accessibility audit (VoiceOver, Dynamic Type)
- Dark mode visual polish
- App icon and launch screen

### 8.4 Future Considerations (v2 and Beyond)

**High Priority — Clinical Value:**

- **Callback Reminders:** Set local notifications to follow up with a patient in X hours. Integrates with iOS notification system. Addresses medicolegal follow-up documentation concerns.
- **Quick Response Templates:** Pre-saved advice snippets for common scenarios (mastitis care, postpartum bleeding instructions, medication questions). Reduces documentation time and ensures consistent advice.
- **Shift Summary Dashboard:** Statistics view showing total calls, priority breakdown, calls by hour, pending follow-ups. Useful for shift handoff and personal tracking.
- **Home Screen Widgets:** WidgetKit integration showing pending follow-ups count, quick "new record" button, or recent activity summary.

**Medium Priority — Enhanced Documentation:**

- **Voice Memo Attachment:** Record audio notes and attach to a triage record. Useful for complex cases or when typing is impractical.
- **Photo Attachments:** Attach images to records (patient-sent photos of rashes, wounds, etc.). Store in app sandbox with record association.
- **Shift Handoff Mode:** Generate structured handoff notes for the incoming on-call physician. Highlight pending follow-ups, unresolved issues, and high-priority patients.
- **PDF Export:** Professional-looking PDF export with optional clinic branding/letterhead. More suitable for official documentation than plain text.

**Lower Priority — Platform Integration:**

- **Apple Watch Complication:** Show pending follow-up count at a glance. Quick access to recent records.
- **Siri Shortcuts Integration:** "Hey Siri, log a triage call" to quickly open new record form.
- **iPad Layout Optimization:** Multi-column layout for iPad, drag-and-drop support.
- **Integration with Answering Service APIs:** If available, auto-import messages from specific answering services.

**Research/Experimental:**

- **On-device ML Model:** Train a custom model on user's message patterns for improved parsing accuracy over time.
- **Call Log Integration:** Detect when a phone call ends and prompt to create a triage record.

---

## 9. Claude Code Build Instructions

Place this PRD file in the project root directory. Then in Claude Code:

```
Read OnCallScribe_PRD.md and build Phase 1 MVP. Follow the technical architecture, 
data model, project structure, and UI specifications exactly. Start with the data 
model and parser, then build the views. Ensure it compiles and runs in Xcode immediately.
```

--- 

*End of Document*
