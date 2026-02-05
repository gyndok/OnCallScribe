import Foundation

enum Disposition: String, Codable, CaseIterable, Identifiable {
    case advisedHomeCare = "Advised home care"
    case sentToER = "Sent to ER/L&D"
    case scheduledOfficeVisit = "Scheduled office visit"
    case calledInRx = "Called in Rx"
    case referredToSpecialist = "Referred to specialist"
    case other = "Other"

    var id: String { rawValue }
}
