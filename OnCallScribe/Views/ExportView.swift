import SwiftUI

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss

    let records: [TriageRecord]

    @AppStorage("onCallPhysicianName") private var physicianName = ""

    @State private var startDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var exportText = ""
    @State private var showingShareSheet = false
    @State private var useManualSelection = false
    @State private var selectedRecordIDs: Set<UUID> = []
    @State private var showingRecordList = false

    private var dateFilteredRecords: [TriageRecord] {
        let startOfDay = Calendar.current.startOfDay(for: startDate)
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate

        return records.filter { record in
            record.dateReceived >= startOfDay && record.dateReceived <= endOfDay
        }.sorted { $0.dateReceived > $1.dateReceived }
    }

    private var recordsToExport: [TriageRecord] {
        if useManualSelection {
            return records.filter { selectedRecordIDs.contains($0.id) }
                .sorted { $0.dateReceived > $1.dateReceived }
        } else {
            return dateFilteredRecords
        }
    }

    private var statistics: (routine: Int, urgent: Int, emergent: Int, followUp: Int) {
        let toExport = recordsToExport
        return (
            routine: toExport.filter { $0.priorityEnum == .routine }.count,
            urgent: toExport.filter { $0.priorityEnum == .urgent }.count,
            emergent: toExport.filter { $0.priorityEnum == .emergent }.count,
            followUp: toExport.filter { $0.followUpNeeded }.count
        )
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Selection Mode Toggle
                    selectionModeCard

                    if !useManualSelection {
                        // Date Range Card
                        dateRangeCard

                        // Quick Date Presets
                        quickPresetsCard
                    } else {
                        // Manual Selection Card
                        manualSelectionCard
                    }

                    // Statistics Card
                    if !recordsToExport.isEmpty {
                        statisticsCard
                    }

                    // Record List Preview
                    if !recordsToExport.isEmpty {
                        recordListCard
                    }

                    // Export Actions
                    if !recordsToExport.isEmpty {
                        exportActionsCard
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
        .sheet(isPresented: $showingRecordList) {
            NavigationStack {
                RecordSelectionListView(
                    records: records,
                    selectedIDs: $selectedRecordIDs
                )
            }
        }
        .onAppear {
            // Default to last 24 hours or all records if few
            if records.count <= 10 {
                if let oldest = records.min(by: { $0.dateReceived < $1.dateReceived }) {
                    startDate = oldest.dateReceived
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Cards

    private var selectionModeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SELECTION MODE")
                .sectionHeader()

            HStack(spacing: 8) {
                selectionModeButton(title: "Date Range", icon: "calendar", isSelected: !useManualSelection) {
                    useManualSelection = false
                }

                selectionModeButton(title: "Manual", icon: "checkmark.circle", isSelected: useManualSelection) {
                    useManualSelection = true
                    if selectedRecordIDs.isEmpty {
                        // Pre-select date-filtered records when switching
                        selectedRecordIDs = Set(dateFilteredRecords.map { $0.id })
                    }
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

    private func selectionModeButton(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.impact(.light)
            action()
        } label: {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(isSelected ? .white : Color.txtSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentTeal : Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

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

    private var quickPresetsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK SELECT")
                .sectionHeader()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    quickPresetButton("Today") { setDateRange(days: 0) }
                    quickPresetButton("24 Hours") { setDateRange(days: 1) }
                    quickPresetButton("Weekend") { setWeekendRange() }
                    quickPresetButton("This Week") { setDateRange(days: 7) }
                    quickPresetButton("All Records") { setAllRecords() }
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

    private func quickPresetButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.impact(.light)
            action()
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundColor(Color.txtSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.bgSecondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.border, lineWidth: 1)
                )
        }
    }

    private var manualSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SELECTED RECORDS")
                    .sectionHeader()

                Spacer()

                Button {
                    HapticFeedback.impact(.light)
                    showingRecordList = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color.accentTeal)
                }
            }

            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.accentTeal)

                Text("\(selectedRecordIDs.count) of \(records.count) records selected")
                    .font(.subheadline)
                    .foregroundColor(Color.txtSecondary)

                Spacer()

                if selectedRecordIDs.count < records.count {
                    Button("Select All") {
                        HapticFeedback.impact(.light)
                        selectedRecordIDs = Set(records.map { $0.id })
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(Color.accentTeal)
                } else {
                    Button("Deselect All") {
                        HapticFeedback.impact(.light)
                        selectedRecordIDs.removeAll()
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(Color.prioUrgent)
                }
            }
            .padding(12)
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    private var statisticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SUMMARY")
                .sectionHeader()

            HStack(spacing: 12) {
                statBadge(count: recordsToExport.count, label: "Total", color: Color.accentTeal)

                if statistics.emergent > 0 {
                    statBadge(count: statistics.emergent, label: "Emergent", color: Color.prioEmergent)
                }
                if statistics.urgent > 0 {
                    statBadge(count: statistics.urgent, label: "Urgent", color: Color.prioUrgent)
                }
                if statistics.routine > 0 {
                    statBadge(count: statistics.routine, label: "Routine", color: Color.prioRoutine)
                }

                Spacer()

                if statistics.followUp > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text("\(statistics.followUp) need follow-up")
                            .font(.caption)
                    }
                    .foregroundColor(Color.prioUrgent)
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

    private func statBadge(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title3.weight(.bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(Color.txtTertiary)
        }
        .frame(minWidth: 50)
    }

    private var recordListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RECORDS TO EXPORT")
                    .sectionHeader()

                Spacer()

                Text("\(recordsToExport.count) records")
                    .font(.caption)
                    .foregroundColor(Color.txtTertiary)
            }

            VStack(spacing: 8) {
                ForEach(recordsToExport.prefix(5)) { record in
                    exportRecordRow(record)
                }

                if recordsToExport.count > 5 {
                    HStack {
                        Spacer()
                        Text("+ \(recordsToExport.count - 5) more records")
                            .font(.caption)
                            .foregroundColor(Color.txtTertiary)
                        Spacer()
                    }
                    .padding(.top, 4)
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

    private func exportRecordRow(_ record: TriageRecord) -> some View {
        HStack(spacing: 12) {
            // Priority indicator
            Circle()
                .fill(record.priorityEnum.color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color.txtPrimary)

                Text(record.chiefComplaintSnippet)
                    .font(.caption)
                    .foregroundColor(Color.txtTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(record.dateReceived.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundColor(Color.txtTertiary)
        }
        .padding(10)
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var exportActionsCard: some View {
        VStack(spacing: 12) {
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

            Button {
                HapticFeedback.impact(.light)
                exportText = generateExportText()
                UIPasteboard.general.string = exportText
                HapticFeedback.notification(.success)
            } label: {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("Copy to Clipboard")
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(Color.accentTeal)
            }
        }
    }

    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(Color.txtTertiary)

            Text("No Records")
                .font(.headline)
                .foregroundColor(Color.txtPrimary)

            Text(useManualSelection
                 ? "Select records to export using the Edit button above."
                 : "No records found in the selected date range.")
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

    // MARK: - Date Helpers

    private func setDateRange(days: Int) {
        let calendar = Calendar.current
        let now = Date()

        if days == 0 {
            startDate = calendar.startOfDay(for: now)
            endDate = now
        } else {
            startDate = calendar.date(byAdding: .day, value: -days, to: now) ?? now
            endDate = now
        }
    }

    private func setWeekendRange() {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)

        // Find last Friday 5pm
        let daysToLastFriday = (weekday + 1) % 7 + 1
        var start = calendar.date(byAdding: .day, value: -daysToLastFriday, to: now)!
        start = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: start)!

        startDate = start
        endDate = now
    }

    private func setAllRecords() {
        if let oldest = records.min(by: { $0.dateReceived < $1.dateReceived }) {
            startDate = oldest.dateReceived
        }
        endDate = Date()
    }

    private func generateExportText() -> String {
        ExportManager.shared.exportRecords(recordsToExport, physicianName: physicianName.isEmpty ? "Unknown" : physicianName)
    }
}

// MARK: - Record Selection List View

struct RecordSelectionListView: View {
    @Environment(\.dismiss) private var dismiss

    let records: [TriageRecord]
    @Binding var selectedIDs: Set<UUID>

    private var sortedRecords: [TriageRecord] {
        records.sorted { $0.dateReceived > $1.dateReceived }
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(sortedRecords) { record in
                        selectionRow(record)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Select Records")
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

            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundColor(Color.accentTeal)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Text("\(selectedIDs.count) selected")
                    .font(.subheadline)
                    .foregroundColor(Color.txtSecondary)

                Spacer()

                if selectedIDs.count < records.count {
                    Button("Select All") {
                        HapticFeedback.impact(.light)
                        selectedIDs = Set(records.map { $0.id })
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color.accentTeal)
                } else {
                    Button("Deselect All") {
                        HapticFeedback.impact(.light)
                        selectedIDs.removeAll()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color.prioUrgent)
                }
            }
            .padding(16)
            .background(Color.bgSecondary)
        }
        .preferredColorScheme(.dark)
    }

    private func selectionRow(_ record: TriageRecord) -> some View {
        let isSelected = selectedIDs.contains(record.id)

        return Button {
            HapticFeedback.impact(.light)
            if isSelected {
                selectedIDs.remove(record.id)
            } else {
                selectedIDs.insert(record.id)
            }
        } label: {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? Color.accentTeal : Color.txtTertiary)

                // Priority indicator
                Circle()
                    .fill(record.priorityEnum.color)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(record.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Color.txtPrimary)

                    Text(record.chiefComplaintSnippet)
                        .font(.caption)
                        .foregroundColor(Color.txtTertiary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(record.dateReceived.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundColor(Color.txtTertiary)

                    Text(record.dateReceived.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(Color.txtTertiary)
                }
            }
            .padding(12)
            .background(isSelected ? Color.accentTeal.opacity(0.1) : Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentTeal.opacity(0.3) : Color.border, lineWidth: 0.5)
            )
        }
    }
}

#Preview {
    NavigationStack {
        ExportView(records: [])
    }
}
