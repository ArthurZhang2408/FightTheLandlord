//
//  AddColumn.swift
//  FightTheLandlord
//
//  Created by Arthur Zhang on 2024-10-04.
//

import SwiftUI

struct AddColumn: View {
    @Binding var showingNewItemView: Bool
    @StateObject var viewModel: AddColumnViewModel = AddColumnViewModel(idx: -1)
    let turn: Int

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Players Section (Bid + Double in card format)
                Section {
                    PlayerBidCard(
                        name: viewModel.instance.room.aName.isEmpty ? "玩家A" : viewModel.instance.room.aName,
                        isFirstBidder: turn == 0,
                        selectedBid: $viewModel.apoint,
                        isDoubled: $viewModel.setting.adouble,
                        options: viewModel.points,
                        isLandlord: determineLandlordPosition() == 0
                    )

                    PlayerBidCard(
                        name: viewModel.instance.room.bName.isEmpty ? "玩家B" : viewModel.instance.room.bName,
                        isFirstBidder: turn == 1,
                        selectedBid: $viewModel.bpoint,
                        isDoubled: $viewModel.setting.bdouble,
                        options: viewModel.points,
                        isLandlord: determineLandlordPosition() == 1
                    )

                    PlayerBidCard(
                        name: viewModel.instance.room.cName.isEmpty ? "玩家C" : viewModel.instance.room.cName,
                        isFirstBidder: turn == 2,
                        selectedBid: $viewModel.cpoint,
                        isDoubled: $viewModel.setting.cdouble,
                        options: viewModel.points,
                        isLandlord: determineLandlordPosition() == 2
                    )
                } header: {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(Color(hex: "FF6B35"))
                        Text("玩家叫分")
                    }
                } footer: {
                    if let landlord = determineLandlord() {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundColor(Color(hex: "F7931E"))
                            Text("\(landlord) 成为地主")
                                .foregroundColor(.primary)
                        }
                    } else if allNotBid() {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("没人叫分，点击完成将自动轮换到下一位玩家先叫")
                        }
                    }
                }

                // MARK: - Multipliers Section (Bombs + Spring)
                Section {
                    // Bombs counter
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.yellow)
                            Text("炸弹")
                        }
                        Spacer()
                        HStack(spacing: 16) {
                            Button {
                                let current = Int(viewModel.bombs) ?? 0
                                if current > 0 {
                                    viewModel.bombs = "\(current - 1)"
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(Int(viewModel.bombs) ?? 0 > 0 ? Color(hex: "FF6B35") : .secondary.opacity(0.5))
                            }
                            .buttonStyle(.plain)

                            Text(viewModel.bombs.isEmpty ? "0" : viewModel.bombs)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .frame(minWidth: 28)

                            Button {
                                let current = Int(viewModel.bombs) ?? 0
                                viewModel.bombs = "\(current + 1)"
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(Color(hex: "FF6B35"))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Spring toggle
                    Toggle(isOn: $viewModel.setting.spring) {
                        HStack(spacing: 8) {
                            Image(systemName: "sun.max.fill")
                                .foregroundColor(.orange)
                            Text("春天")
                        }
                    }
                    .tint(Color(hex: "FF6B35"))
                } header: {
                    HStack {
                        Image(systemName: "xmark.octagon.fill")
                            .foregroundColor(Color(hex: "FF6B35"))
                        Text("倍数")
                    }
                }

                // MARK: - Result Section
                Section {
                    VStack(spacing: 12) {
                        Picker("比赛结果", selection: $viewModel.setting.landlordResult) {
                            HStack {
                                Image(systemName: "crown.fill")
                                Text("地主赢")
                            }
                            .tag(true)
                            HStack {
                                Image(systemName: "person.2.fill")
                                Text("农民赢")
                            }
                            .tag(false)
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    HStack {
                        Image(systemName: "flag.checkered")
                            .foregroundColor(Color(hex: "FF6B35"))
                        Text("结果")
                    }
                }
            }
            .navigationTitle(viewModel.gameIdx == -1 ? "添加新局" : "修改第\(viewModel.gameIdx+1)局")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showingNewItemView = false
                    }
                    .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        // Check if no one bid - auto advance to next first bidder
                        if allNotBid() {
                            viewModel.instance.room.starter = (viewModel.instance.room.starter + 1) % 3
                            showingNewItemView = false
                            return
                        }

                        if viewModel.add() {
                            showingNewItemView = false
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "FF6B35"))
                }
            }
            .alert("输入错误", isPresented: $viewModel.showAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }

    private func playerName(_ index: Int) -> String {
        switch index {
        case 0: return viewModel.instance.room.aName.isEmpty ? "玩家A" : viewModel.instance.room.aName
        case 1: return viewModel.instance.room.bName.isEmpty ? "玩家B" : viewModel.instance.room.bName
        case 2: return viewModel.instance.room.cName.isEmpty ? "玩家C" : viewModel.instance.room.cName
        default: return ""
        }
    }

    private func allNotBid() -> Bool {
        return viewModel.apoint == "不叫" && viewModel.bpoint == "不叫" && viewModel.cpoint == "不叫"
    }

    private func determineLandlordPosition() -> Int? {
        let bids = [viewModel.apoint, viewModel.bpoint, viewModel.cpoint]
        let values = bids.map { bidValue($0) }
        if let maxValue = values.max(), maxValue > 0 {
            return values.firstIndex(of: maxValue)
        }
        return nil
    }

    private func determineLandlord() -> String? {
        let bids = [
            (viewModel.apoint, viewModel.instance.room.aName.isEmpty ? "玩家A" : viewModel.instance.room.aName),
            (viewModel.bpoint, viewModel.instance.room.bName.isEmpty ? "玩家B" : viewModel.instance.room.bName),
            (viewModel.cpoint, viewModel.instance.room.cName.isEmpty ? "玩家C" : viewModel.instance.room.cName)
        ]

        let maxBid = bids.filter { $0.0 != "不叫" }.max { bidValue($0.0) < bidValue($1.0) }
        return maxBid?.1
    }

    private func bidValue(_ bid: String) -> Int {
        switch bid {
        case "1分": return 1
        case "2分": return 2
        case "3分": return 3
        default: return 0
        }
    }
}

// MARK: - Player Bid Card

struct PlayerBidCard: View {
    let name: String
    let isFirstBidder: Bool
    @Binding var selectedBid: String
    @Binding var isDoubled: Bool
    let options: [String]
    var isLandlord: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Player name row
            HStack {
                HStack(spacing: 8) {
                    if isFirstBidder {
                        Image(systemName: "hand.point.right.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "FF6B35"))
                    }
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))

                    if isLandlord {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "F7931E"))
                    }
                }

                Spacer()

                // Double toggle with label
                HStack(spacing: 8) {
                    Text("加倍")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Toggle("", isOn: $isDoubled)
                        .labelsHidden()
                        .tint(Color(hex: "FF6B35"))
                }
            }

            // Bid picker (full width)
            Picker("叫分", selection: $selectedBid) {
                ForEach(options, id: \.self) { option in
                    Text(option)
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    AddColumn(showingNewItemView: .constant(true), turn: 0)
}
