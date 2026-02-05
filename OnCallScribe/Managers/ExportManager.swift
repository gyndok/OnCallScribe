import Foundation

final class ExportManager {

    static let shared = ExportManager()

    private init() {}

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private let dobFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
    }()

    private let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    func exportRecords(_ records: [TriageRecord], physicianName: String) -> String {
        guard !records.isEmpty else {
            return "No records to export."
        }

        let sortedRecords = records.sorted { $0.dateReceived < $1.dateReceived }

        // Determine date range
        let firstDate = sortedRecords.first!.dateReceived
        let lastDate = sortedRecords.last!.dateReceived

        let dateRangeString: String
        if Calendar.current.isDate(firstDate, inSameDayAs: lastDate) {
            dateRangeString = dateOnlyFormatter.string(from: firstDate)
        } else {
            let startFormatter = DateFormatter()
            startFormatter.dateFormat = "MMMM d"
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "d, yyyy"

            if Calendar.current.component(.month, from: firstDate) == Calendar.current.component(.month, from: lastDate) {
                dateRangeString = "\(startFormatter.string(from: firstDate))–\(endFormatter.string(from: lastDate))"
            } else {
                dateRangeString = "\(dateOnlyFormatter.string(from: firstDate)) – \(dateOnlyFormatter.string(from: lastDate))"
            }
        }

        var output = """
        ON-CALL TRIAGE LOG
        Dr. \(physicianName) | \(dateRangeString) | \(records.count) encounter\(records.count == 1 ? "" : "s")

        """

        for (index, record) in sortedRecords.enumerated() {
            output += formatRecord(record, number: index + 1)
        }

        return output
    }

    private func formatRecord(_ record: TriageRecord, number: Int) -> String {
        var lines: [String] = []

        // Header line
        let priorityString = record.priorityEnum.rawValue.uppercased()
        lines.append("---")
        lines.append("ENCOUNTER \(number) | \(dateFormatter.string(from: record.dateReceived)) | \(priorityString)")

        // Patient info
        var patientLine = "Patient: \(record.displayName)"
        if let dob = record.dateOfBirth {
            patientLine += " | DOB: \(dobFormatter.string(from: dob))"
        }
        lines.append(patientLine)

        // Attending and callback
        var contactLine = ""
        if let attending = record.attendingDoctor, !attending.isEmpty {
            contactLine += "Attending: Dr. \(attending)"
        }
        if let callback = record.callbackNumber, !callback.isEmpty {
            if !contactLine.isEmpty { contactLine += " | " }
            contactLine += "Callback: \(callback)"
        }
        if !contactLine.isEmpty {
            lines.append(contactLine)
        }

        // OB Status
        if let obStatus = record.obStatus, !obStatus.isEmpty {
            lines.append("OB Status: \(obStatus)")
        }

        // Chief complaint
        if let complaint = record.chiefComplaint, !complaint.isEmpty {
            lines.append("Chief Complaint: \(complaint)")
        }

        // Advice
        if let advice = record.advice, !advice.isEmpty {
            lines.append("Advice: \(advice)")
        }

        // Disposition
        if let disposition = record.disposition, !disposition.isEmpty {
            lines.append("Disposition: \(disposition)")
        }

        // Follow-up
        if record.followUpNeeded {
            var followUpLine = "Follow-up: Yes"
            if let note = record.followUpNote, !note.isEmpty {
                followUpLine += " — \(note)"
            }
            lines.append(followUpLine)
        }

        lines.append("")

        return lines.joined(separator: "\n")
    }
}
