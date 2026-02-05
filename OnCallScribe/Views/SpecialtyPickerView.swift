import SwiftUI

struct SpecialtyPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSpecialty: String

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(MedicalSpecialty.allCases) { specialty in
                            Button {
                                HapticFeedback.impact(.light)
                                selectedSpecialty = specialty.rawValue
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: specialty.icon)
                                        .font(.title3)
                                        .foregroundColor(selectedSpecialty == specialty.rawValue ? Color.accentTeal : Color.txtTertiary)
                                        .frame(width: 28)

                                    Text(specialty.rawValue)
                                        .font(.body)
                                        .foregroundColor(Color.txtPrimary)

                                    Spacer()

                                    if selectedSpecialty == specialty.rawValue {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color.accentTeal)
                                    }
                                }
                                .padding(16)
                                .background(selectedSpecialty == specialty.rawValue ? Color.accentTeal.opacity(0.1) : Color.bgCard)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedSpecialty == specialty.rawValue ? Color.accentTeal : Color.border, lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(CardPressStyle())
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Select Specialty")
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
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SpecialtyPickerView(selectedSpecialty: .constant(MedicalSpecialty.obgyn.rawValue))
}
