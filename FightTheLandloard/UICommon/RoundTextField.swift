//
//  RoundTextField.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-17.
//

import SwiftUI
import Combine

enum KeyboardType {
    case none, email, emoji, decimal, password, disableAuto
}

struct RoundTextField: View {
    @State var title: String = "Title"
    @Binding var text: String
    var textAlign: Alignment  = .leading
    var keyboardType: KeyboardType = KeyboardType.none
    var charLimit: Int = 30
    var height: CGFloat = 48
    
    var body: some View {
        VStack{
            Text(title)
                .multilineTextAlignment(.leading)
                .font(.customfont(.regular, fontSize: 14))
                .frame(minWidth: 0, maxWidth: .screenWidth, alignment: textAlign)
                
                .foregroundColor(.gray50)
                .padding(.bottom, 4)
            
            switch keyboardType {
            case .password:
                SecureField("", text: $text)
                    .padding(15)
                    
                    .frame(height: height)
                    .overlay {
                        RoundedRectangle(cornerRadius:  15)
                            .stroke(Color.gray70, lineWidth: 1)
                    }
                    .foregroundColor(.white)
                    .background(Color.gray60.opacity(0.05))
                    .cornerRadius(15)
            case .email:
                TextField("", text: $text)
                    .autocorrectionDisabled()
                    .autocapitalization(/*@START_MENU_TOKEN@*/.none/*@END_MENU_TOKEN@*/)
                    .padding(15)
                    .keyboardType(.emailAddress)
                    .frame(height: height)
                    .overlay {
                        RoundedRectangle(cornerRadius:  15)
                            .stroke(Color.gray70, lineWidth: 1)
                    }
                    .foregroundColor(.white)
                    .background(Color.gray60.opacity(0.05))
                    .cornerRadius(15)
                    .onChange(of: Just(text), perform: { _ in limitText(charLimit)})
            case .emoji:
                EmojiTextField(text: $text)
                    .padding(15)
                    .frame(height: height)
                    .overlay {
                        RoundedRectangle(cornerRadius:  15)
                            .stroke(Color.gray70, lineWidth: 1)
                    }
                    .foregroundColor(.white)
                    .background(Color.gray60.opacity(0.05))
                    .cornerRadius(15)
                    .onChange(of: Just(text), perform: { _ in limitText(charLimit)})
            case .decimal:
                TextField("", text: $text)
                    .autocorrectionDisabled()
                    .autocapitalization(/*@START_MENU_TOKEN@*/.none/*@END_MENU_TOKEN@*/)
                    .padding(15)
                    .keyboardType(.decimalPad)
                    .frame(height: height)
                    .overlay {
                        RoundedRectangle(cornerRadius:  15)
                            .stroke(Color.gray70, lineWidth: 1)
                    }
                    .foregroundColor(.white)
                    .background(Color.gray60.opacity(0.05))
                    .cornerRadius(15)
            case .disableAuto:
                TextField("", text: $text)
                    .autocorrectionDisabled()
                    .autocapitalization(/*@START_MENU_TOKEN@*/.none/*@END_MENU_TOKEN@*/)
                    .padding(15)
                    .keyboardType(.default)
                    .frame(height: height)
                    .overlay {
                        RoundedRectangle(cornerRadius:  15)
                            .stroke(Color.gray70, lineWidth: 1)
                    }
                    .foregroundColor(.white)
                    .background(Color.gray60.opacity(0.05))
                    .cornerRadius(15)
                    .onChange(of: Just(text), perform: { _ in limitText(charLimit)})
            default:
                TextField("", text: $text)
                    .padding(15)
                    .keyboardType(.default)
                    .frame(height: height)
                    .overlay {
                        RoundedRectangle(cornerRadius:  15)
                            .stroke(Color.gray70, lineWidth: 1)
                    }
                    .foregroundColor(.white)
                    .background(Color.gray60.opacity(0.05))
                    .cornerRadius(15)
                    .onChange(of: Just(text), perform: { _ in limitText(charLimit)})
            }
            
//            if (isPassword) {
//                SecureField("", text: $text)
//                    .padding(15)
//
//                    .frame(height: height)
//                    .overlay {
//                        RoundedRectangle(cornerRadius:  15)
//                            .stroke(Color.gray70, lineWidth: 1)
//                    }
//                    .foregroundColor(.white)
//                    .background(Color.gray60.opacity(0.05))
//                    .cornerRadius(15)
//            } else if (disableAutoCorrect) {
//                TextField("", text: $text)
//                    .autocorrectionDisabled()
//                    .autocapitalization(/*@START_MENU_TOKEN@*/.none/*@END_MENU_TOKEN@*/)
//                    .padding(15)
//                    .keyboardType(keyboardType)
//                    .frame(height: height)
//                    .overlay {
//                        RoundedRectangle(cornerRadius:  15)
//                            .stroke(Color.gray70, lineWidth: 1)
//                    }
//                    .foregroundColor(.white)
//                    .background(Color.gray60.opacity(0.05))
//                    .cornerRadius(15)
//                    .onChange(of: Just(text), perform: { _ in limitText(charLimit)})
//            } else if (!emoji) {
//                TextField("", text: $text)
//                    .padding(15)
//                    .keyboardType(keyboardType)
//                    .frame(height: height)
//                    .overlay {
//                        RoundedRectangle(cornerRadius:  15)
//                            .stroke(Color.gray70, lineWidth: 1)
//                    }
//                    .foregroundColor(.white)
//                    .background(Color.gray60.opacity(0.05))
//                    .cornerRadius(15)
//                    .onChange(of: Just(text), perform: { _ in limitText(charLimit)})
//            } else {
//                EmojiTextField(text: $text)
//                    .padding(15)
//                    .keyboardType(keyboardType)
//                    .frame(height: height)
//                    .overlay {
//                        RoundedRectangle(cornerRadius:  15)
//                            .stroke(Color.gray70, lineWidth: 1)
//                    }
//                    .foregroundColor(.white)
//                    .background(Color.gray60.opacity(0.05))
//                    .cornerRadius(15)
//                    .onChange(of: Just(text), perform: { _ in limitText(charLimit)})
//            }
            
        }
    }
    
    func limitText(_ upper: Int) {
        if text.count > upper {
            text = String(text.prefix(upper))
        }
    }
}

#Preview {
    RoundTextField( text: Binding(get: {return ""}, set: { _ in}))
}
