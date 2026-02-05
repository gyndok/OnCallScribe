---
title: Privacy Policy - OnCall Scribe
---

# Privacy Policy

**Effective Date:** February 5, 2026
**Last Updated:** February 5, 2026

## Summary

OnCall Scribe stores all data exclusively on your device. We do not collect, transmit, or have access to any of your data.

## Data Storage

- All triage records, settings, and preferences are stored locally on your iPhone using Apple's SwiftData framework.
- Data is stored in the app's sandboxed container with iOS file protection (NSFileProtectionComplete), meaning the database is encrypted when your device is locked.
- No data is stored on any external server, cloud service, or third-party platform.

## Data Collection

OnCall Scribe collects **no data whatsoever**:

- **No personal information** is collected or transmitted.
- **No usage analytics** are gathered.
- **No crash reports** are sent to any server.
- **No telemetry** of any kind is implemented.
- **No cookies or tracking technologies** are used.
- The app makes **zero network calls**. It functions fully in airplane mode.

## Third-Party Services

OnCall Scribe uses **no third-party SDKs, libraries, or services**:

- No Firebase
- No Google Analytics
- No crash reporting services
- No advertising networks
- No social media integrations

## AI Processing

OnCall Scribe uses Apple Foundation Models for intelligent message parsing:

- All AI processing occurs **entirely on your device**.
- No message content is sent to Apple, Anthropic, OpenAI, or any other service.
- AI parsing requires a compatible device (iPhone 15 Pro or later) with Apple Intelligence enabled.
- If AI parsing is unavailable, the app falls back to a local regex-based parser.

## Data Export

Data only leaves your device when **you explicitly choose** to export or share:

- Exporting generates a formatted text summary that you share via the iOS share sheet.
- You control what records are exported and where they are sent.
- The app never transmits data autonomously.

## Biometric Authentication

- Face ID / Touch ID authentication is handled entirely by Apple's LocalAuthentication framework.
- Biometric data is managed by iOS and is never accessible to OnCall Scribe.

## HIPAA Considerations

OnCall Scribe is designed with HIPAA-conscious principles:

- No Protected Health Information (PHI) is transmitted to any third party.
- No Business Associate Agreement (BAA) is required since no data leaves the device.
- It is the physician's responsibility to ensure that any exported records are handled in compliance with their institution's HIPAA policies.
- We recommend enabling Face ID / Touch ID app lock for additional security.

## Children's Privacy

OnCall Scribe is designed for use by licensed medical professionals and is not intended for use by children under 17.

## Changes to This Policy

If we update this privacy policy, we will post the revised version on this page with an updated effective date. Since the app makes no network calls, policy changes cannot be pushed to existing users.

## Contact

For questions about this privacy policy:

- [Open an issue on GitHub](https://github.com/gyndok/OnCallScribe/issues)

---

*OnCall Scribe is a documentation tool and does not provide medical advice, diagnosis, or treatment recommendations.*
