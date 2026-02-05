import Foundation
import SwiftUI

final class DoctorListManager: ObservableObject {
    static let shared = DoctorListManager()

    private let storageKey = "savedDoctorsList"

    @Published var doctors: [String] = []

    private init() {
        loadDoctors()
    }

    private func loadDoctors() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.doctors = decoded
        } else {
            self.doctors = []
        }
    }

    private func saveDoctors() {
        if let encoded = try? JSONEncoder().encode(doctors) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    func addDoctor(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !doctors.contains(trimmed) else { return }
        doctors.append(trimmed)
        doctors.sort()
        saveDoctors()
    }

    func removeDoctor(_ name: String) {
        doctors.removeAll { $0 == name }
        saveDoctors()
    }

    func removeDoctor(at offsets: IndexSet) {
        doctors.remove(atOffsets: offsets)
        saveDoctors()
    }
}
