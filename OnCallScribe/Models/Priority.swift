import Foundation

enum Priority: String, Codable, CaseIterable, Identifiable {
    case routine = "Routine"
    case urgent = "Urgent"
    case emergent = "Emergent"

    var id: String { rawValue }
}
