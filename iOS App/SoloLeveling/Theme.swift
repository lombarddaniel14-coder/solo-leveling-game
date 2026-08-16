import SwiftUI

/// Solo-Leveling "System" visual language: near-black space background, cyan
/// accents, gold highlights, condensed/mono panel feel, glowing borders.
public enum Theme {

    // MARK: - Colors

    public static let bg          = Color(hex: 0x0A0A0F) // deep space
    public static let bgPanel     = Color(hex: 0x0A1218) // panel fill
    public static let bgElevated  = Color(hex: 0x0F1C26) // raised panel
    public static let cyan        = Color(hex: 0x00D4FF) // primary accent
    public static let cyanSoft    = Color(hex: 0xA5CEDE) // muted cyan text
    public static let cyanDeep    = Color(hex: 0x5FB8D4)
    public static let gold        = Color(hex: 0xD4B45A) // highlight
    public static let goldBright  = Color(hex: 0xFFCF4D)
    public static let danger      = Color(hex: 0xFF3860)
    public static let success     = Color(hex: 0x2EDC8C)
    public static let textPrimary = Color(hex: 0xE8ECF2)
    public static let textDim     = Color(hex: 0x7A93A8)
    public static let border      = Color(hex: 0x1E3A4A)

    // MARK: - Fonts

    public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    public static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    // MARK: - Gradients

    public static var bgGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x05070B), Color(hex: 0x0A0F16), Color(hex: 0x081019)],
            startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Color hex init

public extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha)
    }
}

// MARK: - Reusable panel style

/// A glowing "system window" panel container.
public struct SystemPanel<Content: View>: View {
    private let content: Content
    private let accent: Color

    public init(accent: Color = Theme.cyan, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    public var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.bgPanel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(accent.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: accent.opacity(0.18), radius: 10, x: 0, y: 0)
    }
}

// MARK: - Section header

public struct SectionHeader: View {
    let text: String
    var accent: Color = Theme.cyan

    public init(_ text: String, accent: Color = Theme.cyan) {
        self.text = text
        self.accent = accent
    }

    public var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(accent)
                .frame(width: 3, height: 16)
            Text(text.uppercased())
                .font(Theme.mono(13, weight: .bold))
                .tracking(2)
                .foregroundColor(accent)
            Spacer()
        }
    }
}

// MARK: - Glowing progress bar

public struct GlowBar: View {
    let value: Double // 0...1
    var color: Color = Theme.cyan
    var height: CGFloat = 10

    public init(value: Double, color: Color = Theme.cyan, height: CGFloat = 10) {
        self.value = max(0, min(1, value))
        self.color = color
        self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Theme.bg.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: height / 2)
                            .stroke(Theme.border, lineWidth: 1))
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(colors: [color.opacity(0.7), color],
                                       startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, geo.size.width * value))
                    .shadow(color: color.opacity(0.7), radius: 6)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Primary button style

public struct SystemButtonStyle: ButtonStyle {
    var accent: Color = Theme.cyan
    var filled: Bool = true

    public init(accent: Color = Theme.cyan, filled: Bool = true) {
        self.accent = accent
        self.filled = filled
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.mono(14, weight: .bold))
            .tracking(1)
            .foregroundColor(filled ? Theme.bg : accent)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(filled ? accent : Color.clear))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(accent, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .shadow(color: accent.opacity(filled ? 0.5 : 0), radius: 8)
    }
}
