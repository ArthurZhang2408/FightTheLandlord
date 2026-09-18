//
//  PlayerEditorView.swift
//  FightTheLandlord
//
//  Create or edit a player (name + color).
//

import SwiftUI

struct PlayerEditorView: View {
    enum Mode: Equatable {
        case create
        case edit(Player)
    }

    let mode: Mode
    var onCreated: ((Player) -> Void)? = nil

    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var color: PlayerColor = .blue
    @State private var errorMessage: String?
    @FocusState private var nameFocused: Bool

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        PlayerAvatar(name: name.isEmpty ? "?" : name, color: color.color, size: 52)
                        TextField("玩家名称", text: $name)
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .onSubmit(save)
                    }
                    .padding(.vertical, 4)
                } footer: {
                    Text("名称会显示在计分板、历史记录和统计中。")
                }

                Section("颜色") {
                    PlayerColorGrid(selected: $color)
                        .padding(.vertical, 6)
                }
            }
            .navigationTitle(isEditing ? "编辑玩家" : "新玩家")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "保存" : "添加", action: save)
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("无法保存", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                if case .edit(let player) = mode {
                    name = player.name
                    color = player.resolvedColor
                } else {
                    color = suggestedColor()
                }
                nameFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func suggestedColor() -> PlayerColor {
        let used = Set(store.players.map { $0.resolvedColor })
        return PlayerColor.allCases.first { !used.contains($0) } ?? .blue
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        switch mode {
        case .create:
            do {
                let player = try store.addPlayer(name: trimmed, color: color)
                Haptics.success()
                onCreated?(player)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        case .edit(let player):
            if store.players.contains(where: { $0.name == trimmed && $0.id != player.id }) {
                errorMessage = DataStoreError.duplicatePlayerName.localizedDescription
                return
            }
            var updated = player
            updated.name = trimmed
            updated.playerColor = color
            store.updatePlayer(updated)
            Haptics.success()
            dismiss()
        }
    }
}

struct PlayerColorGrid: View {
    @Binding var selected: PlayerColor

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(PlayerColor.allCases) { option in
                Button {
                    selected = option
                    Haptics.light()
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(option.color).frame(width: 36, height: 36)
                            if option == selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay(
                            Circle().stroke(option == selected ? option.color : Color.clear, lineWidth: 2)
                                .frame(width: 44, height: 44)
                        )
                        Text(option.displayName)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
