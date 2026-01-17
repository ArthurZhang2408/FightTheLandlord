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
            // Background
            Color.grayC.ignoresSafeArea()
            
            // Background image with overlay
            Image("welcome_screen")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.grayC.opacity(0.3),
                            Color.grayC.opacity(0.7),
                            Color.grayC
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            VStack(spacing: 0) {
                Spacer()
                
                // Title Section
                VStack(spacing: 12) {
                    Image(systemName: "suit.spade.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.primary500)
                    
                    Text("斗地主计分牌")
                        .font(.customfont(.bold, fontSize: 36))
                        .foregroundColor(.white)
                    
                    Text("轻松记录每一局")
                        .font(.customfont(.regular, fontSize: 16))
                        .foregroundColor(.gray40)
                }
                .padding(.bottom, 60)
                
                Spacer()
                
                // Buttons Section
                VStack(spacing: 12) {
                    SecondaryButton(title: "继续上次") {
                        instance.continueGame()
                    }
                    
                    PrimaryButton(title: "开始新对局") {
                        instance.newGame()
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("斗地主计分牌")
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    WelcomeView().environmentObject(DataSingleton.instance)
}
