//
//  PrimaryButton.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-10.
//

import SwiftUI

struct PrimaryButton: View {
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
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.primary500, .primary]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .padding(.horizontal, 20)
        }
        .shadow(color: .primary.opacity(0.3), radius: 8, y: 4)
    }
}

#Preview {
    PrimaryButton()
        .background(Color.grayC)
}
