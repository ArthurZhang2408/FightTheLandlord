//
//  WelcomeView.swift
//  FightTheLandlord
//
//  Created by Arthur Zhang on 2024-10-10.
//

import SwiftUI

struct WelcomeView: View {
    @State private var animateCards = false
    @State private var animateLogo = false
    @State private var animateButtons = false
    @EnvironmentObject var instance: DataSingleton

    var body: some View {
        ZStack {
            // Background gradient with animated overlay
            AppTheme.welcomeGradient
                .ignoresSafeArea()

            // Decorative floating cards
            GeometryReader { geo in
                // Top left card
                FloatingCardView(symbol: "♠️", rotation: -15)
                    .offset(
                        x: animateCards ? 30 : 20,
                        y: animateCards ? 80 : 100
                    )
                    .opacity(animateCards ? 0.3 : 0)

                // Top right card
                FloatingCardView(symbol: "♥️", rotation: 20)
                    .offset(
                        x: geo.size.width - 90,
                        y: animateCards ? 120 : 140
                    )
                    .opacity(animateCards ? 0.25 : 0)

                // Bottom left card
                FloatingCardView(symbol: "♦️", rotation: 10)
                    .offset(
                        x: animateCards ? 50 : 40,
                        y: geo.size.height - 280
                    )
                    .opacity(animateCards ? 0.2 : 0)

                // Bottom right card
                FloatingCardView(symbol: "♣️", rotation: -25)
                    .offset(
                        x: geo.size.width - 100,
                        y: geo.size.height - 320
                    )
                    .opacity(animateCards ? 0.25 : 0)
            }

            VStack(spacing: 0) {
                Spacer()

                // Logo Section
                VStack(spacing: 24) {
                    // Animated logo with glow effect
                    ZStack {
                        // Outer glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.orange.opacity(0.4),
                                        Color.orange.opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 50,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 180, height: 180)
                            .scaleEffect(animateLogo ? 1.1 : 0.9)

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
                                .frame(width: 120, height: 120)
                                .shadow(color: Color.orange.opacity(0.5), radius: 20, y: 10)

                            // Inner highlight
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .center
                                    )
                                )
                                .frame(width: 110, height: 110)

                            // Card icon
                            Text("🃏")
                                .font(.system(size: 56))
                                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        }
                        .scaleEffect(animateLogo ? 1 : 0.8)
                    }

                    // App title
                    VStack(spacing: 8) {
                        Text("斗地主计分牌")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                        Text("轻松记录每一局精彩对决")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .opacity(animateLogo ? 1 : 0)
                    .offset(y: animateLogo ? 0 : 20)
                }

                Spacer()

                // Action Buttons
                VStack(spacing: 14) {
                    // Primary button - Start new game
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            instance.newGame()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("开始新牌局")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "FF6B35"), Color(hex: "F7931E")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.orange.opacity(0.4), radius: 12, y: 6)
                    }
                    .buttonStyle(ScaleButtonStyle())

                    // Secondary button - Continue game
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            instance.continueGame()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 18, weight: .medium))
                            Text("继续上一局")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white.opacity(0.12))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 50)
                .opacity(animateButtons ? 1 : 0)
                .offset(y: animateButtons ? 0 : 30)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Staggered animations
            withAnimation(.easeOut(duration: 0.8)) {
                animateCards = true
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animateLogo = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                animateButtons = true
            }
        }
    }
}

// MARK: - Floating Card View

/// Decorative floating card for background ambiance
struct FloatingCardView: View {
    let symbol: String
    let rotation: Double

    @State private var animate = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
                .frame(width: 50, height: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )

            Text(symbol)
                .font(.system(size: 24))
                .opacity(0.8)
        }
        .rotationEffect(.degrees(rotation))
        .offset(y: animate ? -8 : 8)
        .animation(
            Animation.easeInOut(duration: 3)
                .repeatForever(autoreverses: true)
                .delay(Double.random(in: 0...1)),
            value: animate
        )
        .onAppear {
            animate = true
        }
    }
}

// MARK: - Scale Button Style

/// Button style with subtle scale effect on press
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    WelcomeView().environmentObject(DataSingleton.instance)
}
