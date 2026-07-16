import SwiftUI

struct RecordFilter: Equatable {
    var startDate: Date?
    var endDate: Date?
    var priorities: Set<Priority> = []
    /// Disposition filter matches the exact strings records are saved with
    /// (specialty-specific options or custom "Other" text) — the old
    /// Disposition enum's rawValues no longer matched anything the form saves.
    var dispositions: Set<String> = []
    var followUpNeeded: Bool?
    var attendingDoctor: String?

    var isActive: Bool {
        startDate != nil ||
        endDate != nil ||
        !priorities.isEmpty ||
        !dispositions.isEmpty ||
        followUpNeeded != nil ||
        attendingDoctor != nil
    }

    var activeFilterCount: Int {
        var count = 0
        if startDate != nil { count += 1 }
        if endDate != nil { count += 1 }
        if !priorities.isEmpty { count += 1 }
        if !dispositions.isEmpty { count += 1 }
        if followUpNeeded != nil { count += 1 }
        if attendingDoctor != nil { count += 1 }
        return count
    }

    mutating func clear() {
        startDate = nil
        endDate = nil
        priorities = []
        dispositions = []
        followUpNeeded = nil
        attendingDoctor = nil
    }
}

struct SearchFilterView: View {
    @Binding var filter: RecordFilter
    @Environment(\.dismiss) private var dismiss

    let knownDoctors: [String]
    /// Distinct disposition strings that actually occur in the user's records,
    /// so every chip is guaranteed to match at least one record.
    let knownDispositions: [String]

    @State private var showStartDatePicker = false
    @State private var showEndDatePicker = false
    @State private var tempStartDate = Date()
    @State private var tempEndDate = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Date Range Section
                        filterSection(title: "DATE RANGE") {
                            VStack(spacing: 12) {
                                // Start Date — normalized to the start of the
                                // picked day so the whole day is included
                                dateFilterRow(
                                    label: "From",
                                    date: filter.startDate,
                                    showPicker: $showStartDatePicker,
                                    tempDate: $tempStartDate
                                ) { date in
                                    filter.startDate = date.map { Calendar.current.startOfDay(for: $0) }
                                }

                                // End Date — normalized to the end of the
                                // picked day; comparing the raw picker value
                                // (which carries a wall-clock time) silently
                                // excluded most of the "To" day's records
                                dateFilterRow(
                                    label: "To",
                                    date: filter.endDate,
                                    showPicker: $showEndDatePicker,
                                    tempDate: $tempEndDate
                                ) { date in
                                    filter.endDate = date.map(Self.endOfDay)
                                }
                            }
                        }

                        // Quick Date Presets
                        filterSection(title: "QUICK SELECT") {
                            HStack(spacing: 8) {
                                quickDateButton("Today") {
                                    setDateRange(days: 0)
                                }
                                quickDateButton("24h") {
                                    setDateRange(days: 1)
                                }
                                quickDateButton("Weekend") {
                                    setWeekendRange()
                                }
                                quickDateButton("Week") {
                                    setDateRange(days: 7)
                                }
                            }
                        }

                        // Priority Section
                        filterSection(title: "PRIORITY") {
                            HStack(spacing: 8) {
                                ForEach(Priority.allCases, id: \.self) { priority in
                                    priorityToggle(priority)
                                }
                            }
                        }

                        // Disposition Section
                        if !knownDispositions.isEmpty {
                            filterSection(title: "DISPOSITION") {
                                FlowLayout(spacing: 8) {
                                    ForEach(knownDispositions, id: \.self) { disposition in
                                        dispositionToggle(disposition)
                                    }
                                }
                            }
                        }

                        // Follow-up Section
                        filterSection(title: "FOLLOW-UP") {
                            HStack(spacing: 8) {
                                followUpToggle(label: "Needed", value: true)
                                followUpToggle(label: "Not Needed", value: false)
                                followUpToggle(label: "Any", value: nil)
                            }
                        }

                        // Attending Doctor Section
                        if !knownDoctors.isEmpty {
                            filterSection(title: "ATTENDING DOCTOR") {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        doctorToggle(nil, label: "Any")
                                        ForEach(knownDoctors, id: \.self) { doctor in
                                            doctorToggle(doctor, label: doctor)
                                        }
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.bgPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if filter.isActive {
                        Button("Clear") {
                            HapticFeedback.impact(.light)
                            filter.clear()
                        }
                        .foregroundColor(Color.prioUrgent)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color.accentTeal)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if filter.isActive {
                    activeFiltersBar
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Components

    private func filterSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .sectionHeader()

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dateFilterRow(
        label: String,
        date: Date?,
        showPicker: Binding<Bool>,
        tempDate: Binding<Date>,
        onSet: @escaping (Date?) -> Void
    ) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .foregroundColor(Color.txtSecondary)

                Spacer()

                if let date = date {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .foregroundColor(Color.txtPrimary)

                    Button {
                        HapticFeedback.impact(.light)
                        onSet(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.txtTertiary)
                    }
                } else {
                    Button {
                        tempDate.wrappedValue = date ?? Date()
                        showPicker.wrappedValue.toggle()
                        // Commit immediately: if the user then taps the
                        // already-selected day (e.g. today), onChange never
                        // fires and no filter would be applied.
                        if showPicker.wrappedValue {
                            onSet(tempDate.wrappedValue)
                        }
                    } label: {
                        Text("Select")
                            .foregroundColor(Color.accentTeal)
                    }
                }
            }
            .padding(12)
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if showPicker.wrappedValue {
                DatePicker(
                    "",
                    selection: tempDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .background(Color.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onChange(of: tempDate.wrappedValue) { _, newValue in
                    onSet(newValue)
                    showPicker.wrappedValue = false
                }
            }
        }
    }

    private func quickDateButton(_ label: String, action: @escaping () -> Void) -> some View {
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

    private func priorityToggle(_ priority: Priority) -> some View {
        let isSelected = filter.priorities.contains(priority)

        return Button {
            HapticFeedback.impact(.light)
            if isSelected {
                filter.priorities.remove(priority)
            } else {
                filter.priorities.insert(priority)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: priority.icon)
                Text(priority.rawValue)
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(isSelected ? .white : priority.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? priority.color : Color.bgSecondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : priority.color.opacity(0.5), lineWidth: 1)
            )
        }
    }

    private func dispositionToggle(_ disposition: String) -> some View {
        let isSelected = filter.dispositions.contains(disposition)

        return Button {
            HapticFeedback.impact(.light)
            if isSelected {
                filter.dispositions.remove(disposition)
            } else {
                filter.dispositions.insert(disposition)
            }
        } label: {
            Text(disposition)
                .font(.caption.weight(.medium))
                .foregroundColor(isSelected ? .white : Color.txtSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentTeal : Color.bgSecondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.border, lineWidth: 1)
                )
        }
    }

    private func followUpToggle(label: String, value: Bool?) -> some View {
        let isSelected = filter.followUpNeeded == value

        return Button {
            HapticFeedback.impact(.light)
            filter.followUpNeeded = value
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundColor(isSelected ? .white : Color.txtSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(isSelected ? Color.accentTeal : Color.bgSecondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.border, lineWidth: 1)
                )
        }
    }

    private func doctorToggle(_ doctor: String?, label: String) -> some View {
        let isSelected = filter.attendingDoctor == doctor

        return Button {
            HapticFeedback.impact(.light)
            filter.attendingDoctor = doctor
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundColor(isSelected ? .white : Color.txtSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(isSelected ? Color.accentTeal : Color.bgSecondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.border, lineWidth: 1)
                )
        }
    }

    private var activeFiltersBar: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundColor(Color.accentTeal)

            Text("\(filter.activeFilterCount) filter\(filter.activeFilterCount == 1 ? "" : "s") active")
                .font(.subheadline.weight(.medium))
                .foregroundColor(Color.txtPrimary)

            Spacer()

            Button("Clear All") {
                HapticFeedback.impact(.light)
                filter.clear()
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(Color.prioUrgent)
        }
        .padding(16)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.border),
            alignment: .top
        )
    }

    // MARK: - Date Helpers

    static func endOfDay(_ date: Date) -> Date {
        let start = Calendar.current.startOfDay(for: date)
        return Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }

    /// Presets set only a start bound. A frozen `endDate = now` excluded every
    /// record created after the preset was tapped — a "Today" filter that
    /// hides today's newest calls.
    private func setDateRange(days: Int) {
        let calendar = Calendar.current
        let now = Date()

        if days == 0 {
            // Today
            filter.startDate = calendar.startOfDay(for: now)
        } else {
            filter.startDate = calendar.date(byAdding: .day, value: -days, to: now)
        }
        filter.endDate = nil
    }

    /// The most recent on-call weekend: Friday 5pm through Monday 7am.
    private func setWeekendRange() {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now) // Sun=1 ... Sat=7

        // Days back to the most recent Friday (0 on Friday itself).
        let daysBackToFriday = (weekday + 1) % 7
        let friday = calendar.date(byAdding: .day, value: -daysBackToFriday, to: now)!
        var startDate = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: friday)!

        // On Friday before 5pm the weekend hasn't started — use last weekend.
        if startDate > now {
            startDate = calendar.date(byAdding: .day, value: -7, to: startDate)!
        }

        // The weekend ends the following Monday at 7am.
        let monday = calendar.date(byAdding: .day, value: 3, to: startDate)!
        let endDate = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: monday)!

        filter.startDate = startDate
        filter.endDate = endDate
    }
}

// MARK: - Flow Layout for Disposition Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing

                self.size.width = max(self.size.width, x - spacing)
            }

            self.size.height = y + rowHeight
        }
    }
}

#Preview {
    SearchFilterView(
        filter: .constant(RecordFilter()),
        knownDoctors: ["Dr. Smith", "Dr. Jones", "Dr. LaBerge"],
        knownDispositions: ["Sent to ER", "Advised home care", "Called in Rx"]
    )
}
