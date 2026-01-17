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
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(selectedPlayer != nil ? Color.accentColor.opacity(0.15) : Color(.tertiarySystemFill))
                        .frame(width: 50, height: 50)
                    
                    if let player = selectedPlayer {
                        Text(String(player.name.prefix(1)))
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                    } else {
                        Image(systemName: "person.badge.plus")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(selectedPlayer?.name ?? "玩家\(position)")
                    .font(.caption)
                    .foregroundColor(selectedPlayer != nil ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
        PlayerPickerView(selectedPlayer: .constant(nil), excludePlayers: [], position: "C")
    }
    .padding()
}
