//
//  SecondaryPutton.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-10.
//

import SwiftUI

struct SecondaryButton: View {
    @State var title: String = "Title"
    var onPressed: (()->())?
    var body: some View {
        
    
        Button {
            onPressed?()
        } label: {
            
            ZStack{
                Image("secodry_btn")
                    .resizable()
                    .scaledToFill()
                    .padding(.horizontal, 20)
                    .frame(width: .screenWidth, height: 48)
                
                Text(title)
                    .font(.customfont(.semibold, fontSize: 14))
                    .padding(.horizontal, 20)
            }
        }
        .foregroundColor(.white)
    }
}
#Preview {
    SecondaryButton()
}
