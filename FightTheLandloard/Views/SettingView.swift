//
//  SettingView.swift
//  FightTheLandlord
//
//  Created by Arthur Zhang on 2024-10-16.
//

import SwiftUI

struct SettingView: View {
    let players: [String]
    @EnvironmentObject var instance: DataSingleton
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Display Settings
                Section {
                    // Color preference
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "paintpalette.fill")
                                .foregroundColor(Color(hex: "FF6B35"))
                                .font(.system(size: 14))
                            Text("分数颜色")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }

                        Picker("颜色设置", selection: $instance.greenWin) {
                            HStack {
                                Circle().fill(.green).frame(width: 10, height: 10)
                                Text("绿色为赢")
                            }
                            .tag(true)

                            HStack {
                                Circle().fill(.red).frame(width: 10, height: 10)
                                Text("红色为赢")
                            }
                            .tag(false)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Preview with animated transition
                    HStack {
                        Text("预览效果")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("+100")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(instance.greenWin ? .green : .red)
                            .contentTransition(.numericText())
                        Text("/")
                            .foregroundColor(.secondary)
                        Text("-100")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(instance.greenWin ? .red : .green)
                            .contentTransition(.numericText())
                    }
                } header: {
                    HStack {
                        Image(systemName: "eye.fill")
                            .foregroundColor(Color(hex: "FF6B35"))
                        Text("显示设置")
                    }
                } footer: {
                    Text("在中国传统文化中，红色代表喜庆和好运。您可以根据个人习惯选择颜色代表输赢。")
                }

                // MARK: - Score Display Mode
                Section {
                    Picker("显示方式", selection: $instance.scorePerGame) {
                        HStack {
                            Image(systemName: "number.circle")
                            Text("每局分数")
                        }
                        .tag(true)
                        HStack {
                            Image(systemName: "sum")
                            Text("累计总分")
                        }
                        .tag(false)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    HStack {
                        Image(systemName: "list.number")
                            .foregroundColor(Color(hex: "FF6B35"))
                        Text("分数显示方式")
                    }
                } footer: {
                    Text("选择在列表中显示每局分数还是累计总分")
                }

                // MARK: - Bidding Order
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "hand.point.right.fill")
                                .foregroundColor(Color(hex: "FF6B35"))
                                .font(.system(size: 14))
                            Text("下一局先叫分的玩家")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }

                        Picker("先叫分", selection: $instance.room.starter) {
                            ForEach(0..<3, id: \.self) { index in
                                Text(playerName(index)).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(Color(hex: "FF6B35"))
                        Text("叫分顺序")
                    }
                } footer: {
                    Text("设置下一局由哪位玩家先开始叫分。叫分顺序会按A→B→C循环。")
                }

                // MARK: - Data Sync
                SyncSettingsView()

                // MARK: - About
                Section {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.secondary)
                            Text("版本")
                        }
                        Spacer()
                        Text("2.2")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Capsule())
                    }
                } header: {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(Color(hex: "FF6B35"))
                        Text("关于")
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "FF6B35"))
                }
            }
        }
    }

    private func playerName(_ index: Int) -> String {
        if index < players.count && !players[index].isEmpty {
            return players[index]
        }
        return ["玩家A", "玩家B", "玩家C"][index]
    }
}

#Preview {
    SettingView(players: ["张三", "李四", "王五"]).environmentObject(DataSingleton.instance)
}
