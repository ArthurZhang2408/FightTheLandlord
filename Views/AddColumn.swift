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
    
    @State private var currentStep = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress Indicator
                ProgressView(value: Double(currentStep + 1), total: 3)
                    .tint(.accentColor)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                HStack {
                    ForEach(0..<3) { step in
                        Text(stepTitle(step))
                            .font(.caption)
                            .foregroundColor(step == currentStep ? .accentColor : .secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                
                Divider()
                    .padding(.top, 12)
                
                // Step Content
                TabView(selection: $currentStep) {
                    // Step 1: Select Landlord & Bids
                    Step1LandlordView(viewModel: viewModel, turn: turn)
                        .tag(0)
                    
                    // Step 2: Multipliers
                    Step2MultipliersView(viewModel: viewModel)
                        .tag(1)
                    
                    // Step 3: Result
                    Step3ResultView(viewModel: viewModel)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                // Navigation Buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button {
                            withAnimation { currentStep -= 1 }
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("上一步")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if currentStep < 2 {
                        Button {
                            withAnimation { currentStep += 1 }
                        } label: {
                            HStack {
                                Text("下一步")
                                Image(systemName: "chevron.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            if viewModel.add() {
                                showingNewItemView = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("完成")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
                .padding()
            }
            .navigationTitle(viewModel.gameIdx == -1 ? "添加新局" : "修改第\(viewModel.gameIdx+1)局")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showingNewItemView = false
                    }
                }
            }
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text("输入错误"),
                    message: Text(viewModel.errorMessage),
                    dismissButton: .default(Text("确定"))
                )
            }
        }
    }
    
    private func stepTitle(_ step: Int) -> String {
        switch step {
        case 0: return "叫分"
        case 1: return "倍数"
        case 2: return "结果"
        default: return ""
        }
    }
}

// MARK: - Step 1: Landlord & Bids

struct Step1LandlordView: View {
    @ObservedObject var viewModel: AddColumnViewModel
    let turn: Int
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // First bidder indicator
                if turn >= 0 {
                    HStack {
                        Image(systemName: "hand.point.right.fill")
                            .foregroundColor(.orange)
                        Text("本局由 \(playerName(turn)) 先叫分")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Player bid cards
                VStack(spacing: 16) {
                    Text("每位玩家的叫分")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    PlayerBidCard(
                        name: viewModel.instance.room.aName.isEmpty ? "玩家A" : viewModel.instance.room.aName,
                        isFirstBidder: turn == 0,
                        selectedBid: $viewModel.apoint,
                        options: viewModel.points
                    )
                    
                    PlayerBidCard(
                        name: viewModel.instance.room.bName.isEmpty ? "玩家B" : viewModel.instance.room.bName,
                        isFirstBidder: turn == 1,
                        selectedBid: $viewModel.bpoint,
                        options: viewModel.points
                    )
                    
                    PlayerBidCard(
                        name: viewModel.instance.room.cName.isEmpty ? "玩家C" : viewModel.instance.room.cName,
                        isFirstBidder: turn == 2,
                        selectedBid: $viewModel.cpoint,
                        options: viewModel.points
                    )
                }
                
                // Landlord hint
                if let landlord = determineLandlord() {
                    HStack {
                        Text("👑")
                        Text("\(landlord) 成为地主")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.yellow.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
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

struct PlayerBidCard: View {
    let name: String
    let isFirstBidder: Bool
    @Binding var selectedBid: String
    let options: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(name)
                    .font(.headline)
                if isFirstBidder {
                    Text("先叫")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
                Spacer()
            }
            
            Picker("叫分", selection: $selectedBid) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Step 2: Multipliers

struct Step2MultipliersView: View {
    @ObservedObject var viewModel: AddColumnViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Bombs
                VStack(alignment: .leading, spacing: 12) {
                    Label("炸弹数量", systemImage: "bolt.fill")
                        .font(.headline)
                    
                    HStack {
                        Text("每个炸弹翻倍")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        
                        HStack(spacing: 16) {
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
                            
                            Text(viewModel.bombs.isEmpty ? "0" : viewModel.bombs)
                                .font(.title)
                                .fontWeight(.bold)
                                .frame(width: 50)
                            
                            Button {
                                let current = Int(viewModel.bombs) ?? 0
                                viewModel.bombs = "\(current + 1)"
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Spring
                VStack(alignment: .leading, spacing: 12) {
                    Label("春天", systemImage: "sun.max.fill")
                        .font(.headline)
                    
                    Toggle(isOn: $viewModel.setting.spring) {
                        VStack(alignment: .leading) {
                            Text("是否春天")
                            Text("一方打完所有牌对方一张未出")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Double options for each player
                VStack(alignment: .leading, spacing: 12) {
                    Label("加倍", systemImage: "xmark.circle.fill")
                        .font(.headline)
                    
                    Text("选择加倍的玩家")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        DoubleToggle(
                            name: viewModel.instance.room.aName.isEmpty ? "A" : viewModel.instance.room.aName,
                            isOn: $viewModel.setting.adouble
                        )
                        DoubleToggle(
                            name: viewModel.instance.room.bName.isEmpty ? "B" : viewModel.instance.room.bName,
                            isOn: $viewModel.setting.bdouble
                        )
                        DoubleToggle(
                            name: viewModel.instance.room.cName.isEmpty ? "C" : viewModel.instance.room.cName,
                            isOn: $viewModel.setting.cdouble
                        )
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }
}

struct DoubleToggle: View {
    let name: String
    @Binding var isOn: Bool
    
    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            VStack(spacing: 4) {
                Text(name)
                    .font(.subheadline)
                    .lineLimit(1)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isOn ? Color.accentColor.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isOn ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .foregroundColor(isOn ? .accentColor : .primary)
    }
}

// MARK: - Step 3: Result

struct Step3ResultView: View {
    @ObservedObject var viewModel: AddColumnViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Text("比赛结果")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                ResultButton(
                    title: "地主赢了",
                    icon: "👑",
                    subtitle: "地主获得积分",
                    isSelected: viewModel.setting.landlordResult,
                    color: .orange
                ) {
                    viewModel.setting.landlordResult = true
                }
                
                ResultButton(
                    title: "农民赢了",
                    icon: "🌾",
                    subtitle: "农民获得积分",
                    isSelected: !viewModel.setting.landlordResult,
                    color: .green
                ) {
                    viewModel.setting.landlordResult = false
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top)
    }
}

struct ResultButton: View {
    let title: String
    let icon: String
    let subtitle: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(icon)
                    .font(.system(size: 40))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(color)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? color.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .foregroundColor(.primary)
    }
}

#Preview {
    AddColumn(showingNewItemView: Binding(get: {return true}, set: { _ in}), turn: 0)
}
