//
//  GameEditorView.swift
//  FightTheLandlord
//
//  Add or edit one game. Bids, doubles, bombs, spring and the result are entered
//  here; the score is computed live by `ScoreCalculator` and shown before saving.
//

import SwiftUI

struct GameEditorView: View {
    enum Mode: Equatable {
        case add(firstBidder: Seat)
        case edit(game: Game, index: Int)
    }

    let mode: Mode
    let playerNames: [String]
    var onSave: (Game) -> Void
    /// Add mode only: nobody bid, the deal passes to the next seat.
    var onNoBids: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var draft = Game()
    @State private var validationMessage: String?

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var firstBidder: Seat? {
        switch mode {
        case .add(let seat): return seat
        case .edit(let game, _): return game.firstBidder
        }
    }

    private var nobodyBid: Bool { draft.bids.allSatisfy { $0 == 0 } }
    private var landlordPreview: Seat? { ScoreCalculator.previewLandlord(bids: draft.bids) }
    private var outcome: ScoreCalculator.Outcome? { try? ScoreCalculator.compute(.init(game: draft)) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(Seat.allCases) { seat in
                        bidRow(for: seat)
                    }
                } header: {
                    Text("叫分")
                } footer: {
                    bidFooter
                }

                Section("倍数") {
                    Stepper(value: $draft.bombs, in: 0...8) {
                        HStack {
                            Label("炸弹", systemImage: "flame")
                            Spacer()
                            Text("\(draft.bombs)")
                                .font(AppFont.score(17, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(draft.bombs > 0 ? AppTheme.accent : AppTheme.textSecondary)
                        }
                    }
                    Toggle(isOn: $draft.spring) {
                        Label("春天", systemImage: "sun.max")
                    }
                }

                Section("结果") {
                    Picker("结果", selection: $draft.landlordWon) {
                        Text("地主赢").tag(true)
                        Text("农民赢").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    preview
                } header: {
                    Text("本局得分")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "保存" : "完成", action: commit)
                        .fontWeight(.semibold)
                        .disabled(outcome == nil && !(nobodyBid && !isEditing))
                }
            }
            .alert("无法保存", isPresented: Binding(get: { validationMessage != nil }, set: { if !$0 { validationMessage = nil } })) {
                Button("好", role: .cancel) {}
            } message: {
                Text(validationMessage ?? "")
            }
            .onAppear(perform: load)
        }
    }

    private var title: String {
        switch mode {
        case .add: return "记一局"
        case .edit(_, let index): return "修改第 \(index + 1) 局"
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func bidRow(for seat: Seat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(playerNames[seat])
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                if firstBidder == seat {
                    Chip(text: "先叫", tint: AppTheme.accent, icon: "hand.point.right.fill")
                }
                if landlordPreview == seat {
                    RoleBadge(isLandlord: true)
                }
                Spacer()
                Text("加倍")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Toggle("加倍", isOn: Binding(
                    get: { draft.doubles[seat] },
                    set: { draft.doubles[seat] = $0 }
                ))
                .labelsHidden()
            }
            Picker("叫分", selection: Binding(
                get: { draft.bids[seat] },
                set: { draft.bids[seat] = $0 }
            )) {
                Text("不叫").tag(0)
                Text("1分").tag(1)
                Text("2分").tag(2)
                Text("3分").tag(3)
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var bidFooter: some View {
        if let landlord = landlordPreview {
            Label("\(playerNames[landlord]) 当地主，底分 \(draft.winningBid * 100)", systemImage: "crown.fill")
                .foregroundStyle(AppTheme.gold)
        } else if nobodyBid {
            if isEditing {
                Text("至少要有一人叫分。")
            } else {
                Label("没人叫分？点“完成”将由下一位玩家先叫，本局不计分。", systemImage: "arrow.triangle.2.circlepath")
            }
        } else {
            Label(errorText, systemImage: "exclamationmark.triangle")
                .foregroundStyle(AppTheme.red)
        }
    }

    private var errorText: String {
        do {
            _ = try ScoreCalculator.landlordSeat(bids: draft.bids)
            return ""
        } catch {
            return error.localizedDescription
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let outcome = outcome {
            HStack(spacing: 0) {
                ForEach(Seat.allCases) { seat in
                    VStack(spacing: 6) {
                        HStack(spacing: 4) {
                            if outcome.landlord == seat {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(AppTheme.gold)
                            }
                            Text(playerNames[seat])
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                        }
                        ScoreText(value: outcome.scores[seat], size: 22)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 6)
            HStack {
                Text("倍数")
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text(multiplierText(outcome))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        } else {
            Text(nobodyBid ? "叫分后显示得分" : "请检查叫分")
                .foregroundStyle(AppTheme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)
        }
    }

    private func multiplierText(_ outcome: ScoreCalculator.Outcome) -> String {
        var parts: [String] = ["底分 \(draft.winningBid * 100)"]
        if draft.bombs > 0 { parts.append("炸弹 ×\(1 << draft.bombs)") }
        if draft.spring { parts.append("春天 ×2") }
        if draft.doubles[outcome.landlord] { parts.append("地主加倍 ×2") }
        let farmerDoubles = outcome.landlord.others.filter { draft.doubles[$0] }.count
        if farmerDoubles > 0 { parts.append("农民加倍 ×\(farmerDoubles)") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Actions

    private func load() {
        switch mode {
        case .add(let seat):
            draft = Game(firstBidder: seat)
        case .edit(let game, _):
            draft = game
        }
    }

    private func commit() {
        if nobodyBid, !isEditing {
            onNoBids?()
            Haptics.light()
            dismiss()
            return
        }
        do {
            let scored = try ScoreCalculator.score(draft)
            Haptics.success()
            onSave(scored)
            dismiss()
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}
