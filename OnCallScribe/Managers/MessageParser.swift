import Foundation

struct ParsedMessage {
    var attendingDoctor: String?
    var patientName: String?
    var callbackNumber: String?
    var dateOfBirth: Date?
    var obStatus: String?
    var chiefComplaint: String?
}

/// Shared DOB parsing used by both the regex and AI parsers.
enum TriageDateParser {
    /// Fixed Gregorian calendar so DOBs are interpreted correctly regardless of
    /// the device's calendar setting (Buddhist, Japanese, etc.).
    static let gregorian = Calendar(identifier: .gregorian)

    /// Parses "M/D/YYYY" or "M-D-YY" style date strings.
    ///
    /// Two-digit years resolve to the most recent matching date that is not in
    /// the future: "26" is 2026 if that day has already occurred (a newborn),
    /// otherwise 1926. Impossible dates (e.g. 9/31) are rejected instead of
    /// rolling over to the next month.
    static func parseDate(_ dateString: String) -> Date? {
        let separators = CharacterSet(charactersIn: "/-")
        let components = dateString.components(separatedBy: separators)

        guard components.count == 3,
              let month = Int(components[0]),
              let day = Int(components[1]),
              let rawYear = Int(components[2]) else {
            return nil
        }

        let now = Date()
        let currentYear = gregorian.component(.year, from: now)

        func build(year: Int) -> Date? {
            var dateComponents = DateComponents()
            dateComponents.calendar = gregorian
            dateComponents.year = year
            dateComponents.month = month
            dateComponents.day = day
            guard year >= 1900, year <= currentYear,
                  dateComponents.isValidDate,
                  let date = gregorian.date(from: dateComponents),
                  date <= now else {
                return nil
            }
            return date
        }

        if rawYear < 100 {
            // Prefer the 2000s interpretation when it isn't in the future.
            return build(year: 2000 + rawYear) ?? build(year: 1900 + rawYear)
        }
        return build(year: rawYear)
    }
}

final class MessageParser {

    static let shared = MessageParser()

    private init() {}

    func parse(_ rawMessage: String) -> ParsedMessage {
        var result = ParsedMessage()

        // Normalize the input
        var text = normalizeText(rawMessage)
        let originalText = text

        // Extract doctor name
        if let doctor = extractDoctorName(from: text) {
            result.attendingDoctor = doctor.name
            text = doctor.remainingText
        }

        // Extract phone number
        if let phone = extractPhoneNumber(from: text) {
            result.callbackNumber = phone.number
            text = phone.remainingText
        }

        // Extract date of birth
        if let dob = extractDateOfBirth(from: text) {
            result.dateOfBirth = dob.date
            text = dob.remainingText
        }

        // Extract OB status
        if let ob = extractOBStatus(from: text) {
            result.obStatus = ob.status
            text = ob.remainingText
        }

        // Extract patient name (heuristic: text between doctor name and first recognized field)
        if let patientName = extractPatientName(from: originalText, doctor: result.attendingDoctor) {
            result.patientName = patientName
        }

        // Remaining text becomes chief complaint
        let complaint = cleanupChiefComplaint(text)
        if !complaint.isEmpty {
            result.chiefComplaint = complaint
        } else {
            // Fallback: use normalized original text
            result.chiefComplaint = cleanupChiefComplaint(normalizeText(rawMessage))
        }

        return result
    }

    // MARK: - Normalization

    private func normalizeText(_ text: String) -> String {
        var normalized = text

        // Replace special characters
        normalized = normalized.replacingOccurrences(of: "§", with: "")
        normalized = normalized.replacingOccurrences(of: "--", with: " ")
        normalized = normalized.replacingOccurrences(of: ",,", with: ",")

        // Normalize whitespace
        normalized = normalized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Doctor Name Extraction

    private func extractDoctorName(from text: String) -> (name: String, remainingText: String)? {
        let pattern = #"^DR\.?\s+([A-Z][A-Z'-]+)"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let nameRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        let doctorName = String(text[nameRange])
        let fullMatchRange = Range(match.range, in: text)!
        let remainingText = String(text[fullMatchRange.upperBound...]).trimmingCharacters(in: .whitespaces)

        return (formatDoctorName(doctorName), remainingText)
    }

    private func formatDoctorName(_ name: String) -> String {
        // Capitalize properly: LABERGE -> LaBerge or Laberge
        let lowercased = name.lowercased()
        return lowercased.prefix(1).uppercased() + lowercased.dropFirst()
    }

    // MARK: - Phone Number Extraction

    private func extractPhoneNumber(from text: String) -> (number: String, remainingText: String)? {
        // Match various phone formats: 1##########, (###) ###-####, ###-###-####, ##########
        // The 11-digit leading-1 pattern must come first so a country code isn't
        // split into a wrong 10-digit number, and the digit lookarounds keep a
        // pattern from matching the middle of a longer digit run.
        let patterns = [
            #"(?<!\d)1[-.\s]?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}(?!\d)"#,
            #"(?<!\d)\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}(?!\d)"#,
            #"(?<!\d)\d{3}[-.\s]\d{3}[-.\s]\d{4}(?!\d)"#,
            #"(?<!\d)\d{10}(?!\d)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let matchRange = Range(match.range, in: text) else {
                continue
            }

            let phoneRaw = String(text[matchRange])
            let formattedPhone = formatPhoneNumber(phoneRaw)

            // Remove from text
            var remainingText = text
            remainingText.removeSubrange(matchRange)
            remainingText = remainingText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return (formattedPhone, remainingText)
        }

        return nil
    }

    private func formatPhoneNumber(_ raw: String) -> String {
        var digits = raw.filter { $0.isNumber }
        // Drop a leading US country code so 1-832-555-1234 formats as (832) 555-1234
        if digits.count == 11 && digits.hasPrefix("1") {
            digits.removeFirst()
        }
        guard digits.count == 10 else { return raw }

        let areaCode = digits.prefix(3)
        let middle = digits.dropFirst(3).prefix(3)
        let last = digits.suffix(4)

        return "(\(areaCode)) \(middle)-\(last)"
    }

    // MARK: - Date of Birth Extraction

    private func extractDateOfBirth(from text: String) -> (date: Date, remainingText: String)? {
        let pattern = #"DOB:?\s*(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let dateRange = Range(match.range(at: 1), in: text),
              let fullRange = Range(match.range, in: text) else {
            return nil
        }

        let dateString = String(text[dateRange])

        // Parse the date with proper two-digit year handling
        guard let date = parseDateWithTwoDigitYearSupport(dateString) else { return nil }

        var remainingText = text
        remainingText.removeSubrange(fullRange)
        remainingText = remainingText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (date, remainingText)
    }

    /// Parses a date string, delegating to the shared parser for correct
    /// two-digit-year, calendar, and validity handling.
    private func parseDateWithTwoDigitYearSupport(_ dateString: String) -> Date? {
        TriageDateParser.parseDate(dateString)
    }

    // MARK: - OB Status Extraction

    private func extractOBStatus(from text: String) -> (status: String, remainingText: String)? {
        var status: String?
        var matchedRange: Range<String.Index>?

        // Check for postpartum with weeks
        let ppPattern = #"POST\s*PARTUM\s*(\d+)\s*WKS?"#
        if let regex = try? NSRegularExpression(pattern: ppPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let weeksRange = Range(match.range(at: 1), in: text),
           let fullRange = Range(match.range, in: text) {
            let weeks = String(text[weeksRange])
            status = "Postpartum \(weeks) weeks"
            matchedRange = fullRange
        }
        // Check for "NOT OB" (case-insensitive search directly on the original
        // string — mapping offsets from an uppercased copy is unsafe because
        // uppercasing can change character counts)
        else if let range = text.range(of: "NOT OB", options: .caseInsensitive) {
            status = "Not OB"
            matchedRange = range
        }
        // Check for "OB" alone
        else if let range = text.range(of: #"\bOB\b"#, options: [.regularExpression, .caseInsensitive]) {
            status = "OB"
            matchedRange = range
        }
        // Check for gestational age — requires explicit pregnancy context
        // (GA/GESTATION suffix or PREGNANT nearby) so symptom durations like
        // "bleeding for 3 weeks" are not misread as a pregnancy.
        else {
            let gaPatterns = [
                #"(\d{1,2})\s*(?:WKS?|WEEKS?)\s*(?:GA\b|GESTATION\w*)"#,
                #"PREGNANT\s*[,@]?\s*(\d{1,2})\s*(?:WKS?|WEEKS?)"#,
                #"(\d{1,2})\s*(?:WKS?|WEEKS?)\s*PREGNANT"#
            ]
            for gaPattern in gaPatterns {
                if let regex = try? NSRegularExpression(pattern: gaPattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                   let weeksRange = Range(match.range(at: 1), in: text),
                   let fullRange = Range(match.range, in: text) {
                    let weeks = String(text[weeksRange])
                    status = "\(weeks) weeks GA"
                    matchedRange = fullRange
                    break
                }
            }
        }

        guard let finalStatus = status, let range = matchedRange else { return nil }

        var remainingText = text
        remainingText.removeSubrange(range)
        remainingText = remainingText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (finalStatus, remainingText)
    }

    // MARK: - Patient Name Extraction

    private func extractPatientName(from text: String, doctor: String?) -> String? {
        // Strategy 1: Look for explicit labels like "PATIENT NAME:", "PT:", "NAME:", etc.
        if let labeledName = extractLabeledPatientName(from: text) {
            return labeledName
        }

        // Strategy 2: Find text after "DR [NAME]" and before phone/DOB patterns
        if let doctorName = doctor {
            if let nameAfterDoctor = extractNameAfterDoctor(from: text, doctorName: doctorName) {
                return nameAfterDoctor
            }
        }

        // Strategy 3: Look for capitalized words that look like names (First Last pattern)
        if let inferredName = inferPatientName(from: text) {
            return inferredName
        }

        return nil
    }

    private func extractLabeledPatientName(from text: String) -> String? {
        // Patterns to match labeled patient names
        let patterns = [
            #"PATIENT\s*NAME[:\s]+([A-Z][A-Z'-]+(?:\s+[A-Z][A-Z'-]+)+)"#,
            #"PT[:\s]+([A-Z][A-Z'-]+(?:\s+[A-Z][A-Z'-]+)+)"#,
            #"NAME[:\s]+([A-Z][A-Z'-]+(?:\s+[A-Z][A-Z'-]+)+)"#,
            #"PATIENT[:\s]+([A-Z][A-Z'-]+(?:\s+[A-Z][A-Z'-]+)+)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let nameRange = Range(match.range(at: 1), in: text) {
                let name = String(text[nameRange])
                return formatPatientName(name)
            }
        }
        return nil
    }

    private func extractNameAfterDoctor(from text: String, doctorName: String) -> String? {
        // Find text after "DR [NAME]" and before phone/DOB patterns
        // Allow for various separators and formats
        let escapedDoctor = NSRegularExpression.escapedPattern(for: doctorName.uppercased())
        // Names are capped at 2-3 words with a lazy quantifier so the capture
        // stops at the shortest plausible name instead of greedily absorbing
        // chief-complaint words that follow.
        let patterns = [
            // DR NAME followed by patient name, then phone or DOB
            #"DR\.?\s+"# + escapedDoctor + #"\s+([A-Z][A-Z'-]+(?:\s+[A-Z][A-Z'-]+){1,2}?)(?=\s*\(?\d{3}|\s*DOB|\s*,\s*,|$)"#,
            // DR NAME with comma separator
            #"DR\.?\s+"# + escapedDoctor + #",?\s*([A-Z][A-Z'-]+(?:\s+[A-Z][A-Z'-]+){1,2}?)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let nameRange = Range(match.range(at: 1), in: text) {
                var name = String(text[nameRange])

                // Clean up any labels that got captured
                name = name.replacingOccurrences(of: "PATIENT NAME", with: "", options: .caseInsensitive)
                name = name.replacingOccurrences(of: "PATIENT", with: "", options: .caseInsensitive)
                name = name.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ",.")))

                if !name.isEmpty {
                    return formatPatientName(name)
                }
            }
        }
        return nil
    }

    private func inferPatientName(from text: String) -> String? {
        // Look for a sequence of 2-3 capitalized words that look like a name
        // This is a fallback heuristic

        // Skip common medical/message terms
        let skipWords = Set(["DR", "DOB", "OB", "NOT", "PATIENT", "NAME", "PHONE", "CALL", "BACK",
                             "MSG", "MESSAGE", "URGENT", "ROUTINE", "EMERGENT", "POSTPARTUM",
                             "CONCERNS", "FOR", "COMPLAINT", "CHIEF", "STATUS", "PREGNANT",
                             "WKS", "WEEKS", "THE", "AND", "WITH", "HAS", "HAVING", "BREAST"])

        // Pattern for 2-3 capitalized words
        let pattern = #"\b([A-Z][a-z]+)\s+([A-Z][a-z]+)(?:\s+([A-Z][a-z]+))?\b"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        for match in matches {
            guard let firstRange = Range(match.range(at: 1), in: text),
                  let lastRange = Range(match.range(at: 2), in: text) else {
                continue
            }

            let firstName = String(text[firstRange]).uppercased()
            let lastName = String(text[lastRange]).uppercased()

            // Skip if these are common medical words
            if skipWords.contains(firstName) || skipWords.contains(lastName) {
                continue
            }

            // This looks like a name
            var nameComponents = [String(text[firstRange]), String(text[lastRange])]

            // Check for middle name
            if match.range(at: 3).location != NSNotFound,
               let middleRange = Range(match.range(at: 3), in: text) {
                let middleName = String(text[middleRange])
                if !skipWords.contains(middleName.uppercased()) {
                    nameComponents.insert(middleName, at: 1)
                }
            }

            return formatPatientName(nameComponents.joined(separator: " "))
        }

        return nil
    }

    private func formatPatientName(_ name: String) -> String {
        var cleaned = name

        // Remove common artifacts
        cleaned = cleaned.replacingOccurrences(of: "REDACTED", with: "[REDACTED]", options: .caseInsensitive)
        cleaned = cleaned.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ",.")))

        // Return redacted as-is
        if cleaned.contains("[REDACTED]") {
            return cleaned
        }

        guard !cleaned.isEmpty else { return "" }

        // Title case: JOHN SMITH -> John Smith
        return cleaned.split(separator: " ").map { word in
            let lowercased = word.lowercased()
            return lowercased.prefix(1).uppercased() + lowercased.dropFirst()
        }.joined(separator: " ")
    }

    // MARK: - Chief Complaint Cleanup

    private func cleanupChiefComplaint(_ text: String) -> String {
        var complaint = text

        // Remove common prefixes/artifacts
        complaint = complaint.replacingOccurrences(of: "CONCERNS FOR", with: "", options: .caseInsensitive)
        complaint = complaint.replacingOccurrences(of: "CONCERN FOR", with: "", options: .caseInsensitive)
        complaint = complaint.replacingOccurrences(of: "PATIENT NAME REDACTED", with: "", options: .caseInsensitive)

        // Fix common spacing issues
        complaint = complaint.replacingOccurrences(of: ",", with: ", ")
        complaint = complaint.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        // Fix common medical abbreviations
        complaint = complaint.replacingOccurrences(of: "MASTITIST", with: "mastitis", options: .caseInsensitive)
        complaint = complaint.replacingOccurrences(of: "SEVEREPAIN", with: "severe pain", options: .caseInsensitive)

        // Trim and clean
        complaint = complaint.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ",-")))

        // Sentence case
        if !complaint.isEmpty {
            complaint = complaint.prefix(1).uppercased() + complaint.dropFirst().lowercased()
        }

        return complaint
    }
}
