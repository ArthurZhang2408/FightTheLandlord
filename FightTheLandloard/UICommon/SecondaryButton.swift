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
            Text(title)
                .font(.customfont(.semibold, fontSize: 14))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.gray80)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray70, lineWidth: 1)
                )
                .cornerRadius(12)
                .padding(.horizontal, 20)
        }
    }
}

#Preview {
    SecondaryButton()
        .background(Color.grayC)
}
