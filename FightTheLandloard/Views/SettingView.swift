//
//  SettingView.swift
//  FightTheLandloard
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
                // MARK: - 显示设置
                Section {
                    // Color preference
                    VStack(alignment: .leading, spacing: 8) {
                        Text("分数颜色")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("颜色设置", selection: $instance.greenWin) {
                            HStack {
                                Circle().fill(.green).frame(width: 12, height: 12)
                                Text("绿色为赢")
                            }
                            .tag(true)
                            
                            HStack {
                                Circle().fill(.red).frame(width: 12, height: 12)
                                Text("红色为赢")
                            }
                            .tag(false)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Preview
                    HStack {
                        Text("预览:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("+100")
                            .fontWeight(.bold)
                            .foregroundColor(instance.greenWin ? .green : .red)
                        Text("/")
                            .foregroundColor(.secondary)
                        Text("-100")
                            .fontWeight(.bold)
                            .foregroundColor(instance.greenWin ? .red : .green)
                    }
                    .font(.subheadline)
                } header: {
                    Text("显示设置")
                } footer: {
                    Text("在中国传统文化中，红色代表喜庆和好运。您可以根据个人习惯选择颜色代表输赢。")
                }
                
                // MARK: - 分数显示方式
                Section {
                    Picker("显示方式", selection: $instance.scorePerGame) {
                        Text("每局分数").tag(true)
                        Text("累计总分").tag(false)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("分数显示方式")
                } footer: {
                    Text("选择在列表中显示每局分数还是累计总分")
                }
                
                // MARK: - 先叫分设置
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("下一局先叫分的玩家")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("先叫分", selection: $instance.room.starter) {
                            ForEach(0..<3, id: \.self) { index in
                                Text(playerName(index)).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    Text("叫分顺序")
                } footer: {
                    Text("设置下一局由哪位玩家先开始叫分。叫分顺序会按A→B→C循环。")
                }
                
                // MARK: - 关于
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("2.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
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
