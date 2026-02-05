import SwiftUI

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss

    let records: [TriageRecord]

    @AppStorage("onCallPhysicianName") private var physicianName = ""

    @State private var startDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var exportText = ""
    @State private var showingShareSheet = false

    private var filteredRecords: [TriageRecord] {
        let startOfDay = Calendar.current.startOfDay(for: startDate)
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate

        return records.filter { record in
            record.dateReceived >= startOfDay && record.dateReceived <= endOfDay
        }
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Date Range Card
                    dateRangeCard

                    // Record Count Card
                    recordCountCard

                    // Preview Card (if records exist)
                    if !filteredRecords.isEmpty {
                        previewCard

                        // Share Button
                        Button {
                            HapticFeedback.impact()
                            exportText = generateExportText()
                            showingShareSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Export")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else {
                        emptyStateCard
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Export Records")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bgPrimary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(Color.txtSecondary)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [exportText])
        }
        .onAppear {
            if let oldest = records.min(by: { $0.dateReceived < $1.dateReceived }) {
                startDate = oldest.dateReceived
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Cards

    private var dateRangeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DATE RANGE")
                .sectionHeader()

            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundColor(Color.txtTertiary)
                        Text("Start")
                            .font(.subheadline)
                            .foregroundColor(Color.txtSecondary)
                    }
                    Spacer()
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(Color.accentTeal)
                }

                Divider()
                    .background(Color.dividerColor)

                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundColor(Color.txtTertiary)
                        Text("End")
                            .font(.subheadline)
                            .foregroundColor(Color.txtSecondary)
                    }
                    Spacer()
                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(Color.accentTeal)
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

    private var recordCountCard: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .foregroundColor(Color.txtTertiary)
                Text("Records to Export")
                    .font(.subheadline)
                    .foregroundColor(Color.txtSecondary)
            }
            Spacer()
            Text("\(filteredRecords.count)")
                .font(.title2.weight(.bold))
                .foregroundColor(filteredRecords.isEmpty ? Color.txtTertiary : Color.accentTeal)
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PREVIEW")
                .sectionHeader()

            ScrollView {
                Text(generateExportText())
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Color.txtSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 250)
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(Color.txtTertiary)

            Text("No Records")
                .font(.headline)
                .foregroundColor(Color.txtPrimary)

            Text("No records found in the selected date range.")
                .font(.subheadline)
                .foregroundColor(Color.txtSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    private func generateExportText() -> String {
        ExportManager.shared.exportRecords(filteredRecords, physicianName: physicianName.isEmpty ? "Unknown" : physicianName)
    }
}

#Preview {
    NavigationStack {
        ExportView(records: [])
    }
}
