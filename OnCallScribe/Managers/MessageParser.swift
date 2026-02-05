import Foundation

struct ParsedMessage {
    var attendingDoctor: String?
    var patientName: String?
    var callbackNumber: String?
    var dateOfBirth: Date?
    var obStatus: String?
    var chiefComplaint: String?
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
        // Match various phone formats: (###) ###-####, ###-###-####, ##########
        let patterns = [
            #"\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#,
            #"\d{3}[-.\s]\d{3}[-.\s]\d{4}"#,
            #"\d{10}"#
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
        let digits = raw.filter { $0.isNumber }
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

    /// Parses a date string, properly handling two-digit years.
    /// - YY <= 25 → 20YY (e.g., 25 → 2025, 01 → 2001)
    /// - YY > 25 → 19YY (e.g., 97 → 1997, 85 → 1985)
    private func parseDateWithTwoDigitYearSupport(_ dateString: String) -> Date? {
        // First, try to parse with explicit components to handle 2-digit years correctly
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

    // MARK: - OB Status Extraction

    private func extractOBStatus(from text: String) -> (status: String, remainingText: String)? {
        let upperText = text.uppercased()
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
        // Check for "NOT OB"
        else if let range = upperText.range(of: "NOT OB") {
            status = "Not OB"
            let startIndex = text.index(text.startIndex, offsetBy: upperText.distance(from: upperText.startIndex, to: range.lowerBound))
            let endIndex = text.index(text.startIndex, offsetBy: upperText.distance(from: upperText.startIndex, to: range.upperBound))
            matchedRange = startIndex..<endIndex
        }
        // Check for "OB" alone
        else if let range = upperText.range(of: "\\bOB\\b", options: .regularExpression) {
            status = "OB"
            let startIndex = text.index(text.startIndex, offsetBy: upperText.distance(from: upperText.startIndex, to: range.lowerBound))
            let endIndex = text.index(text.startIndex, offsetBy: upperText.distance(from: upperText.startIndex, to: range.upperBound))
            matchedRange = startIndex..<endIndex
        }
        // Check for gestational age
        else {
            let gaPattern = #"(\d{1,2})\s*(?:WKS?|WEEKS?)\s*(?:GA|GESTATION)?"#
            if let regex = try? NSRegularExpression(pattern: gaPattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let weeksRange = Range(match.range(at: 1), in: text),
               let fullRange = Range(match.range, in: text) {
                let weeks = String(text[weeksRange])
                status = "\(weeks) weeks GA"
                matchedRange = fullRange
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
        let patterns = [
            // DR NAME followed by patient name, then phone or DOB
            #"DR\.?\s+"# + escapedDoctor + #"\s+([A-Z][A-Z'-]+(?:\s+[A-Z][A-Z'-]+)+)(?=\s*\(?\d{3}|\s*DOB|\s*,\s*,|$)"#,
            // DR NAME with comma separator
            #"DR\.?\s+"# + escapedDoctor + #",?\s*([A-Z][A-Z'-]+(?:\s+[A-Z][A-Z'-]+)+)"#
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
