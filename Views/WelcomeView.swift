//
//  WelcomeView.swift
//  FightTheLandlord
//
//  Created by Arthur Zhang on 2024-10-10.
//

import SwiftUI

struct WelcomeView: View {
    @State private var animateBackground = false
    @State private var animateCards = false
    @State private var animateLogo = false
    @State private var animateTitle = false
    @State private var animateButton = false
    @State private var pulseGlow = false
    @State private var shineOffset: CGFloat = -200
    @EnvironmentObject var instance: DataSingleton

    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    Color(hex: "0F0F1A"),
                    Color(hex: "1A1A2E"),
                    Color(hex: "16213E")
                ],
                startPoint: animateBackground ? .topLeading : .top,
                endPoint: animateBackground ? .bottomTrailing : .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animateBackground)

            // Floating poker cards background
            GeometryReader { geo in
                ForEach(0..<6, id: \.self) { index in
                    FloatingPokerCard(
                        suit: ["♠️", "♥️", "♦️", "♣️", "🃏", "👑"][index],
                        size: [45, 50, 40, 55, 48, 42][index],
                        initialX: [0.1, 0.85, 0.15, 0.9, 0.05, 0.8][index] * geo.size.width,
                        initialY: [0.15, 0.2, 0.7, 0.75, 0.45, 0.5][index] * geo.size.height,
                        rotation: [-15, 20, 10, -25, 15, -10][index],
                        delay: Double(index) * 0.15
                    )
                    .opacity(animateCards ? 0.25 : 0)
                }
            }

            // Main content
            VStack(spacing: 0) {
                Spacer()

                // Logo Section
                VStack(spacing: 32) {
                    // Animated logo with multiple layers
                    ZStack {
                        // Pulsing outer glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(hex: "FF6B35").opacity(0.35),
                                        Color(hex: "FF6B35").opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 60,
                                    endRadius: 130
                                )
                            )
                            .frame(width: 240, height: 240)
                            .scaleEffect(pulseGlow ? 1.15 : 1.0)
                            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: pulseGlow)

                        // Rotating ring
                        Circle()
                            .strokeBorder(
                                AngularGradient(
                                    colors: [
                                        Color(hex: "FF6B35").opacity(0.6),
                                        Color(hex: "F7931E").opacity(0.2),
                                        Color(hex: "FF6B35").opacity(0.05),
                                        Color(hex: "F7931E").opacity(0.2),
                                        Color(hex: "FF6B35").opacity(0.6)
                                    ],
                                    center: .center
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 170, height: 170)
                            .rotationEffect(.degrees(animateLogo ? 360 : 0))
                            .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: animateLogo)

                        // Main icon container
                        ZStack {
                            // Background circle with gradient
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "FF6B35"),
                                            Color(hex: "F7931E"),
                                            Color(hex: "E74C3C")
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 140, height: 140)
                                .shadow(color: Color(hex: "FF6B35").opacity(0.6), radius: 30, y: 10)

                            // Inner highlight
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.4), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .center
                                    )
                                )
                                .frame(width: 130, height: 130)

                            // Card icons stack
                            ZStack {
                                Text("🂡")
                                    .font(.system(size: 38))
                                    .offset(x: -14, y: -5)
                                    .rotationEffect(.degrees(-12))
                                Text("🂱")
                                    .font(.system(size: 38))
                                    .offset(x: 14, y: 5)
                                    .rotationEffect(.degrees(12))
                                Text("👑")
                                    .font(.system(size: 30))
                                    .offset(y: -38)
                            }
                        }
                        .scaleEffect(animateLogo ? 1 : 0.5)
                        .opacity(animateLogo ? 1 : 0)
                    }

                    // App title with gradient text
                    VStack(spacing: 12) {
                        Text("斗地主记分器")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.85)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

                        Text("记录每一局 · 见证每一次胜利")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                            .tracking(2)
                    }
                    .opacity(animateTitle ? 1 : 0)
                    .offset(y: animateTitle ? 0 : 30)
                }

                Spacer()

                // Start Button
                VStack(spacing: 24) {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            instance.newGame()
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 20, weight: .semibold))
                            Text("开始新牌局")
                                .font(.system(size: 20, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            ZStack {
                                // Base gradient
                                LinearGradient(
                                    colors: [Color(hex: "FF6B35"), Color(hex: "F7931E")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )

                                // Shine effect
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0),
                                        Color.white.opacity(0.25),
                                        Color.white.opacity(0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: 100)
                                .offset(x: shineOffset)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: Color(hex: "FF6B35").opacity(0.5), radius: 20, y: 10)
                    }
                    .buttonStyle(ScaleButtonStyle())

                    // Subtle hint text
                    HStack(spacing: 6) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 12))
                        Text("三人对战 · 智慧博弈")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
                .opacity(animateButton ? 1 : 0)
                .offset(y: animateButton ? 0 : 40)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Start background animation
        animateBackground = true

        // Staggered entrance animations
        withAnimation(.easeOut(duration: 1.0)) {
            animateCards = true
        }
        withAnimation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.3)) {
            animateLogo = true
        }
        withAnimation(.easeOut(duration: 0.7).delay(0.6)) {
            animateTitle = true
        }
        withAnimation(.easeOut(duration: 0.7).delay(0.9)) {
            animateButton = true
        }

        // Start continuous animations after entrance
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            pulseGlow = true
            startShineAnimation()
        }
    }

    private func startShineAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
            shineOffset = 250
        }
    }
}

// MARK: - Floating Poker Card

/// Animated floating poker card for background decoration
struct FloatingPokerCard: View {
    let suit: String
    let size: CGFloat
    let initialX: CGFloat
    let initialY: CGFloat
    let rotation: Double
    let delay: Double

    @State private var offsetY: CGFloat = 0
    @State private var rotationAngle: Double = 0

    var body: some View {
        Text(suit)
            .font(.system(size: size))
            .position(x: initialX, y: initialY + offsetY)
            .rotationEffect(.degrees(rotation + rotationAngle))
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: Double.random(in: 3...5))
                        .repeatForever(autoreverses: true)
                        .delay(delay)
                ) {
                    offsetY = CGFloat.random(in: -20...20)
                    rotationAngle = Double.random(in: -5...5)
                }
            }
    }
}

// MARK: - Scale Button Style

/// Button style with scale effect on press
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    WelcomeView().environmentObject(DataSingleton.instance)
}
