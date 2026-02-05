import SwiftUI
import UIKit

// MARK: - MedDark Design System

extension Color {
    // MARK: Background Colors
    static let backgroundPrimary = Color("BackgroundPrimary")
    static let backgroundSecondary = Color("BackgroundSecondary")
    static let backgroundCard = Color("BackgroundCard")

    // MARK: Accent Colors
    static let accentPrimary = Color("AccentPrimary")
    static let accentSecondary = Color("AccentSecondary")

    // MARK: Text Colors
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let textTertiary = Color("TextTertiary")

    // MARK: Priority Colors
    static let priorityRoutine = Color("PriorityRoutine")
    static let priorityUrgent = Color("PriorityUrgent")
    static let priorityEmergent = Color("PriorityEmergent")

    // MARK: Semantic Colors
    static let destructive = Color("Destructive")
    static let cardBorder = Color("CardBorder")
    static let divider = Color("Divider")
}

// MARK: - Hex Color Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Adaptive Colors (for when Asset Catalog colors aren't available)

extension Color {
    static func adaptive(dark: String, light: String) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }

    // Fallback definitions using adaptive colors
    static let bgPrimary = adaptive(dark: "0D1117", light: "F6F8FA")
    static let bgSecondary = adaptive(dark: "161B22", light: "FFFFFF")
    static let bgCard = adaptive(dark: "1C2128", light: "FFFFFF")
    static let accentTeal = Color(hex: "2DA8A8")
    static let accentTealDark = Color(hex: "1A6B6B")
    static let txtPrimary = adaptive(dark: "E6EDF3", light: "1F2328")
    static let txtSecondary = Color(hex: "8B949E")
    static let txtTertiary = adaptive(dark: "484F58", light: "656D76")
    static let prioRoutine = Color(hex: "3FB950")
    static let prioUrgent = Color(hex: "D29922")
    static let prioEmergent = Color(hex: "F85149")
    static let border = Color(hex: "30363D")
    static let dividerColor = Color(hex: "21262D")
}

// MARK: - Typography
// All fonts use system text styles for Dynamic Type support

struct MedDarkTypography {
    // List row title
    static let listTitle = Font.headline.weight(.semibold)

    // List row subtitle
    static let listSubtitle = Font.subheadline.weight(.regular)

    // Card section headers
    static let sectionHeader = Font.caption.weight(.bold)

    // Form field labels
    static let fieldLabel = Font.subheadline.weight(.medium)

    // Navigation large title
    static let largeTitle = Font.largeTitle.weight(.bold)

    // Body text (slightly larger for tired eyes)
    static let body = Font.body

    // Caption
    static let caption = Font.caption
}

// MARK: - Scaled Metrics for Accessibility

/// Use these for any fixed-size elements that should scale with Dynamic Type
struct AccessibilityMetrics {
    @ScaledMetric(relativeTo: .body) static var iconSizeSmall: CGFloat = 16
    @ScaledMetric(relativeTo: .body) static var iconSizeMedium: CGFloat = 24
    @ScaledMetric(relativeTo: .body) static var iconSizeLarge: CGFloat = 32
    @ScaledMetric(relativeTo: .body) static var iconSizeXLarge: CGFloat = 48
    @ScaledMetric(relativeTo: .body) static var iconSizeHero: CGFloat = 64
    @ScaledMetric(relativeTo: .caption) static var badgeSize: CGFloat = 16
    @ScaledMetric(relativeTo: .body) static var minTouchTarget: CGFloat = 44
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    let priority: Priority?

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.border, lineWidth: 0.5)
            )
            .overlay(alignment: .leading) {
                if let priority = priority {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(priority.color)
                        .frame(width: 3)
                        .padding(.vertical, 8)
                }
            }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled ? Color.accentTeal : Color.accentTeal.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct FormFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.border, lineWidth: 1)
            )
    }
}

struct PriorityPillStyle: ButtonStyle {
    let priority: Priority
    let isSelected: Bool

    private var backgroundColor: Color {
        isSelected ? priority.color : Color.bgSecondary
    }

    private var foregroundColor: Color {
        isSelected ? .white : Color.txtSecondary
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(backgroundColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle(priority: Priority? = nil) -> some View {
        modifier(CardStyle(priority: priority))
    }

    func formFieldStyle() -> some View {
        modifier(FormFieldStyle())
    }

    func sectionHeader() -> some View {
        self
            .font(MedDarkTypography.sectionHeader)
            .foregroundColor(Color.txtTertiary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

// MARK: - Priority Extension

extension Priority {
    var color: Color {
        switch self {
        case .routine: return Color.prioRoutine
        case .urgent: return Color.prioUrgent
        case .emergent: return Color.prioEmergent
        }
    }

    var icon: String {
        switch self {
        case .routine: return "circle.fill"
        case .urgent: return "exclamationmark.circle.fill"
        case .emergent: return "bolt.circle.fill"
        }
    }
}

// MARK: - Haptic Feedback

struct HapticFeedback {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    static func success() {
        notification(.success)
    }

    static func error() {
        notification(.error)
    }
}
