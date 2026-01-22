//
//  WelcomeView.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-10.
//

import SwiftUI

struct WelcomeView: View {
    @State var start: Bool = false
    @EnvironmentObject var instance: DataSingleton
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.05, green: 0.05, blue: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo / Icon
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.red.opacity(0.8), .orange.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: .red.opacity(0.3), radius: 20, y: 10)
                        
                        Text("🃏")
                            .font(.system(size: 60))
                    }
                    
                    Text("斗地主计分牌")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("轻松记录每一局精彩对决")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button {
                        instance.newGame()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("开始新牌局")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    
                    Button {
                        instance.continueGame()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("继续上一局")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    WelcomeView().environmentObject(DataSingleton.instance)
}
