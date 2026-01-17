//
//  PlayerPickerView.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-20.
//

import SwiftUI

struct PlayerPickerView: View {
    @Binding var selectedPlayer: Player?
    let excludePlayers: [Player]
    let position: String  // "A", "B", or "C"
    
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var showingAddPlayer = false
    
    var availablePlayers: [Player] {
        firebaseService.players.filter { player in
            !excludePlayers.contains(where: { $0.id == player.id })
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Position label
            Text("玩家\(position)")
                .font(.customfont(.medium, fontSize: 11))
                .foregroundColor(.gray50)
            
            Menu {
                ForEach(availablePlayers) { player in
                    Button {
                        selectedPlayer = player
                    } label: {
                        HStack {
                            Text(player.name)
                            if selectedPlayer?.id == player.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                Divider()
                
                Button {
                    showingAddPlayer = true
                } label: {
                    Label("添加新玩家", systemImage: "plus.circle")
                }
            } label: {
                HStack(spacing: 6) {
                    if let player = selectedPlayer {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.primary500)
                        Text(player.name)
                            .font(.customfont(.medium, fontSize: 14))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "person.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.gray50)
                        Text("选择")
                            .font(.customfont(.regular, fontSize: 14))
                            .foregroundColor(.gray50)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.gray50)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.gray80)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(selectedPlayer != nil ? Color.primary500.opacity(0.5) : Color.gray70, lineWidth: 1)
                )
            }
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerView(isPresented: $showingAddPlayer)
        }
    }
}

#Preview {
    HStack {
        PlayerPickerView(selectedPlayer: .constant(nil), excludePlayers: [], position: "A")
        PlayerPickerView(selectedPlayer: .constant(Player(name: "张三")), excludePlayers: [], position: "B")
    }
    .padding()
    .background(Color.grayC)
}
