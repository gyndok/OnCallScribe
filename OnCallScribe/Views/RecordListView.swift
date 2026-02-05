import SwiftUI
import SwiftData
import UIKit

struct RecordListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TriageRecord.dateReceived, order: .reverse) private var records: [TriageRecord]

    @State private var searchText = ""
    @State private var showingNewRecord = false
    @State private var showingSettings = false
    @State private var showingExport = false
    @State private var showingFilters = false
    @State private var selectedRecord: TriageRecord?
    @State private var recordToEdit: TriageRecord?
    @State private var recordToDelete: TriageRecord?
    @State private var showingDeleteAlert = false
    @State private var filter = RecordFilter()

    @AppStorage("onCallPhysicianName") private var physicianName = ""

    private var knownDoctors: [String] {
        let doctors = Set(records.compactMap { $0.attendingDoctor?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty })
        return Array(doctors).sorted()
    }

    private var filteredRecords: [TriageRecord] {
        var result = records

        // Apply text search
        if !searchText.isEmpty {
            let lowercasedSearch = searchText.lowercased()
            result = result.filter { record in
                record.patientName?.lowercased().contains(lowercasedSearch) == true ||
                record.attendingDoctor?.lowercased().contains(lowercasedSearch) == true ||
                record.chiefComplaint?.lowercased().contains(lowercasedSearch) == true ||
                record.advice?.lowercased().contains(lowercasedSearch) == true ||
                record.disposition?.lowercased().contains(lowercasedSearch) == true ||
                record.tags.contains { $0.lowercased().contains(lowercasedSearch) }
            }
        }

        // Apply date range filter
        if let startDate = filter.startDate {
            result = result.filter { $0.dateReceived >= startDate }
        }
        if let endDate = filter.endDate {
            result = result.filter { $0.dateReceived <= endDate }
        }

        // Apply priority filter
        if !filter.priorities.isEmpty {
            result = result.filter { filter.priorities.contains($0.priorityEnum) }
        }

        // Apply disposition filter
        if !filter.dispositions.isEmpty {
            result = result.filter { record in
                guard let disposition = record.dispositionEnum else { return false }
                return filter.dispositions.contains(disposition)
            }
        }

        // Apply follow-up filter
        if let followUpNeeded = filter.followUpNeeded {
            result = result.filter { $0.followUpNeeded == followUpNeeded }
        }

        // Apply attending doctor filter
        if let doctor = filter.attendingDoctor {
            result = result.filter { $0.attendingDoctor == doctor }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                if records.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Search bar
                            searchBar
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            // Active filters indicator
                            if filter.isActive {
                                activeFiltersIndicator
                                    .padding(.horizontal, 16)
                            }

                            // No results message
                            if filteredRecords.isEmpty {
                                noResultsView
                                    .padding(.top, 40)
                            }

                            // Record cards
                            ForEach(filteredRecords) { record in
                                RecordCardView(record: record)
                                    .padding(.horizontal, 16)
                                    .onTapGesture {
                                        HapticFeedback.impact(.light)
                                        selectedRecord = record
                                    }
                                    .contextMenu {
                                        // Edit Record
                                        Button {
                                            HapticFeedback.impact(.light)
                                            recordToEdit = record
                                        } label: {
                                            Label("Edit Record", systemImage: "pencil")
                                        }

                                        // Call Back
                                        if let callbackNumber = record.callbackNumber, !callbackNumber.isEmpty {
                                            Button {
                                                callPhoneNumber(callbackNumber)
                                            } label: {
                                                Label("Call Back", systemImage: "phone.arrow.up.right")
                                            }
                                        }

                                        Divider()

                                        // Priority Toggle
                                        if record.priorityEnum == .routine {
                                            Button {
                                                togglePriority(record, to: .urgent)
                                            } label: {
                                                Label("Mark as Urgent", systemImage: "exclamationmark.circle")
                                            }
                                        } else if record.priorityEnum == .urgent {
                                            Button {
                                                togglePriority(record, to: .emergent)
                                            } label: {
                                                Label("Mark as Emergent", systemImage: "bolt.circle")
                                            }
                                            Button {
                                                togglePriority(record, to: .routine)
                                            } label: {
                                                Label("Mark as Routine", systemImage: "circle")
                                            }
                                        } else {
                                            Button {
                                                togglePriority(record, to: .routine)
                                            } label: {
                                                Label("Mark as Routine", systemImage: "circle")
                                            }
                                        }

                                        Divider()

                                        // Delete Record
                                        Button(role: .destructive) {
                                            recordToDelete = record
                                            showingDeleteAlert = true
                                        } label: {
                                            Label("Delete Record", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle("OnCall Scribe")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.bgPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(Color.txtSecondary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if !records.isEmpty {
                            Button {
                                showingExport = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(Color.txtSecondary)
                            }
                        }

                        Button {
                            HapticFeedback.impact()
                            showingNewRecord = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(Color.accentTeal)
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedRecord) { record in
                RecordDetailView(record: record)
            }
            .sheet(isPresented: $showingNewRecord) {
                NavigationStack {
                    RecordFormView(mode: .create)
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
            .sheet(isPresented: $showingExport) {
                NavigationStack {
                    ExportView(records: records)
                }
            }
            .sheet(item: $recordToEdit) { record in
                NavigationStack {
                    RecordFormView(mode: .edit(record))
                }
            }
            .sheet(isPresented: $showingFilters) {
                SearchFilterView(filter: $filter, knownDoctors: knownDoctors)
            }
            .alert("Delete this triage record?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    recordToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let record = recordToDelete {
                        HapticFeedback.notification(.warning)
                        modelContext.delete(record)
                        recordToDelete = nil
                    }
                }
            } message: {
                Text("This cannot be undone.")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundColor(Color.txtTertiary)

            Text("No Records")
                .font(.title2.weight(.semibold))
                .foregroundColor(Color.txtPrimary)

            Text("Tap + to add your first triage record")
                .font(.subheadline)
                .foregroundColor(Color.txtSecondary)
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(Color.txtTertiary)

            Text("No Matching Records")
                .font(.title3.weight(.semibold))
                .foregroundColor(Color.txtPrimary)

            Text("Try adjusting your search or filters")
                .font(.subheadline)
                .foregroundColor(Color.txtSecondary)

            Button {
                HapticFeedback.impact(.light)
                searchText = ""
                filter.clear()
            } label: {
                Text("Clear All Filters")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color.accentTeal)
            }
            .padding(.top, 8)
        }
    }

    private var activeFiltersIndicator: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundColor(Color.accentTeal)
                .font(.caption)

            Text("\(filter.activeFilterCount) filter\(filter.activeFilterCount == 1 ? "" : "s") active")
                .font(.caption.weight(.medium))
                .foregroundColor(Color.txtSecondary)

            Text("·")
                .foregroundColor(Color.txtTertiary)

            Text("\(filteredRecords.count) of \(records.count) records")
                .font(.caption)
                .foregroundColor(Color.txtTertiary)

            Spacer()

            Button {
                HapticFeedback.impact(.light)
                filter.clear()
            } label: {
                Text("Clear")
                    .font(.caption.weight(.medium))
                    .foregroundColor(Color.prioUrgent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.txtTertiary)

            TextField("Search records...", text: $searchText)
                .foregroundColor(Color.txtPrimary)

            // Filter button
            Button {
                HapticFeedback.impact(.light)
                showingFilters = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .foregroundColor(filter.isActive ? Color.accentTeal : Color.txtTertiary)

                    // Badge for active filter count
                    if filter.isActive {
                        Text("\(filter.activeFilterCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.prioUrgent)
                            .clipShape(Circle())
                            .offset(x: 6, y: -6)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    private func deleteRecord(_ record: TriageRecord) {
        HapticFeedback.impact(.medium)
        modelContext.delete(record)
    }

    private func togglePriority(_ record: TriageRecord, to newPriority: Priority) {
        HapticFeedback.notification(.success)
        record.priorityEnum = newPriority
        record.lastModified = Date()
    }

    private func callPhoneNumber(_ number: String) {
        // Clean the phone number - remove non-numeric characters except +
        let cleaned = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard !cleaned.isEmpty,
              let url = URL(string: "tel://\(cleaned)") else {
            return
        }

        if UIApplication.shared.canOpenURL(url) {
            HapticFeedback.impact(.light)
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Record Card View

struct RecordCardView: View {
    let record: TriageRecord

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        Button {
            // Handled by parent
        } label: {
            HStack(spacing: 0) {
                // Priority indicator bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(record.priorityEnum.color)
                    .frame(width: 3)

                // Content
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(record.displayName)
                            .font(MedDarkTypography.listTitle)
                            .foregroundColor(Color.txtPrimary)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(dateFormatter.string(from: record.dateReceived))
                                .font(.caption)
                        }
                        .foregroundColor(Color.txtSecondary)
                    }

                    Text(record.chiefComplaintSnippet)
                        .font(MedDarkTypography.listSubtitle)
                        .foregroundColor(Color.txtSecondary)
                        .lineLimit(2)

                    // Bottom row with metadata
                    HStack(spacing: 12) {
                        if let callback = record.callbackNumber, !callback.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "phone.arrow.up.right")
                                Text(callback)
                            }
                            .font(.caption)
                            .foregroundColor(Color.txtTertiary)
                        }

                        Spacer()

                        // Priority badge
                        HStack(spacing: 4) {
                            Image(systemName: record.priorityEnum.icon)
                            Text(record.priorityEnum.rawValue)
                        }
                        .font(.caption.weight(.medium))
                        .foregroundColor(record.priorityEnum.color)

                        if record.followUpNeeded {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(Color.prioUrgent)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(CardPressStyle())
    }
}

#Preview {
    RecordListView()
        .modelContainer(for: TriageRecord.self, inMemory: true)
}
