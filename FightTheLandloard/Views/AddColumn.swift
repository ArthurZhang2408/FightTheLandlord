//
//  AddColumn.swift
//  FightTheLandloard
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
                // MARK: - Players Section (Bid + Double combined)
                Section {
                    CompactPlayerRow(
                        name: viewModel.instance.room.aName.isEmpty ? "玩家A" : viewModel.instance.room.aName,
                        isFirstBidder: turn == 0,
                        selectedBid: $viewModel.apoint,
                        isDoubled: $viewModel.setting.adouble,
                        options: viewModel.points
                    )
                    
                    CompactPlayerRow(
                        name: viewModel.instance.room.bName.isEmpty ? "玩家B" : viewModel.instance.room.bName,
                        isFirstBidder: turn == 1,
                        selectedBid: $viewModel.bpoint,
                        isDoubled: $viewModel.setting.bdouble,
                        options: viewModel.points
                    )
                    
                    CompactPlayerRow(
                        name: viewModel.instance.room.cName.isEmpty ? "玩家C" : viewModel.instance.room.cName,
                        isFirstBidder: turn == 2,
                        selectedBid: $viewModel.cpoint,
                        isDoubled: $viewModel.setting.cdouble,
                        options: viewModel.points
                    )
                } header: {
                    HStack {
                        Text("叫分")
                        Spacer()
                        Text("加倍")
                            .foregroundColor(.secondary)
                    }
                } footer: {
                    if let landlord = determineLandlord() {
                        Text("👑 \(landlord) 成为地主")
                    } else if allNotBid() {
                        Text("⚠️ 没人叫分，点击完成将自动轮换到下一位玩家先叫")
                    }
                }
                
                // MARK: - Multipliers Section (Bombs + Spring)
                Section {
                    HStack {
                        Label("炸弹", systemImage: "bolt.fill")
                        Spacer()
                        HStack(spacing: 12) {
                            Button {
                                let current = Int(viewModel.bombs) ?? 0
                                if current > 0 {
                                    viewModel.bombs = "\(current - 1)"
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Text(viewModel.bombs.isEmpty ? "0" : viewModel.bombs)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .frame(minWidth: 24)
                            
                            Button {
                                let current = Int(viewModel.bombs) ?? 0
                                viewModel.bombs = "\(current + 1)"
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Toggle(isOn: $viewModel.setting.spring) {
                        Label("春天", systemImage: "sun.max.fill")
                    }
                } header: {
                    Text("倍数")
                }
                
                // MARK: - Result Section
                Section {
                    Picker("比赛结果", selection: $viewModel.setting.landlordResult) {
                        Text("地主赢").tag(true)
                        Text("农民赢").tag(false)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("结果")
                }
            }
            .navigationTitle(viewModel.gameIdx == -1 ? "添加新局" : "修改第\(viewModel.gameIdx+1)局")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showingNewItemView = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        // Check if no one bid - auto advance to next first bidder
                        // When no one bids, the current game cannot proceed.
                        // We advance the starter position so the next game will have
                        // a different player bidding first (like passing the deck in real play).
                        if allNotBid() {
                            viewModel.instance.room.starter = (viewModel.instance.room.starter + 1) % 3
                            showingNewItemView = false
                            return
                        }
                        
                        if viewModel.add() {
                            showingNewItemView = false
                        }
                    }
                    .fontWeight(.semibold)
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

// MARK: - Compact Player Row (Bid + Double in one row)

struct CompactPlayerRow: View {
    let name: String
    let isFirstBidder: Bool
    @Binding var selectedBid: String
    @Binding var isDoubled: Bool
    let options: [String]
    
    var body: some View {
        HStack(spacing: 8) {
            // Player name with first bidder indicator
            HStack(spacing: 4) {
                if isFirstBidder {
                    Image(systemName: "hand.point.right.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .frame(width: 70, alignment: .leading)
            
            // Bid picker (compact)
            Picker("", selection: $selectedBid) {
                ForEach(options, id: \.self) { option in
                    Text(option == "不叫" ? "不叫" : option.replacingOccurrences(of: "分", with: ""))
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
            
            // Double toggle
            Toggle("", isOn: $isDoubled)
                .labelsHidden()
                .frame(width: 50)
        }
    }
}

#Preview {
    AddColumn(showingNewItemView: .constant(true), turn: 0)
}
