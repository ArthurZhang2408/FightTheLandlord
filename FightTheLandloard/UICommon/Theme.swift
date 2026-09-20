//
//  Theme.swift
//  FightTheLandlord
//
//  Design tokens. One accent, two role colors, semantic score colors, system
//  backgrounds for automatic light/dark support. Keep visual decisions here.
//

import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// A color that adapts to light and dark mode.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

enum AppTheme {
    // Brand
    static let accent = Color.dynamic(light: 0xB5432F, dark: 0xE06A55)      // 朱砂
    static let accentMuted = accent.opacity(0.12)

    // Roles
    static let gold = Color.dynamic(light: 0xA9832B, dark: 0xD8B15A)        // 地主
    static let jade = Color.dynamic(light: 0x2C8A66, dark: 0x5DBD96)        // 农民

    // Semantic score colors (which one means "win" is a user setting)
    static let green = Color.dynamic(light: 0x2D8F58, dark: 0x4FC47C)
    static let red = Color.dynamic(light: 0xC4392F, dark: 0xE5675C)

    // Surfaces
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let surfaceSecondary = Color(uiColor: .tertiarySystemGroupedBackground)
    static let fill = Color(uiColor: .tertiarySystemFill)
    static let hairline = Color(uiColor: .separator).opacity(0.55)

    // Text
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)

    enum Radius {
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 22
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    /// Color for a score value. Zero is neutral.
    static func scoreColor(_ value: Int, greenWin: Bool) -> Color {
        if value == 0 { return textSecondary }
        let positive = value > 0
        if greenWin { return positive ? green : red }
        return positive ? red : green
    }

    static func scoreColor(_ value: Double, greenWin: Bool) -> Color {
        scoreColor(value > 0 ? 1 : (value < 0 ? -1 : 0), greenWin: greenWin)
    }

    static func resultColor(win: Bool, greenWin: Bool) -> Color {
        scoreColor(win ? 1 : -1, greenWin: greenWin)
    }

    static func roleColor(isLandlord: Bool) -> Color {
        isLandlord ? gold : jade
    }

    /// Distinct colors for stake levels 1 / 2 / 3 分.
    static func stakeColor(_ bid: Int) -> Color {
        switch bid {
        case 3: return accent
        case 2: return gold
        case 1: return jade
        default: return textTertiary
        }
    }
}

enum AppFont {
    /// Rounded numerals for scores.
    static func score(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static let largeTitle = Font.system(.largeTitle, design: .default).weight(.bold)
    static let title = Font.system(.title2, design: .default).weight(.semibold)
    static let headline = Font.system(.headline, design: .default)
    static let body = Font.system(.body, design: .default)
    static let subheadline = Font.system(.subheadline, design: .default)
    static let caption = Font.system(.caption, design: .default)
    static let sectionTitle = Font.system(.footnote, design: .default).weight(.semibold)
}

extension PlayerColor {
    /// Refined tones that stay legible on both light and dark surfaces.
    var color: Color {
        switch self {
        case .blue: return Color.dynamic(light: 0x2E6FD9, dark: 0x5A90E6)
        case .green: return Color.dynamic(light: 0x2C9C5A, dark: 0x3FA866)
        case .orange: return Color.dynamic(light: 0xDA7A25, dark: 0xD98536)
        case .purple: return Color.dynamic(light: 0x7A4FD3, dark: 0x977AE4)
        case .red: return Color.dynamic(light: 0xD13A36, dark: 0xE45A52)
        case .teal: return Color.dynamic(light: 0x0A9BAB, dark: 0x2FA4B3)
        case .pink: return Color.dynamic(light: 0xD4388F, dark: 0xD45A98)
        case .indigo: return Color.dynamic(light: 0x3F52BD, dark: 0x7A86DA)
        }
    }
}

extension Player {
    var color: Color { resolvedColor.color }
}

// MARK: - Card style

struct CardModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 0.5)
            )
    }
}

extension View {
    /// Standard content card: surface color, continuous corners, hairline border.
    func card(padding: CGFloat = AppTheme.Spacing.l, radius: CGFloat = AppTheme.Radius.l) -> some View {
        modifier(CardModifier(padding: padding, radius: radius))
    }
}

// MARK: - Haptics

@MainActor
enum Haptics {
    static func light() {
        guard AppSettings.shared.hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        guard AppSettings.shared.hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        guard AppSettings.shared.hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func selection() {
        guard AppSettings.shared.hapticsEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func warning() {
        guard AppSettings.shared.hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
