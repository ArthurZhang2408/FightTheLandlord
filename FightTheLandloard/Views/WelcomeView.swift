//
//  WelcomeView.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-10.
//

import SwiftUI

struct WelcomeView: View {
    @State var start: Bool = false
    
    var body: some View {
        ZStack{
            Image("welcome_screen")
            
            VStack{
                Text("斗地主计分牌")
                    .font(.customfont(.regular, fontSize: 30))
                    .foregroundColor(.black)
                    .padding(.top, .topInsets + 30)
                
                Spacer()
                PrimaryButton(title: "开始", onPressed: {
                    start.toggle()
                })
                .background( NavigationLink(destination: MainView(), isActive: $start, label: {EmptyView()}))
                .padding(.bottom, .bottomInsets)
            }
            .navigationTitle("斗地主计分牌")
        }
    }
}

#Preview {
    WelcomeView()
}
