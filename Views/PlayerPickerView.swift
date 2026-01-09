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
        VStack {
            Menu {
                ForEach(availablePlayers) { player in
                    Button(player.name) {
                        selectedPlayer = player
                    }
                }
                
                Divider()
                
                Button {
                    showingAddPlayer = true
                } label: {
                    Label("添加新玩家", systemImage: "plus")
                }
            } label: {
                HStack {
                    Text(selectedPlayer?.name ?? "选择玩家\(position)")
                        .foregroundColor(selectedPlayer == nil ? .gray : .white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding(15)
                .overlay {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.gray70, lineWidth: 1)
                }
            }
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerView(isPresented: $showingAddPlayer)
        }
    }
}

#Preview {
    PlayerPickerView(selectedPlayer: .constant(nil), excludePlayers: [], position: "A")
}
