---
title: Support & FAQ - OnCall Scribe
---

# Support & FAQ

## Getting Started

### How do I create a triage record?
Tap the **+** button in the top-right corner of the main screen. Paste a triage message into the text field or tap "Paste from Clipboard." The app will parse the message into structured fields. Review and edit the parsed fields, add your clinical advice and disposition, then tap Save.

### How do I edit or delete a record?
Long-press on any record card to open the context menu. From there you can edit, change priority, or delete the record. You can also tap a record to view its details, then use the Edit button in the toolbar.

## AI Parsing

### Why isn't AI parsing working?
On-device AI parsing requires:
- **iPhone 15 Pro or later** (A17 Pro chip or newer)
- **iOS 18.1 or later**
- **Apple Intelligence enabled** in Settings > Apple Intelligence & Siri

If these requirements aren't met, the app automatically falls back to a regex-based parser that handles most common message formats.

### Is my data sent to a server for AI parsing?
No. All AI parsing uses Apple Foundation Models running entirely on your device. No message content is ever sent to any server.

## Data & Privacy

### Where is my data stored?
All data is stored locally on your iPhone. Nothing is stored on any server or cloud service.

### Does the app sync across devices?
No. OnCall Scribe does not use iCloud or any cloud sync. Data exists only on the device where it was created. This is a deliberate design choice for privacy and HIPAA compliance.

### How do I back up my data?
Go to Settings (gear icon) and tap "Export All Data (JSON)." This creates a JSON file containing all your records that you can save to Files, send via AirDrop, or store however you prefer.

### Can I use this app in airplane mode?
Yes. OnCall Scribe makes zero network calls and functions fully offline.

## Features

### How do I change my specialty?
Go to Settings (gear icon) and tap your current specialty under "Your Information." Select your new specialty from the picker. This customizes the parser instructions and available fields for your practice.

### How do I export records for shift handoff?
Tap the export icon (share button) in the toolbar. Choose a date range or manually select records, then tap "Share Export" to send the formatted triage log via the iOS share sheet.

### How do I enable Face ID / Touch ID?
Go to Settings > Security and toggle "App Lock" on. You'll be prompted to authenticate to enable the feature. Once enabled, the app will require biometric authentication or your device passcode when returning from the background.

### How do I filter records?
Tap the filter icon in the search bar. You can filter by date range, priority level, disposition type, follow-up status, and attending doctor. Active filters are shown with a badge on the filter icon.

## Important Notices

### Does this app replace EMR documentation?
No. OnCall Scribe is a personal documentation and organization tool for on-call triage messages. It does not interface with any Electronic Medical Record (EMR) system and should not be considered a substitute for proper medical documentation in your institution's EMR.

### Is this app HIPAA compliant?
OnCall Scribe is designed with HIPAA-conscious principles — all data stays on your device with no data collection or transmission. However, it is your responsibility to ensure that any exported records are handled in compliance with your institution's HIPAA policies. See our [Privacy Policy](privacy.md) for details.

## Contact & Support

For bug reports, feature requests, or questions:

- [Open an issue on GitHub](https://github.com/gyndok/OnCallScribe/issues)

---

*OnCall Scribe is a documentation tool and does not provide medical advice, diagnosis, or treatment recommendations.*
