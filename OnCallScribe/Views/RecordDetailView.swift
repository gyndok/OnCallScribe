import SwiftUI
import SwiftData

struct RecordDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var record: TriageRecord

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private let dobFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
    }()

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Priority Header Card
                    priorityHeaderCard

                    // Patient Information Card
                    patientInfoCard

                    // Chief Complaint Card
                    if let complaint = record.chiefComplaint, !complaint.isEmpty {
                        chiefComplaintCard(complaint)
                    }

                    // Clinical Response Card
                    clinicalResponseCard

                    // Record Metadata Card
                    metadataCard

                    // Original Message Card
                    if !record.rawMessage.isEmpty {
                        originalMessageCard
                    }

                    // Delete Button
                    deleteButton
                }
                .padding(16)
            }
        }
        .navigationTitle("Record Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bgPrimary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingEditSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .foregroundColor(Color.accentTeal)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                RecordFormView(mode: .edit(record))
            }
        }
        .alert("Delete Record?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                HapticFeedback.impact()
                modelContext.delete(record)
                dismiss()
            }
        } message: {
            Text("This will permanently delete this triage record. This cannot be undone.")
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Card Components

    private var priorityHeaderCard: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: record.priorityEnum.icon)
                    .font(.title2)
                    .accessibilityHidden(true)
                Text(record.priorityEnum.rawValue)
                    .font(.headline.weight(.semibold))
            }
            .foregroundColor(record.priorityEnum.color)

            Spacer()

            if record.followUpNeeded {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .accessibilityHidden(true)
                    Text("Follow-up")
                }
                .font(.caption.weight(.medium))
                .foregroundColor(Color.prioUrgent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.prioUrgent.opacity(0.15))
                .clipShape(Capsule())
            }

            if record.callbackCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(Color.prioRoutine)
                    .accessibilityLabel("Callback completed")
            }
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
    }

    private var patientInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PATIENT INFORMATION")
                .sectionHeader()

            VStack(spacing: 12) {
                DetailRow(icon: "person", label: "Patient Name", value: record.displayName)

                if let dob = record.dateOfBirth {
                    DetailRow(icon: "calendar", label: "Date of Birth", value: dobFormatter.string(from: dob))
                }

                if let callback = record.callbackNumber, !callback.isEmpty {
                    DetailRow(icon: "phone.arrow.up.right", label: "Callback Number", value: callback, isTappable: true)
                }

                if let attending = record.attendingDoctor, !attending.isEmpty {
                    DetailRow(icon: "stethoscope", label: "Attending Doctor", value: "Dr. \(attending)")
                }

                if let obStatus = record.obStatus, !obStatus.isEmpty {
                    DetailRow(icon: "heart.text.square", label: "OB Status", value: obStatus)
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

    private func chiefComplaintCard(_ complaint: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CHIEF COMPLAINT")
                .sectionHeader()

            Text(complaint)
                .font(.body)
                .foregroundColor(Color.txtPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    private var clinicalResponseCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CLINICAL RESPONSE")
                .sectionHeader()

            VStack(spacing: 12) {
                if let advice = record.advice, !advice.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.bubble")
                                .foregroundColor(Color.txtTertiary)
                            Text("Advice / Plan")
                                .font(.caption.weight(.medium))
                                .foregroundColor(Color.txtSecondary)
                        }
                        Text(advice)
                            .font(.body)
                            .foregroundColor(Color.txtPrimary)
                    }

                    Divider()
                        .background(Color.dividerColor)
                }

                if let disposition = record.disposition, !disposition.isEmpty {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundColor(Color.txtTertiary)
                            Text("Disposition")
                                .font(.caption.weight(.medium))
                                .foregroundColor(Color.txtSecondary)
                        }
                        Spacer()
                        Text(disposition)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(Color.accentTeal)
                    }
                }

                if record.followUpNeeded {
                    Divider()
                        .background(Color.dividerColor)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(Color.prioUrgent)
                            Text("Follow-up Required")
                                .font(.caption.weight(.medium))
                                .foregroundColor(Color.prioUrgent)
                        }
                        if let note = record.followUpNote, !note.isEmpty {
                            Text(note)
                                .font(.subheadline)
                                .foregroundColor(Color.txtSecondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RECORD INFO")
                .sectionHeader()

            VStack(spacing: 12) {
                DetailRow(
                    icon: "person.badge.clock",
                    label: "On-Call Physician",
                    value: record.onCallPhysician.isEmpty ? "Not specified" : "Dr. \(record.onCallPhysician)"
                )

                DetailRow(
                    icon: "clock",
                    label: "Received",
                    value: dateFormatter.string(from: record.dateReceived)
                )

                DetailRow(
                    icon: "pencil",
                    label: "Last Modified",
                    value: dateFormatter.string(from: record.lastModified)
                )
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

    private var originalMessageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ORIGINAL MESSAGE")
                .sectionHeader()

            Text(record.rawMessage)
                .font(.caption)
                .foregroundColor(Color.txtTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    private var deleteButton: some View {
        Button {
            showingDeleteAlert = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete Record")
            }
            .font(.headline.weight(.medium))
            .foregroundColor(Color.prioEmergent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.prioEmergent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.prioEmergent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(CardPressStyle())
        .padding(.top, 8)
    }
}

// MARK: - Detail Row Component

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    var isTappable: Bool = false

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(Color.txtTertiary)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(Color.txtSecondary)
            }

            Spacer()

            if isTappable {
                Button {
                    // Could add phone call action here
                } label: {
                    Text(value)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Color.accentTeal)
                }
                .accessibilityLabel("\(label): \(value)")
                .accessibilityHint("Double tap to call")
            } else {
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color.txtPrimary)
            }
        }
        .accessibilityElement(children: isTappable ? .contain : .combine)
        .accessibilityLabel(isTappable ? "" : "\(label): \(value)")
    }
}

#Preview {
    NavigationStack {
        RecordDetailView(record: TriageRecord(
            rawMessage: "DR LABERGE PATIENT NAME REDACTED. ,§713-854-9439,,DOB:06/30/1993NOT OBCONCERNS FOR MASTITIST,SEVEREPAIN ,POST PARTUM 1WKS,--",
            attendingDoctor: "Laberge",
            patientName: "Jane Doe",
            callbackNumber: "(713) 854-9439",
            dateOfBirth: Date(),
            obStatus: "Postpartum 1 week",
            chiefComplaint: "Concerns for mastitis, severe pain",
            advice: "Start warm compresses, ibuprofen 600mg q6h, call back if fever > 101.5",
            disposition: "Advised home care",
            priority: .urgent,
            followUpNeeded: true,
            followUpNote: "Recheck in office Monday AM",
            onCallPhysician: "Klein"
        ))
    }
    .modelContainer(for: TriageRecord.self, inMemory: true)
}
