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
        ZStack{
            Image("welcome_screen")
            
            VStack{
                Text("斗地主计分牌")
                    .font(.customfont(.bold, fontSize: 50))
                    .foregroundColor(.white)
                    .padding(.top, .topInsets + 30)
                
                Spacer()
                SecondaryButton(title: "继续", onPressed: {
                    instance.continueGame()
                })
                .padding(.bottom, 15)
                
                PrimaryButton(title: "开始", onPressed: {
                    instance.newGame()
                })
                .padding(.bottom, .bottomInsets)
            }
        }
        .navigationTitle("斗地主计分牌")
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .background(Color.grayC)
    }
}

#Preview {
    WelcomeView()
}
