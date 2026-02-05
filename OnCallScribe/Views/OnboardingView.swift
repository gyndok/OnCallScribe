import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("selectedSpecialty") private var selectedSpecialtyRaw = ""
    @AppStorage("onCallPhysicianName") private var physicianName = ""

    @State private var currentStep = 0
    @State private var tempSpecialty: MedicalSpecialty?
    @State private var tempName = ""

    private var canProceed: Bool {
        switch currentStep {
        case 0: return true // Welcome
        case 1: return tempSpecialty != nil // Specialty selection
        case 2: return !tempName.trimmingCharacters(in: .whitespaces).isEmpty // Name
        default: return true
        }
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<3) { step in
                        Capsule()
                            .fill(step <= currentStep ? Color.accentTeal : Color.border)
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Content
                switch currentStep {
                case 0:
                    welcomeStep
                case 1:
                    specialtyStep
                case 2:
                    nameStep
                default:
                    EmptyView()
                }

                Spacer()

                // Bottom button
                Button {
                    HapticFeedback.impact()
                    advanceStep()
                } label: {
                    Text(currentStep == 2 ? "Get Started" : "Continue")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canProceed ? Color.accentTeal : Color.accentTeal.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canProceed)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "stethoscope")
                .font(.system(size: 80))
                .foregroundColor(Color.accentTeal)

            Text("Welcome to\nOnCall Scribe")
                .font(.largeTitle.weight(.bold))
                .foregroundColor(Color.txtPrimary)
                .multilineTextAlignment(.center)

            Text("The fastest way to document on-call triage messages. Let's customize the app for your practice.")
                .font(.body)
                .foregroundColor(Color.txtSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var specialtyStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Select Your Specialty")
                    .font(.title.weight(.bold))
                    .foregroundColor(Color.txtPrimary)

                Text("This customizes the app for your practice")
                    .font(.subheadline)
                    .foregroundColor(Color.txtSecondary)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(MedicalSpecialty.allCases) { specialty in
                        Button {
                            HapticFeedback.impact(.light)
                            withAnimation {
                                tempSpecialty = specialty
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: specialty.icon)
                                    .font(.title3)
                                    .foregroundColor(tempSpecialty == specialty ? Color.accentTeal : Color.txtTertiary)
                                    .frame(width: 28)

                                Text(specialty.rawValue)
                                    .font(.body)
                                    .foregroundColor(Color.txtPrimary)

                                Spacer()

                                if tempSpecialty == specialty {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color.accentTeal)
                                }
                            }
                            .padding(14)
                            .background(tempSpecialty == specialty ? Color.accentTeal.opacity(0.1) : Color.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(tempSpecialty == specialty ? Color.accentTeal : Color.border, lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(CardPressStyle())
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private var nameStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Enter Your Name")
                    .font(.title.weight(.bold))
                    .foregroundColor(Color.txtPrimary)

                Text("Used as the default on-call physician")
                    .font(.subheadline)
                    .foregroundColor(Color.txtSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.clock")
                        .foregroundColor(Color.txtTertiary)
                    Text("Your Name")
                        .font(MedDarkTypography.fieldLabel)
                        .foregroundColor(Color.txtSecondary)
                }

                TextField("e.g., Dr. Smith", text: $tempName)
                    .font(.body)
                    .foregroundColor(Color.txtPrimary)
                    .formFieldStyle()
            }
            .padding(.horizontal, 24)

            if let specialty = tempSpecialty {
                HStack(spacing: 8) {
                    Image(systemName: specialty.icon)
                        .foregroundColor(Color.accentTeal)
                    Text(specialty.rawValue)
                        .font(.subheadline)
                        .foregroundColor(Color.txtSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.bgCard)
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Actions

    private func advanceStep() {
        if currentStep < 2 {
            withAnimation {
                currentStep += 1
            }
        } else {
            // Complete onboarding
            if let specialty = tempSpecialty {
                selectedSpecialtyRaw = specialty.rawValue
            }
            physicianName = tempName.trimmingCharacters(in: .whitespaces)
            hasCompletedOnboarding = true
        }
    }
}

#Preview {
    OnboardingView()
}
