import SwiftUI
import SwiftData

enum RecordFormMode {
    case create
    case edit(TriageRecord)

    var isEditing: Bool {
        if case .edit = self { return true }
        return false
    }

    var navigationTitle: String {
        isEditing ? "Edit Record" : "New Record"
    }
}

enum ParsingState {
    case idle
    case parsing
    case completed(usedAI: Bool)
    case failed
}

struct RecordFormView: View {
    init(mode: RecordFormMode) {
        self.mode = mode
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: RecordFormMode

    @AppStorage("onCallPhysicianName") private var defaultPhysicianName = ""
    @AppStorage("selectedSpecialty") private var selectedSpecialtyRaw = MedicalSpecialty.other.rawValue

    // Raw message
    @State private var rawMessage = ""
    @State private var hasParsed = false
    @State private var parsingState: ParsingState = .idle

    // Parsed/Editable fields
    @State private var patientName = ""
    @State private var attendingDoctor = ""
    @State private var selectedDoctorFromList: String? = nil
    @State private var isOtherDoctor = false
    @State private var callbackNumber = ""

    @ObservedObject private var doctorManager = DoctorListManager.shared
    @State private var dateOfBirth: Date?
    @State private var showDOBPicker = false
    @State private var obStatus = ""
    @State private var chiefComplaint = ""

    // Specialty-specific fields
    @State private var patientAge = ""  // Pediatrics
    @State private var gestationalAge = ""  // OBGYN
    @State private var safetyConcerns = ""  // Psychiatry

    // Physician documentation
    @State private var advice = ""
    @State private var selectedDisposition: String?
    @State private var otherDisposition = ""
    @State private var priority: Priority = .routine
    @State private var callbackCompleted = false
    @State private var followUpNeeded = false
    @State private var followUpNote = ""
    @State private var onCallPhysician = ""

    private var currentSpecialty: MedicalSpecialty {
        MedicalSpecialty(rawValue: selectedSpecialtyRaw) ?? .other
    }

    private var canSave: Bool {
        !rawMessage.isEmpty || !chiefComplaint.isEmpty || !patientName.isEmpty
    }

    /// Date range for DOB picker: Jan 1, 1900 to today
    private var dobDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        var minComponents = DateComponents()
        minComponents.year = 1900
        minComponents.month = 1
        minComponents.day = 1
        let minDate = calendar.date(from: minComponents) ?? Date.distantPast
        return minDate...Date()
    }

    /// Default starting date for DOB picker when no date is selected (30 years ago)
    private var defaultDOBPickerDate: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    }

    /// Formats a date as MM/DD/YYYY (always 4-digit year)
    private func formatDOB(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }

    private var isParsing: Bool {
        if case .parsing = parsingState { return true }
        return false
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Message Input Section
                    if !mode.isEditing {
                        pasteSection
                    }

                    // Parsing indicator
                    if isParsing {
                        parsingIndicator
                    }

                    // Raw message display/edit
                    rawMessageSection

                    // Patient Information
                    patientInfoSection

                    // Chief Complaint
                    chiefComplaintSection

                    // Physician Response
                    physicianResponseSection

                    // Follow-up
                    followUpSection

                    // Save Button
                    Button {
                        HapticFeedback.impact()
                        saveRecord()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Save Record")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(isEnabled: canSave))
                    .disabled(!canSave || isParsing)
                    .padding(.top, 8)
                }
                .padding(16)
            }
            .disabled(isParsing)
        }
        .navigationTitle(mode.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bgPrimary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(Color.txtSecondary)
                .disabled(isParsing)
            }
        }
        .onAppear {
            loadInitialData()
        }
        .onChange(of: rawMessage) { oldValue, newValue in
            if !mode.isEditing && newValue.count > oldValue.count + 10 && !hasParsed {
                Task {
                    await parseMessage()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var pasteSection: some View {
        VStack(spacing: 12) {
            Button {
                pasteFromClipboard()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.title2)
                    Text("Paste from Clipboard")
                        .font(.headline.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.accentTeal)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(CardPressStyle())
            .disabled(isParsing)

            HStack(spacing: 6) {
                if AIMessageParser.shared.isAvailable {
                    Image(systemName: "cpu")
                        .font(.caption2)
                        .foregroundColor(Color.accentTeal)
                    Text("AI-powered parsing enabled")
                        .font(.caption)
                        .foregroundColor(Color.accentTeal)
                } else {
                    Text("Copy a triage message, then tap above to auto-parse")
                        .font(.caption)
                        .foregroundColor(Color.txtTertiary)
                }
            }
            .multilineTextAlignment(.center)
        }
    }

    private var parsingIndicator: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Color.accentTeal)

            VStack(alignment: .leading, spacing: 2) {
                Text("Parsing message...")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color.txtPrimary)

                if AIMessageParser.shared.isAvailable {
                    Text("Using on-device AI")
                        .font(.caption)
                        .foregroundColor(Color.accentTeal)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentTeal.opacity(0.5), lineWidth: 1)
        )
    }

    private var rawMessageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ORIGINAL MESSAGE")
                    .sectionHeader()

                Spacer()

                if case .completed(let usedAI) = parsingState {
                    HStack(spacing: 4) {
                        Image(systemName: usedAI ? "cpu" : "text.magnifyingglass")
                            .font(.caption2)
                        Text(usedAI ? "AI parsed" : "Regex parsed")
                            .font(.caption)
                    }
                    .foregroundColor(Color.txtTertiary)
                }
            }

            TextEditor(text: $rawMessage)
                .font(.body)
                .foregroundColor(Color.txtPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(12)
                .background(Color.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.border, lineWidth: 1)
                )
        }
    }

    private var patientInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TRIAGE INFO")
                .sectionHeader()

            FormField(
                icon: "person",
                label: "Patient Name",
                text: $patientName,
                placeholder: "Enter patient name"
            )

            // Attending Doctor Picker
            DoctorPickerField(
                selectedDoctor: $selectedDoctorFromList,
                otherDoctorName: $attendingDoctor,
                isOtherSelected: $isOtherDoctor,
                doctors: doctorManager.doctors
            )

            FormField(
                icon: "phone.arrow.up.right",
                label: "Callback Number",
                text: $callbackNumber,
                placeholder: "(555) 555-5555",
                keyboardType: .phonePad
            )

            // Date of Birth
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundColor(Color.txtTertiary)
                    Text("Date of Birth")
                        .font(MedDarkTypography.fieldLabel)
                        .foregroundColor(Color.txtSecondary)
                }

                Button {
                    withAnimation {
                        showDOBPicker.toggle()
                    }
                } label: {
                    HStack {
                        if let dob = dateOfBirth {
                            Text(formatDOB(dob))
                                .foregroundColor(Color.txtPrimary)
                        } else {
                            Text("Select date of birth")
                                .foregroundColor(Color.txtTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(Color.txtTertiary)
                            .rotationEffect(.degrees(showDOBPicker ? 180 : 0))
                    }
                    .formFieldStyle()
                }

                if showDOBPicker {
                    DatePicker(
                        "Date of Birth",
                        selection: Binding(
                            get: { dateOfBirth ?? defaultDOBPickerDate },
                            set: { dateOfBirth = $0 }
                        ),
                        in: dobDateRange,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .background(Color.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Specialty-specific fields
            if currentSpecialty.showsOBStatus {
                FormField(
                    icon: "heart.text.square",
                    label: "OB Status",
                    text: $obStatus,
                    placeholder: "OB, Not OB, Postpartum, etc."
                )

                FormField(
                    icon: "calendar.badge.clock",
                    label: "Gestational Age",
                    text: $gestationalAge,
                    placeholder: "e.g., 32 weeks, 32w4d"
                )
            }

            if currentSpecialty.showsPediatricFields {
                FormField(
                    icon: "figure.child",
                    label: "Patient Age",
                    text: $patientAge,
                    placeholder: "e.g., 3 years, 18 months, newborn"
                )
            }

            if currentSpecialty.showsSafetyConcerns {
                FormField(
                    icon: "exclamationmark.shield",
                    label: "Safety Concerns",
                    text: $safetyConcerns,
                    placeholder: "SI, HI, self-harm, etc."
                )
            }
        }
    }

    private var chiefComplaintSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(currentSpecialty.chiefComplaintLabel.uppercased())
                .sectionHeader()

            TextEditor(text: $chiefComplaint)
                .font(.body)
                .foregroundColor(Color.txtPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(12)
                .background(Color.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.border, lineWidth: 1)
                )
        }
    }

    private var physicianResponseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PHYSICIAN RESPONSE")
                .sectionHeader()

            // Priority Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Priority")
                    .font(MedDarkTypography.fieldLabel)
                    .foregroundColor(Color.txtSecondary)

                HStack(spacing: 8) {
                    ForEach(Priority.allCases) { p in
                        Button {
                            HapticFeedback.impact(.light)
                            withAnimation {
                                priority = p
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: p.icon)
                                Text(p.rawValue)
                            }
                        }
                        .buttonStyle(PriorityPillStyle(priority: p, isSelected: priority == p))
                    }
                }
            }

            // Advice
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .foregroundColor(Color.txtTertiary)
                    Text("Advice / Plan")
                        .font(MedDarkTypography.fieldLabel)
                        .foregroundColor(Color.txtSecondary)
                }

                TextEditor(text: $advice)
                    .font(.body)
                    .foregroundColor(Color.txtPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .padding(12)
                    .background(Color.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.border, lineWidth: 1)
                    )
            }

            // Disposition (specialty-specific)
            VStack(alignment: .leading, spacing: 8) {
                Text("Disposition")
                    .font(MedDarkTypography.fieldLabel)
                    .foregroundColor(Color.txtSecondary)

                SpecialtyDispositionPicker(
                    selection: $selectedDisposition,
                    options: currentSpecialty.dispositionOptions
                )

                if selectedDisposition == "Other" {
                    TextField("Specify disposition", text: $otherDisposition)
                        .foregroundColor(Color.txtPrimary)
                        .formFieldStyle()
                }
            }

            // On-Call Physician
            FormField(
                icon: "person.badge.clock",
                label: "On-Call Physician",
                text: $onCallPhysician,
                placeholder: "Your name"
            )
        }
    }

    private var followUpSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FOLLOW-UP")
                .sectionHeader()

            // Callback Completed Toggle
            ToggleRow(
                icon: "checkmark.circle.fill",
                iconColor: callbackCompleted ? Color.prioRoutine : Color.txtTertiary,
                title: "Callback Completed",
                isOn: $callbackCompleted
            )

            // Follow-up Needed Toggle
            ToggleRow(
                icon: "exclamationmark.triangle",
                iconColor: followUpNeeded ? Color.prioUrgent : Color.txtTertiary,
                title: "Follow-up Needed",
                isOn: $followUpNeeded
            )

            if followUpNeeded {
                TextField("Follow-up notes", text: $followUpNote)
                    .foregroundColor(Color.txtPrimary)
                    .formFieldStyle()
            }
        }
    }

    // MARK: - Actions

    private func loadInitialData() {
        onCallPhysician = defaultPhysicianName

        if case .edit(let record) = mode {
            rawMessage = record.rawMessage
            patientName = record.patientName ?? ""
            attendingDoctor = record.attendingDoctor ?? ""
            callbackNumber = record.callbackNumber ?? ""
            dateOfBirth = record.dateOfBirth
            obStatus = record.obStatus ?? ""
            chiefComplaint = record.chiefComplaint ?? ""
            patientAge = record.patientAge ?? ""
            gestationalAge = record.gestationalAge ?? ""
            safetyConcerns = record.safetyConcerns ?? ""
            advice = record.advice ?? ""
            priority = record.priorityEnum
            callbackCompleted = record.callbackCompleted
            followUpNeeded = record.followUpNeeded
            followUpNote = record.followUpNote ?? ""
            onCallPhysician = record.onCallPhysician

            // Set doctor picker state based on whether the doctor is in the saved list
            if let doctor = record.attendingDoctor, !doctor.isEmpty {
                if doctorManager.doctors.contains(doctor) {
                    selectedDoctorFromList = doctor
                    isOtherDoctor = false
                } else {
                    selectedDoctorFromList = nil
                    isOtherDoctor = true
                }
            }

            // Load disposition
            if let dispositionStr = record.disposition {
                let recordSpecialty = MedicalSpecialty(rawValue: record.specialty) ?? currentSpecialty
                if recordSpecialty.dispositionOptions.contains(dispositionStr) {
                    selectedDisposition = dispositionStr
                } else {
                    selectedDisposition = "Other"
                    otherDisposition = dispositionStr
                }
            }

            hasParsed = true
        }
    }

    private func pasteFromClipboard() {
        if let clipboardText = UIPasteboard.general.string {
            rawMessage = clipboardText
            Task {
                await parseMessage()
            }
        }
    }

    @MainActor
    private func parseMessage() async {
        guard !rawMessage.isEmpty else { return }

        parsingState = .parsing

        // Try AI parsing first if available
        if AIMessageParser.shared.isAvailable {
            do {
                let aiParsed = try await AIMessageParser.shared.parse(rawMessage, specialty: currentSpecialty)
                applyAIParsedResult(aiParsed)
                parsingState = .completed(usedAI: true)
                HapticFeedback.success()
                hasParsed = true
                return
            } catch {
                // Fall through to regex parser
                print("AI parsing failed, falling back to regex: \(error)")
            }
        }

        // Fallback to regex parser
        let regexParsed = MessageParser.shared.parse(rawMessage)
        applyRegexParsedResult(regexParsed)
        parsingState = .completed(usedAI: false)
        HapticFeedback.success()
        hasParsed = true
    }

    private func applyAIParsedResult(_ parsed: ParsedTriageMessage) {
        if let name = parsed.patientName, !name.isEmpty {
            patientName = name
        }
        if let doctor = parsed.attendingDoctor, !doctor.isEmpty {
            attendingDoctor = doctor
            updateDoctorPickerState(for: doctor)
        }
        if let phone = parsed.callbackNumber, !phone.isEmpty {
            callbackNumber = phone
        }
        if let dob = parsed.dateOfBirthAsDate {
            dateOfBirth = dob
        }
        if let ob = parsed.obStatus, !ob.isEmpty {
            obStatus = ob
        }
        if let complaint = parsed.chiefComplaint, !complaint.isEmpty {
            chiefComplaint = complaint
        }
        // Specialty-specific fields
        if let ga = parsed.gestationalAge, !ga.isEmpty {
            gestationalAge = ga
        }
        if let age = parsed.patientAge, !age.isEmpty {
            patientAge = age
        }
        if let safety = parsed.safetyConcerns, !safety.isEmpty {
            safetyConcerns = safety
        }
    }

    private func applyRegexParsedResult(_ parsed: ParsedMessage) {
        if let name = parsed.patientName, !name.isEmpty {
            patientName = name
        }
        if let doctor = parsed.attendingDoctor, !doctor.isEmpty {
            attendingDoctor = doctor
            updateDoctorPickerState(for: doctor)
        }
        if let phone = parsed.callbackNumber, !phone.isEmpty {
            callbackNumber = phone
        }
        if let dob = parsed.dateOfBirth {
            dateOfBirth = dob
        }
        if let ob = parsed.obStatus, !ob.isEmpty {
            obStatus = ob
        }
        if let complaint = parsed.chiefComplaint, !complaint.isEmpty {
            chiefComplaint = complaint
        }
    }

    private func updateDoctorPickerState(for doctor: String) {
        // Check if parsed doctor matches any in the saved list (case-insensitive)
        if let match = doctorManager.doctors.first(where: { $0.lowercased() == doctor.lowercased() }) {
            selectedDoctorFromList = match
            isOtherDoctor = false
        } else {
            selectedDoctorFromList = nil
            isOtherDoctor = true
        }
    }

    private func saveRecord() {
        let finalDisposition: String?
        if selectedDisposition == "Other" && !otherDisposition.isEmpty {
            finalDisposition = otherDisposition
        } else {
            finalDisposition = selectedDisposition
        }

        if case .edit(let record) = mode {
            record.rawMessage = rawMessage
            record.patientName = patientName.isEmpty ? nil : patientName
            record.attendingDoctor = attendingDoctor.isEmpty ? nil : attendingDoctor
            record.callbackNumber = callbackNumber.isEmpty ? nil : callbackNumber
            record.dateOfBirth = dateOfBirth
            record.obStatus = obStatus.isEmpty ? nil : obStatus
            record.chiefComplaint = chiefComplaint.isEmpty ? nil : chiefComplaint
            record.specialty = currentSpecialty.rawValue
            record.patientAge = patientAge.isEmpty ? nil : patientAge
            record.gestationalAge = gestationalAge.isEmpty ? nil : gestationalAge
            record.safetyConcerns = safetyConcerns.isEmpty ? nil : safetyConcerns
            record.advice = advice.isEmpty ? nil : advice
            record.disposition = finalDisposition
            record.priorityEnum = priority
            record.callbackCompleted = callbackCompleted
            record.followUpNeeded = followUpNeeded
            record.followUpNote = followUpNote.isEmpty ? nil : followUpNote
            record.onCallPhysician = onCallPhysician
            record.lastModified = Date()
        } else {
            let record = TriageRecord(
                rawMessage: rawMessage,
                attendingDoctor: attendingDoctor.isEmpty ? nil : attendingDoctor,
                patientName: patientName.isEmpty ? nil : patientName,
                callbackNumber: callbackNumber.isEmpty ? nil : callbackNumber,
                dateOfBirth: dateOfBirth,
                obStatus: obStatus.isEmpty ? nil : obStatus,
                chiefComplaint: chiefComplaint.isEmpty ? nil : chiefComplaint,
                specialty: currentSpecialty,
                patientAge: patientAge.isEmpty ? nil : patientAge,
                gestationalAge: gestationalAge.isEmpty ? nil : gestationalAge,
                safetyConcerns: safetyConcerns.isEmpty ? nil : safetyConcerns,
                advice: advice.isEmpty ? nil : advice,
                disposition: finalDisposition,
                priority: priority,
                callbackCompleted: callbackCompleted,
                followUpNeeded: followUpNeeded,
                followUpNote: followUpNote.isEmpty ? nil : followUpNote,
                onCallPhysician: onCallPhysician
            )
            modelContext.insert(record)
        }

        HapticFeedback.success()
        dismiss()
    }
}

// MARK: - Form Components

struct FormField: View {
    let icon: String
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(Color.txtTertiary)
                Text(label)
                    .font(MedDarkTypography.fieldLabel)
                    .foregroundColor(Color.txtSecondary)
            }

            TextField(placeholder, text: $text)
                .font(.body)
                .foregroundColor(Color.txtPrimary)
                .keyboardType(keyboardType)
                .formFieldStyle()
        }
    }
}

struct ToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)

            Text(title)
                .font(MedDarkTypography.fieldLabel)
                .foregroundColor(Color.txtPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(Color.accentTeal)
                .labelsHidden()
        }
        .padding(12)
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.border, lineWidth: 1)
        )
    }
}

struct SpecialtyDispositionPicker: View {
    @Binding var selection: String?
    let options: [String]

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    HapticFeedback.impact(.light)
                    withAnimation {
                        selection = (selection == option) ? nil : option
                    }
                } label: {
                    HStack(spacing: 6) {
                        if selection == option {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                        }
                        Text(option)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundColor(selection == option ? .white : Color.txtSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 8)
                    .background(selection == option ? Color.accentTeal : Color.bgSecondary)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(selection == option ? Color.clear : Color.border, lineWidth: 1)
                    )
                }
                .buttonStyle(CardPressStyle())
            }
        }
    }
}

struct DoctorPickerField: View {
    @Binding var selectedDoctor: String?
    @Binding var otherDoctorName: String
    @Binding var isOtherSelected: Bool
    let doctors: [String]

    @State private var isExpanded = false

    private var displayValue: String {
        if isOtherSelected {
            return otherDoctorName.isEmpty ? "Other (enter name)" : "Dr. \(otherDoctorName)"
        } else if let selected = selectedDoctor {
            return "Dr. \(selected)"
        } else {
            return "Select attending doctor"
        }
    }

    private var hasSelection: Bool {
        isOtherSelected || selectedDoctor != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "stethoscope")
                    .foregroundColor(Color.txtTertiary)
                Text("Attending Doctor")
                    .font(MedDarkTypography.fieldLabel)
                    .foregroundColor(Color.txtSecondary)
            }

            // Main selector button
            Button {
                HapticFeedback.impact(.light)
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(displayValue)
                        .foregroundColor(hasSelection ? Color.txtPrimary : Color.txtTertiary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(Color.txtTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .formFieldStyle()
            }

            // Expandable options
            if isExpanded {
                VStack(spacing: 0) {
                    // Saved doctors
                    ForEach(doctors, id: \.self) { doctor in
                        Button {
                            HapticFeedback.impact(.light)
                            selectedDoctor = doctor
                            otherDoctorName = doctor
                            isOtherSelected = false
                            withAnimation {
                                isExpanded = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedDoctor == doctor && !isOtherSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedDoctor == doctor && !isOtherSelected ? Color.accentTeal : Color.txtTertiary)

                                Text("Dr. \(doctor)")
                                    .foregroundColor(Color.txtPrimary)

                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                        }

                        Divider()
                            .background(Color.dividerColor)
                    }

                    // "Other" option
                    Button {
                        HapticFeedback.impact(.light)
                        selectedDoctor = nil
                        isOtherSelected = true
                        // Don't close - let them type
                    } label: {
                        HStack {
                            Image(systemName: isOtherSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isOtherSelected ? Color.accentTeal : Color.txtTertiary)

                            Text("Other")
                                .foregroundColor(Color.txtPrimary)

                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                    }
                }
                .background(Color.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.border, lineWidth: 1)
                )

                // Text field for "Other" option
                if isOtherSelected {
                    TextField("Enter doctor's name", text: $otherDoctorName)
                        .font(.body)
                        .foregroundColor(Color.txtPrimary)
                        .formFieldStyle()
                        .onSubmit {
                            withAnimation {
                                isExpanded = false
                            }
                        }
                }
            }
        }
    }
}

#Preview("Create") {
    NavigationStack {
        RecordFormView(mode: .create)
    }
    .modelContainer(for: TriageRecord.self, inMemory: true)
}
