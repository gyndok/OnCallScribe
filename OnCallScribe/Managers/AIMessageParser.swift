import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Generable Output Struct

@Generable
struct ParsedTriageMessage {
    // Universal fields
    @Guide(description: "The attending physician's last name, extracted from DR or DR. prefix. Return just the name without 'Dr.' prefix.")
    var attendingDoctor: String?

    @Guide(description: "The patient's full name, properly capitalized. Look for names after 'DR [DOCTOR]' or labeled as 'PATIENT NAME:', 'PT:', or 'NAME:'. Remove any labels. Format as 'First Last' with proper capitalization.")
    var patientName: String?

    @Guide(description: "The callback phone number, formatted as (###) ###-####. Remove any special characters like § before the number.")
    var callbackNumber: String?

    @Guide(description: "Date of birth exactly as written in the source, e.g. MM/DD/YYYY or MM/DD/YY. Do not convert two-digit years to four digits — leave them as-is.")
    var dateOfBirth: String?

    @Guide(description: "The patient's chief complaint and symptoms. Clean up abbreviations, fix misspellings, normalize spacing, convert to sentence case. Remove any field labels.")
    var chiefComplaint: String?

    // OBGYN-specific fields
    @Guide(description: "OB status if mentioned: 'OB', 'Not OB', 'Postpartum X weeks', 'Pregnant XX weeks'. Extract gestational age if present.")
    var obStatus: String?

    @Guide(description: "Gestational age if pregnant, in weeks+days format like '32w4d' or '32 weeks'.")
    var gestationalAge: String?

    // Pediatrics-specific fields
    @Guide(description: "Patient's age if pediatric, e.g. '3 years', '18 months', '6 weeks', 'newborn'.")
    var patientAge: String?

    // Psychiatry-specific fields
    @Guide(description: "Safety concerns mentioned: suicidal ideation (SI), homicidal ideation (HI), self-harm, overdose, etc.")
    var safetyConcerns: String?
}

// MARK: - Date Parsing Helper

extension ParsedTriageMessage {
    var dateOfBirthAsDate: Date? {
        guard let dobString = dateOfBirth else { return nil }

        // Parse with proper two-digit year handling
        return Self.parseDateWithTwoDigitYearSupport(dobString)
    }

    /// Parses a date string via the shared parser, which handles two-digit
    /// years, non-Gregorian device calendars, and impossible dates correctly.
    static func parseDateWithTwoDigitYearSupport(_ dateString: String) -> Date? {
        TriageDateParser.parseDate(dateString)
    }
}

// MARK: - AI Message Parser (with Foundation Models)

@MainActor
final class AIMessageParser {
    static let shared = AIMessageParser()

    private var _isAvailable = false

    private init() {}

    var isAvailable: Bool {
        // Only cache the affirmative result. Transient states (e.g. the model
        // still downloading at launch) are re-checked on every access so AI
        // parsing recovers once the model becomes ready, instead of staying
        // disabled for the rest of the session.
        if _isAvailable { return true }
        _isAvailable = (SystemLanguageModel.default.availability == .available)
        return _isAvailable
    }

    var statusMessage: String {
        let availability = SystemLanguageModel.default.availability
        switch availability {
        case .available:
            return "AI parsing active"
        case .unavailable(.deviceNotEligible):
            return "Device not supported (requires iPhone 15 Pro+)"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence not enabled"
        case .unavailable(.modelNotReady):
            return "AI model downloading..."
        default:
            return "AI parsing unavailable"
        }
    }

    private func makeSession(for specialty: MedicalSpecialty) -> LanguageModelSession {
        let baseInstructions = specialty.parserInstructions + """

            Message format is typically: DR [DOCTOR] [PATIENT NAME] [PHONE] DOB [DATE] [COMPLAINT]

            Patient names usually appear after the doctor's name and before the phone number.
            Look for patterns like "PATIENT NAME:", "PT:", or names in ALL CAPS.
            Names may be 2-3 words (First Last or First Middle Last).
            """

        return LanguageModelSession(instructions: baseInstructions)
    }

    func parse(_ rawMessage: String, specialty: MedicalSpecialty = .other) async throws -> ParsedTriageMessage {
        guard isAvailable else {
            throw AIParserError.modelUnavailable
        }

        // Each parse gets its own session: parses are independent single-turn
        // requests, and per-call sessions eliminate the data race of two
        // overlapping parses (or a mid-flight specialty change) sharing one
        // LanguageModelSession.
        let session = makeSession(for: specialty)

        let response = try await session.respond(
            to: "Parse this triage message:\n\n\(rawMessage)",
            generating: ParsedTriageMessage.self
        )

        return response.content
    }
}

#else

// MARK: - Fallback when FoundationModels is not available

struct ParsedTriageMessage {
    var attendingDoctor: String?
    var patientName: String?
    var callbackNumber: String?
    var dateOfBirth: String?
    var chiefComplaint: String?

    // Specialty-specific fields
    var obStatus: String?
    var gestationalAge: String?
    var patientAge: String?
    var safetyConcerns: String?

    var dateOfBirthAsDate: Date? {
        guard let dobString = dateOfBirth else { return nil }
        return Self.parseDateWithTwoDigitYearSupport(dobString)
    }

    /// Parses a date string via the shared parser, which handles two-digit
    /// years, non-Gregorian device calendars, and impossible dates correctly.
    static func parseDateWithTwoDigitYearSupport(_ dateString: String) -> Date? {
        TriageDateParser.parseDate(dateString)
    }
}

@MainActor
final class AIMessageParser {
    static let shared = AIMessageParser()

    private init() {}

    var isAvailable: Bool { false }

    var statusMessage: String {
        "AI parsing not available on this device"
    }

    func parse(_ rawMessage: String, specialty: MedicalSpecialty = .other) async throws -> ParsedTriageMessage {
        throw AIParserError.modelUnavailable
    }
}

#endif

// MARK: - Errors

enum AIParserError: LocalizedError {
    case modelUnavailable
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "On-device AI model is not available"
        case .parsingFailed(let reason):
            return "Failed to parse message: \(reason)"
        }
    }
}
