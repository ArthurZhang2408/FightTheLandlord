//
//  Components.swift
//  FightTheLandlord
//
//  Small reusable building blocks shared by every screen.
//

import SwiftUI

// MARK: - Section header

struct SectionHeader<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.s) {
            Text(title)
                .font(AppFont.sectionTitle)
                .foregroundStyle(AppTheme.textSecondary)
                .textCase(nil)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, AppTheme.Spacing.xs)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}

// MARK: - Avatar

struct PlayerAvatar: View {
    let name: String
    let color: Color
    var size: CGFloat = 40
    var emphasized: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(emphasized ? 1 : 0.14))
            Text(String(name.trimmingCharacters(in: .whitespaces).prefix(1)))
                .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                .foregroundStyle(emphasized ? Color.white : color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Score text

struct ScoreText: View {
    @Environment(AppSettings.self) private var settings
    let value: Int
    var size: CGFloat = 24
    var weight: Font.Weight = .bold
    var neutralColor: Color? = nil

    var body: some View {
        Text(ScoreFormat.signed(value))
            .font(AppFont.score(size, weight: weight))
            .foregroundStyle(value == 0 ? (neutralColor ?? AppTheme.textSecondary) : AppTheme.scoreColor(value, greenWin: settings.greenWin))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .contentTransition(.numericText())
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let title: String
    let value: String
    var caption: String? = nil
    var icon: String? = nil
    var tint: Color = AppTheme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption2)
                        .foregroundStyle(tint == AppTheme.textPrimary ? AppTheme.textTertiary : tint)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(AppFont.score(20, weight: .semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let caption = caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.m, style: .continuous))
    }
}

// MARK: - Stat row (list style)

struct StatRowItem: View {
    let icon: String
    var tint: Color = AppTheme.textSecondary
    let label: String
    let value: String
    var valueColor: Color = AppTheme.textPrimary
    var detail: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(label)
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(AppFont.score(17, weight: .semibold))
                    .foregroundStyle(valueColor)
                    .monospacedDigit()
                if let detail = detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Form dots (recent results)

struct FormDots: View {
    @Environment(AppSettings.self) private var settings
    let results: [Bool]
    var size: CGFloat = 8

    var body: some View {
        HStack(spacing: size * 0.45) {
            ForEach(Array(results.enumerated()), id: \.offset) { _, won in
                Circle()
                    .fill(AppTheme.resultColor(win: won, greenWin: settings.greenWin))
                    .frame(width: size, height: size)
            }
        }
    }
}

// MARK: - Chips and badges

struct Chip: View {
    let text: String
    var tint: Color = AppTheme.textSecondary
    var filled: Bool = false
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .foregroundStyle(filled ? Color.white : tint)
        .background(filled ? tint : tint.opacity(0.12))
        .clipShape(Capsule())
    }
}

struct RoleBadge: View {
    let isLandlord: Bool
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: isLandlord ? "crown.fill" : "leaf.fill")
                .font(.system(size: compact ? 8 : 10, weight: .semibold))
            if !compact {
                Text(isLandlord ? "地主" : "农民")
                    .font(.caption2.weight(.semibold))
            }
        }
        .foregroundStyle(AppTheme.roleColor(isLandlord: isLandlord))
        .padding(.horizontal, compact ? 4 : 6)
        .padding(.vertical, compact ? 2 : 3)
        .background(AppTheme.roleColor(isLandlord: isLandlord).opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Progress bar

struct MiniBar: View {
    let fraction: Double
    var tint: Color = AppTheme.accent
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.fill)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

struct WinRateRing: View {
    let fraction: Double
    var tint: Color = AppTheme.accent
    var lineWidth: CGFloat = 6
    var size: CGFloat = 56
    var label: String? = nil

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.fill, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, fraction)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let label = label {
                Text(label)
                    .font(AppFont.score(size * 0.26, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Empty state

struct EmptyStateView<Action: View>: View {
    let icon: String
    let title: String
    let message: String
    @ViewBuilder var action: Action

    init(icon: String, title: String, message: String, @ViewBuilder action: () -> Action) {
        self.icon = icon
        self.title = title
        self.message = message
        self.action = action()
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(AppTheme.textTertiary)
                .padding(.bottom, 4)
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            action
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xxl)
        .padding(.horizontal, AppTheme.Spacing.xl)
    }
}

extension EmptyStateView where Action == EmptyView {
    init(icon: String, title: String, message: String) {
        self.init(icon: icon, title: title, message: message) { EmptyView() }
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = AppTheme.accent
    var fullWidth: Bool = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(tint.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.m, style: .continuous))
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = AppTheme.accent
    var fullWidth: Bool = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(tint.opacity(configuration.isPressed ? 0.18 : 0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.m, style: .continuous))
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Skeleton

struct SkeletonBlock: View {
    var height: CGFloat = 16
    var width: CGFloat? = nil
    var radius: CGFloat = 6
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(AppTheme.fill)
            .frame(width: width, height: height)
            .opacity(pulse ? 0.45 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

struct SkeletonList: View {
    var rows: Int = 6

    var body: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: 12) {
                    SkeletonBlock(height: 40, width: 40, radius: 20)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(height: 14, width: 120)
                        SkeletonBlock(height: 10, width: 80)
                    }
                    Spacer()
                    SkeletonBlock(height: 18, width: 50)
                }
                .card(padding: 14)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Info banner

struct InfoBanner: View {
    let icon: String
    let title: String
    var message: String? = nil
    var tint: Color = AppTheme.accent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                if let message = message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.m, style: .continuous))
    }
}
