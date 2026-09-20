//
//  LaunchRevealView.swift
//  FightTheLandlord
//
//  A short opening moment on cold launch: the crown mark draws itself, the
//  name settles in, the three seats take their places, then everything gives
//  way to the scoreboard. It never blocks: tap to skip, and with Reduce Motion
//  it is a plain fade.
//

import SwiftUI

struct CrownShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + w * x, y: rect.minY + h * y)
        }
        var path = Path()
        path.move(to: p(0.10, 0.88))
        path.addLine(to: p(0.06, 0.30))
        path.addLine(to: p(0.32, 0.55))
        path.addLine(to: p(0.50, 0.08))
        path.addLine(to: p(0.68, 0.55))
        path.addLine(to: p(0.94, 0.30))
        path.addLine(to: p(0.90, 0.88))
        path.closeSubpath()
        return path
    }
}

@MainActor
struct LaunchRevealView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(DataStore.self) private var store
    @State private var strokeProgress: CGFloat = 0
    @State private var crownFilled = false
    @State private var titleShown = false
    @State private var seatsShown = false
    @State private var dismissed = false

    private let title = Array("斗地主计分")

    private var seatColors: [Color] {
        let players = store.players.prefix(3).map { $0.color }
        if players.count == 3 { return Array(players) }
        return Seat.allCases.map(seatFallbackColor)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    CrownShape()
                        .fill(AppTheme.gold.opacity(crownFilled ? 0.16 : 0))
                    CrownShape()
                        .trim(from: 0, to: strokeProgress)
                        .stroke(AppTheme.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
                .frame(width: 96, height: 76)
                .scaleEffect(crownFilled ? 1 : 0.94)

                HStack(spacing: 2) {
                    ForEach(Array(title.enumerated()), id: \.offset) { index, character in
                        Text(String(character))
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .opacity(titleShown ? 1 : 0)
                            .offset(y: titleShown ? 0 : 10)
                            .animation(.easeOut(duration: 0.45).delay(Double(index) * 0.06), value: titleShown)
                    }
                }

                HStack(spacing: 10) {
                    ForEach(Array(seatColors.enumerated()), id: \.offset) { index, color in
                        Circle()
                            .fill(color)
                            .frame(width: 10, height: 10)
                            .scaleEffect(seatsShown ? 1 : 0.2)
                            .opacity(seatsShown ? 1 : 0)
                            .animation(.spring(response: 0.45, dampingFraction: 0.6).delay(Double(index) * 0.08), value: seatsShown)
                    }
                }
            }
            .offset(y: -20)

            VStack {
                Spacer()
                Text("记录每一局 · 见证每一次胜利")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textTertiary)
                    .tracking(1.5)
                    .opacity(seatsShown ? 1 : 0)
                    .padding(.bottom, 48)
            }
        }
        .opacity(dismissed ? 0 : 1)
        .scaleEffect(dismissed ? 1.03 : 1)
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("斗地主计分，点击跳过开场")
        .onAppear(perform: start)
    }

    private func start() {
        if reduceMotion {
            strokeProgress = 1
            crownFilled = true
            titleShown = true
            seatsShown = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                finish()
            }
            return
        }
        withAnimation(.easeInOut(duration: 0.8)) { strokeProgress = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { crownFilled = true }
            titleShown = true
            try? await Task.sleep(for: .milliseconds(450))
            seatsShown = true
            try? await Task.sleep(for: .milliseconds(900))
            finish()
        }
    }

    private func finish() {
        guard !dismissed else { return }
        withAnimation(.easeInOut(duration: reduceMotion ? 0.2 : 0.45)) { dismissed = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 450))
            onFinished()
        }
    }
}
