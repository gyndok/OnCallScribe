import Foundation
import SwiftData

@Model
final class TriageRecord {
    var id: UUID
    var rawMessage: String
    var dateReceived: Date
    var dateSaved: Date
    var lastModified: Date

    // Parsed fields
    var attendingDoctor: String?
    var patientName: String?
    var callbackNumber: String?
    var dateOfBirth: Date?
    var obStatus: String?
    var chiefComplaint: String?

    // Specialty-specific fields
    var specialty: String  // Store MedicalSpecialty rawValue
    var patientAge: String?  // Pediatrics: "3 years", "18 months"
    var gestationalAge: String?  // OBGYN: "32w4d"
    var safetyConcerns: String?  // Psychiatry: SI, HI, etc.

    // Physician documentation
    var advice: String?
    var disposition: String?
    var priority: String
    var callbackCompleted: Bool
    var callbackTime: Date?
    var followUpNeeded: Bool
    var followUpNote: String?
    var tags: [String]
    var onCallPhysician: String

    init(
        rawMessage: String = "",
        attendingDoctor: String? = nil,
        patientName: String? = nil,
        callbackNumber: String? = nil,
        dateOfBirth: Date? = nil,
        obStatus: String? = nil,
        chiefComplaint: String? = nil,
        specialty: MedicalSpecialty = .other,
        patientAge: String? = nil,
        gestationalAge: String? = nil,
        safetyConcerns: String? = nil,
        advice: String? = nil,
        disposition: String? = nil,
        priority: Priority = .routine,
        callbackCompleted: Bool = false,
        callbackTime: Date? = nil,
        followUpNeeded: Bool = false,
        followUpNote: String? = nil,
        tags: [String] = [],
        onCallPhysician: String = ""
    ) {
        self.id = UUID()
        self.rawMessage = rawMessage
        self.dateReceived = Date()
        self.dateSaved = Date()
        self.lastModified = Date()
        self.attendingDoctor = attendingDoctor
        self.patientName = patientName
        self.callbackNumber = callbackNumber
        self.dateOfBirth = dateOfBirth
        self.obStatus = obStatus
        self.chiefComplaint = chiefComplaint
        self.specialty = specialty.rawValue
        self.patientAge = patientAge
        self.gestationalAge = gestationalAge
        self.safetyConcerns = safetyConcerns
        self.advice = advice
        self.disposition = disposition
        self.priority = priority.rawValue
        self.callbackCompleted = callbackCompleted
        self.callbackTime = callbackTime
        self.followUpNeeded = followUpNeeded
        self.followUpNote = followUpNote
        self.tags = tags
        self.onCallPhysician = onCallPhysician
    }

    var priorityEnum: Priority {
        get { Priority(rawValue: priority) ?? .routine }
        set { priority = newValue.rawValue }
    }

    var specialtyEnum: MedicalSpecialty {
        get { MedicalSpecialty(rawValue: specialty) ?? .other }
        set { specialty = newValue.rawValue }
    }

    var dispositionEnum: Disposition? {
        get {
            guard let disposition = disposition else { return nil }
            return Disposition(rawValue: disposition)
        }
        set { disposition = newValue?.rawValue }
    }

    var displayName: String {
        patientName?.isEmpty == false ? patientName! : "Unknown Patient"
    }

    var chiefComplaintSnippet: String {
        guard let complaint = chiefComplaint, !complaint.isEmpty else {
            return "No complaint recorded"
        }
        if complaint.count <= 50 {
            return complaint
        }
        return String(complaint.prefix(50)) + "..."
    }
}
