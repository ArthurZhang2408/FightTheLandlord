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
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Player Bid Section
                    VStack(spacing: 16) {
                        Text("叫分")
                            .font(.customfont(.semibold, fontSize: 16))
                            .foregroundColor(.gray30)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(alignment: .top, spacing: 8) {
                            // Player A Column
                            PlayerBidColumn(
                                playerName: viewModel.instance.room.aName.isEmpty ? "玩家A" : viewModel.instance.room.aName,
                                isFirstBidder: turn == 0,
                                selectedBid: $viewModel.apoint,
                                isDoubled: $viewModel.setting.adouble,
                                points: viewModel.points
                            )
                            
                            // Player B Column
                            PlayerBidColumn(
                                playerName: viewModel.instance.room.bName.isEmpty ? "玩家B" : viewModel.instance.room.bName,
                                isFirstBidder: turn == 1,
                                selectedBid: $viewModel.bpoint,
                                isDoubled: $viewModel.setting.bdouble,
                                points: viewModel.points
                            )
                            
                            // Player C Column
                            PlayerBidColumn(
                                playerName: viewModel.instance.room.cName.isEmpty ? "玩家C" : viewModel.instance.room.cName,
                                isFirstBidder: turn == 2,
                                selectedBid: $viewModel.cpoint,
                                isDoubled: $viewModel.setting.cdouble,
                                points: viewModel.points
                            )
                        }
                    }
                    .padding(16)
                    .background(Color.gray80)
                    .cornerRadius(12)
                    
                    // MARK: - Game Modifiers Section
                    VStack(spacing: 16) {
                        Text("游戏参数")
                            .font(.customfont(.semibold, fontSize: 16))
                            .foregroundColor(.gray30)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Bombs Input
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.warningColor)
                            Text("炸弹数量")
                                .font(.customfont(.medium, fontSize: 14))
                                .foregroundColor(.gray40)
                            Spacer()
                            TextField("0", text: $viewModel.bombs)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.customfont(.semibold, fontSize: 16))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 36)
                                .background(Color.gray70)
                                .cornerRadius(8)
                        }
                        
                        Divider()
                            .background(Color.gray70)
                        
                        // Spring Toggle
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .foregroundColor(.winColor)
                            Text("春天")
                                .font(.customfont(.medium, fontSize: 14))
                                .foregroundColor(.gray40)
                            Spacer()
                            Toggle("", isOn: $viewModel.setting.spring)
                                .toggleStyle(CustomToggleStyle())
                        }
                    }
                    .padding(16)
                    .background(Color.gray80)
                    .cornerRadius(12)
                    
                    // MARK: - Result Section
                    VStack(spacing: 16) {
                        Text("结果")
                            .font(.customfont(.semibold, fontSize: 16))
                            .foregroundColor(.gray30)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Picker("result", selection: $viewModel.setting.landlordResult) {
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
                    .padding(16)
                    .background(Color.gray80)
                    .cornerRadius(12)
                    
                    Spacer(minLength: 20)
                    
                    // MARK: - Submit Button
                    PrimaryButton(title: viewModel.gameIdx == -1 ? "添加" : "保存修改") {
                        if viewModel.add() {
                            showingNewItemView = false
                        }
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(Color.grayC)
            .navigationTitle(viewModel.gameIdx == -1 ? "新一局" : "修改第\(viewModel.gameIdx + 1)局")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showingNewItemView = false
                    }
                    .foregroundColor(.gray40)
                }
            }
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text("错误"),
                    message: Text(viewModel.errorMessage)
                )
            }
        }
    }
}

// MARK: - Player Bid Column

struct PlayerBidColumn: View {
    let playerName: String
    let isFirstBidder: Bool
    @Binding var selectedBid: String
    @Binding var isDoubled: Bool
    let points: [String]
    
    var body: some View {
        VStack(spacing: 12) {
            // Player Name with first bidder indicator
            HStack(spacing: 4) {
                if isFirstBidder {
                    Image(systemName: "hand.point.right.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.primary500)
                }
                Text(playerName)
                    .font(.customfont(.semibold, fontSize: 14))
                    .foregroundColor(isFirstBidder ? .primary500 : .white)
                    .lineLimit(1)
            }
            .frame(height: 24)
            
            // Bid Selection
            Menu {
                ForEach(points, id: \.self) { point in
                    Button(point) {
                        selectedBid = point
                    }
                }
            } label: {
                Text(selectedBid)
                    .font(.customfont(.medium, fontSize: 14))
                    .foregroundColor(selectedBid == "不叫" ? .gray50 : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(selectedBid == "不叫" ? Color.gray70 : Color.primary.opacity(0.3))
                    .cornerRadius(8)
            }
            
            // Double Toggle
            Button {
                isDoubled.toggle()
            } label: {
                Text("加倍")
                    .font(.customfont(.medium, fontSize: 12))
                    .foregroundColor(isDoubled ? .white : .gray50)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(isDoubled ? Color.primary500 : Color.gray70)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Custom Toggle Style

struct CustomToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                Spacer()
                RoundedRectangle(cornerRadius: 16)
                    .fill(configuration.isOn ? Color.primary500 : Color.gray70)
                    .frame(width: 50, height: 30)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 26, height: 26)
                            .offset(x: configuration.isOn ? 10 : -10)
                    )
                    .animation(.spring(response: 0.3), value: configuration.isOn)
            }
        }
    }
}

#Preview {
    AddColumn(showingNewItemView: Binding(get: { return true }, set: { _ in }), turn: 0)
}
