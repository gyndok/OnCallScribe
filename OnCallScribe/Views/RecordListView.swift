import SwiftUI
import SwiftData

struct RecordListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TriageRecord.dateReceived, order: .reverse) private var records: [TriageRecord]

    @State private var searchText = ""
    @State private var showingNewRecord = false
    @State private var showingSettings = false
    @State private var showingExport = false
    @State private var selectedRecord: TriageRecord?

    @AppStorage("onCallPhysicianName") private var physicianName = ""

    private var filteredRecords: [TriageRecord] {
        if searchText.isEmpty {
            return records
        }

        let lowercasedSearch = searchText.lowercased()
        return records.filter { record in
            record.patientName?.lowercased().contains(lowercasedSearch) == true ||
            record.attendingDoctor?.lowercased().contains(lowercasedSearch) == true ||
            record.chiefComplaint?.lowercased().contains(lowercasedSearch) == true ||
            record.advice?.lowercased().contains(lowercasedSearch) == true ||
            record.disposition?.lowercased().contains(lowercasedSearch) == true ||
            record.tags.contains { $0.lowercased().contains(lowercasedSearch) }
        }
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

                            // Record cards
                            ForEach(filteredRecords) { record in
                                RecordCardView(record: record)
                                    .padding(.horizontal, 16)
                                    .onTapGesture {
                                        HapticFeedback.impact(.light)
                                        selectedRecord = record
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            deleteRecord(record)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
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

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.txtTertiary)

            TextField("Search records...", text: $searchText)
                .foregroundColor(Color.txtPrimary)
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
