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

    @Guide(description: "Date of birth in MM/DD/YYYY format (four-digit year). If the source has a two-digit year, convert it: YY <= 25 becomes 20YY (e.g., 01 → 2001), YY > 25 becomes 19YY (e.g., 97 → 1997).")
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

    /// Parses a date string, properly handling two-digit years.
    /// - YY <= 25 → 20YY (e.g., 25 → 2025, 01 → 2001)
    /// - YY > 25 → 19YY (e.g., 97 → 1997, 85 → 1985)
    static func parseDateWithTwoDigitYearSupport(_ dateString: String) -> Date? {
        // Parse the date string into components
        let separators = CharacterSet(charactersIn: "/-")
        let components = dateString.components(separatedBy: separators)

        guard components.count == 3,
              let month = Int(components[0]),
              let day = Int(components[1]),
              var year = Int(components[2]) else {
            return nil
        }

        // Handle two-digit years
        if year < 100 {
            if year <= 25 {
                year = 2000 + year  // 00-25 → 2000-2025
            } else {
                year = 1900 + year  // 26-99 → 1926-1999
            }
        }

        // Validate ranges
        guard month >= 1 && month <= 12,
              day >= 1 && day <= 31,
              year >= 1900 && year <= Calendar.current.component(.year, from: Date()) else {
            return nil
        }

        // Create date from components
        var dateComponents = DateComponents()
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.year = year

        return Calendar.current.date(from: dateComponents)
    }
}

// MARK: - AI Message Parser (with Foundation Models)

final class AIMessageParser {
    static let shared = AIMessageParser()

    private var session: LanguageModelSession?
    private var currentSpecialty: MedicalSpecialty?
    private var _isAvailable: Bool?

    private init() {}

    var isAvailable: Bool {
        if let cached = _isAvailable {
            return cached
        }
        // Check synchronously but safely
        let availability = SystemLanguageModel.default.availability
        _isAvailable = (availability == .available)
        return _isAvailable ?? false
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

    private func setupSession(for specialty: MedicalSpecialty) {
        // Reset session if specialty changed
        if currentSpecialty != specialty {
            session = nil
        }

        guard session == nil else { return }

        currentSpecialty = specialty

        let baseInstructions = specialty.parserInstructions + """

            Message format is typically: DR [DOCTOR] [PATIENT NAME] [PHONE] DOB [DATE] [COMPLAINT]

            Patient names usually appear after the doctor's name and before the phone number.
            Look for patterns like "PATIENT NAME:", "PT:", or names in ALL CAPS.
            Names may be 2-3 words (First Last or First Middle Last).
            """

        session = LanguageModelSession(instructions: baseInstructions)
    }

    func parse(_ rawMessage: String, specialty: MedicalSpecialty = .other) async throws -> ParsedTriageMessage {
        guard isAvailable else {
            throw AIParserError.modelUnavailable
        }

        setupSession(for: specialty)

        guard let session = session else {
            throw AIParserError.modelUnavailable
        }

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

    /// Parses a date string, properly handling two-digit years.
    static func parseDateWithTwoDigitYearSupport(_ dateString: String) -> Date? {
        let separators = CharacterSet(charactersIn: "/-")
        let components = dateString.components(separatedBy: separators)

        guard components.count == 3,
              let month = Int(components[0]),
              let day = Int(components[1]),
              var year = Int(components[2]) else {
            return nil
        }

        // Handle two-digit years: <= 25 → 20YY, > 25 → 19YY
        if year < 100 {
            year = year <= 25 ? 2000 + year : 1900 + year
        }

        guard month >= 1 && month <= 12,
              day >= 1 && day <= 31,
              year >= 1900 && year <= Calendar.current.component(.year, from: Date()) else {
            return nil
        }

        var dateComponents = DateComponents()
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.year = year

        return Calendar.current.date(from: dateComponents)
    }
}

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
