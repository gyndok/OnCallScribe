import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @AppStorage("onCallPhysicianName") private var physicianName = ""
    @AppStorage("selectedSpecialty") private var selectedSpecialtyRaw = MedicalSpecialty.other.rawValue

    @Query private var allRecords: [TriageRecord]

    @State private var showingExportAllAlert = false
    @State private var showingDeleteAllAlert = false
    @State private var exportedJSON: String?
    @State private var showingShareSheet = false
    @State private var showingAddDoctor = false
    @State private var newDoctorName = ""
    @State private var showingSpecialtyPicker = false

    @ObservedObject private var doctorManager = DoctorListManager.shared

    private var selectedSpecialty: MedicalSpecialty {
        get { MedicalSpecialty(rawValue: selectedSpecialtyRaw) ?? .other }
        set { selectedSpecialtyRaw = newValue.rawValue }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Your Information Card (Name + Specialty)
                    yourInformationCard

                    // Attending Doctors Card
                    attendingDoctorsCard

                    // AI Parsing Card
                    aiParsingCard

                    // Data Card
                    dataCard

                    // About Card
                    aboutCard
                }
                .padding(16)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bgPrimary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(Color.accentTeal)
            }
        }
        .alert("Delete All Records?", isPresented: $showingDeleteAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllRecords()
            }
        } message: {
            Text("This will permanently delete all \(allRecords.count) triage records. This cannot be undone.")
        }
        .sheet(isPresented: $showingShareSheet) {
            if let json = exportedJSON {
                ShareSheet(items: [json])
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Cards

    private var yourInformationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("YOUR INFORMATION")
                .sectionHeader()

            // Specialty Picker
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: selectedSpecialty.icon)
                        .foregroundColor(Color.accentTeal)
                    Text("Specialty")
                        .font(MedDarkTypography.fieldLabel)
                        .foregroundColor(Color.txtSecondary)
                }

                Button {
                    HapticFeedback.impact(.light)
                    showingSpecialtyPicker = true
                } label: {
                    HStack {
                        Text(selectedSpecialty.rawValue)
                            .foregroundColor(Color.txtPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Color.txtTertiary)
                    }
                    .formFieldStyle()
                }
            }

            Divider()
                .background(Color.dividerColor)

            // Name Field
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.clock")
                        .foregroundColor(Color.txtTertiary)
                    Text("Your Name")
                        .font(MedDarkTypography.fieldLabel)
                        .foregroundColor(Color.txtSecondary)
                }

                TextField("Enter your name", text: $physicianName)
                    .font(.body)
                    .foregroundColor(Color.txtPrimary)
                    .formFieldStyle()
            }

            Text("Your specialty customizes the app for your practice. Your name is used as the default on-call physician.")
                .font(.caption)
                .foregroundColor(Color.txtTertiary)
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentTeal.opacity(0.3), lineWidth: 0.5)
        )
        .sheet(isPresented: $showingSpecialtyPicker) {
            SpecialtyPickerView(selectedSpecialty: $selectedSpecialtyRaw)
        }
    }

    private var attendingDoctorsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ATTENDING DOCTORS")
                    .sectionHeader()

                Spacer()

                Button {
                    showingAddDoctor = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(Color.accentTeal)
                }
            }

            if doctorManager.doctors.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "stethoscope")
                        .font(.title2)
                        .foregroundColor(Color.txtTertiary)

                    Text("No doctors added")
                        .font(.subheadline)
                        .foregroundColor(Color.txtSecondary)

                    Text("Add attending doctors for quick selection when creating records.")
                        .font(.caption)
                        .foregroundColor(Color.txtTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(doctorManager.doctors, id: \.self) { doctor in
                        HStack {
                            Image(systemName: "stethoscope")
                                .foregroundColor(Color.txtTertiary)
                                .frame(width: 24)

                            Text("Dr. \(doctor)")
                                .font(.subheadline)
                                .foregroundColor(Color.txtPrimary)

                            Spacer()

                            Button {
                                HapticFeedback.impact(.light)
                                doctorManager.removeDoctor(doctor)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(Color.prioEmergent.opacity(0.7))
                            }
                        }
                        .padding(.vertical, 10)

                        if doctor != doctorManager.doctors.last {
                            Divider()
                                .background(Color.dividerColor)
                        }
                    }
                }
            }

            Text("These doctors will appear as quick-select options when entering the attending physician.")
                .font(.caption)
                .foregroundColor(Color.txtTertiary)
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border, lineWidth: 0.5)
        )
        .alert("Add Doctor", isPresented: $showingAddDoctor) {
            TextField("Last name (e.g., Smith)", text: $newDoctorName)
            Button("Cancel", role: .cancel) {
                newDoctorName = ""
            }
            Button("Add") {
                doctorManager.addDoctor(newDoctorName)
                newDoctorName = ""
            }
        } message: {
            Text("Enter the doctor's last name. It will be displayed as \"Dr. [Name]\".")
        }
    }

    private var aiParsingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI PARSING")
                .sectionHeader()

            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "cpu")
                            .foregroundColor(AIMessageParser.shared.isAvailable ? Color.accentTeal : Color.txtTertiary)
                        Text("On-Device AI")
                            .font(.subheadline)
                            .foregroundColor(Color.txtSecondary)
                    }
                    Spacer()
                    Text(AIMessageParser.shared.isAvailable ? "Active" : "Unavailable")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AIMessageParser.shared.isAvailable ? Color.prioRoutine : Color.txtTertiary)
                }

                Divider()
                    .background(Color.dividerColor)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: AIMessageParser.shared.isAvailable ? "checkmark.circle.fill" : "info.circle")
                            .foregroundColor(AIMessageParser.shared.isAvailable ? Color.prioRoutine : Color.txtTertiary)
                        Text("Status")
                            .font(.caption.weight(.medium))
                            .foregroundColor(Color.txtSecondary)
                    }

                    Text(AIMessageParser.shared.statusMessage)
                        .font(.caption)
                        .foregroundColor(Color.txtTertiary)
                }

                if AIMessageParser.shared.isAvailable {
                    Divider()
                        .background(Color.dividerColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Apple Foundation Models")
                            .font(.caption.weight(.medium))
                            .foregroundColor(Color.txtSecondary)

                        Text("Messages are parsed using Apple's on-device 3B parameter LLM. No data is sent to any server — all processing happens locally on your iPhone.")
                            .font(.caption)
                            .foregroundColor(Color.txtTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AIMessageParser.shared.isAvailable ? Color.accentTeal.opacity(0.3) : Color.border, lineWidth: 0.5)
        )
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DATA")
                .sectionHeader()

            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .foregroundColor(Color.txtTertiary)
                        Text("Total Records")
                            .font(.subheadline)
                            .foregroundColor(Color.txtSecondary)
                    }
                    Spacer()
                    Text("\(allRecords.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.txtPrimary)
                }

                Divider()
                    .background(Color.dividerColor)

                Button {
                    exportAllDataAsJSON()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export All Data (JSON)")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color.accentTeal)
                }

                Divider()
                    .background(Color.dividerColor)

                Button {
                    showingDeleteAllAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete All Records")
                        Spacer()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color.prioEmergent)
                }
            }
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ABOUT")
                .sectionHeader()

            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(Color.txtTertiary)
                        Text("Version")
                            .font(.subheadline)
                            .foregroundColor(Color.txtSecondary)
                    }
                    Spacer()
                    Text(appVersion)
                        .font(.subheadline)
                        .foregroundColor(Color.txtPrimary)
                }

                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield")
                            .foregroundColor(Color.txtTertiary)
                        Text("Data Storage")
                            .font(.subheadline)
                            .foregroundColor(Color.txtSecondary)
                    }
                    Spacer()
                    Text("On-device only")
                        .font(.subheadline)
                        .foregroundColor(Color.prioRoutine)
                }

                Divider()
                    .background(Color.dividerColor)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.raised")
                            .foregroundColor(Color.accentTeal)
                        Text("Privacy Notice")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Color.txtPrimary)
                    }

                    Text("OnCall Scribe stores all data exclusively on your device. No data is ever transmitted to any server or cloud service. Data only leaves your device when you explicitly use the Share function.")
                        .font(.caption)
                        .foregroundColor(Color.txtTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    // MARK: - Actions

    private func exportAllDataAsJSON() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let exportData = allRecords.map { record in
            RecordExport(
                id: record.id.uuidString,
                rawMessage: record.rawMessage,
                dateReceived: record.dateReceived,
                dateSaved: record.dateSaved,
                lastModified: record.lastModified,
                attendingDoctor: record.attendingDoctor,
                patientName: record.patientName,
                callbackNumber: record.callbackNumber,
                dateOfBirth: record.dateOfBirth,
                obStatus: record.obStatus,
                chiefComplaint: record.chiefComplaint,
                specialty: record.specialty,
                patientAge: record.patientAge,
                gestationalAge: record.gestationalAge,
                safetyConcerns: record.safetyConcerns,
                advice: record.advice,
                disposition: record.disposition,
                priority: record.priority,
                callbackCompleted: record.callbackCompleted,
                callbackTime: record.callbackTime,
                followUpNeeded: record.followUpNeeded,
                followUpNote: record.followUpNote,
                tags: record.tags,
                onCallPhysician: record.onCallPhysician
            )
        }

        do {
            let jsonData = try encoder.encode(exportData)
            exportedJSON = String(data: jsonData, encoding: .utf8)
            showingShareSheet = true
        } catch {
            print("Failed to encode records: \(error)")
        }
    }

    private func deleteAllRecords() {
        HapticFeedback.impact()
        for record in allRecords {
            modelContext.delete(record)
        }
    }
}

struct RecordExport: Codable {
    let id: String
    let rawMessage: String
    let dateReceived: Date
    let dateSaved: Date
    let lastModified: Date
    let attendingDoctor: String?
    let patientName: String?
    let callbackNumber: String?
    let dateOfBirth: Date?
    let obStatus: String?
    let chiefComplaint: String?
    let specialty: String
    let patientAge: String?
    let gestationalAge: String?
    let safetyConcerns: String?
    let advice: String?
    let disposition: String?
    let priority: String
    let callbackCompleted: Bool
    let callbackTime: Date?
    let followUpNeeded: Bool
    let followUpNote: String?
    let tags: [String]
    let onCallPhysician: String
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: TriageRecord.self, inMemory: true)
}
