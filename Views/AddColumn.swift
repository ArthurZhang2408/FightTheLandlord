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
    var height: CGFloat = 40
    var width: CGFloat = .screenWidth/3.5
    var leadingPad: CGFloat = 13
    let turn: Int
    var body: some View {
        NavigationView {
            VStack {
                VStack (alignment: .center) {
                    HStack {
                        VStack (alignment: .leading, spacing: 20) {
                            VStack{
                                Text(viewModel.instance.room.aName)
                                    .foregroundStyle((turn == 0) ? .blue : .white)
//                                Text("A")
                            }
                            .frame(height: height)
                            .padding(.leading, leadingPad)
                            VStack{
                                Picker(selection: $viewModel.apoint) {
                                    ForEach(viewModel.points, id: \.self) { curr in
                                        Text(curr)
                                    }
                                } label: {
                                }
                            }
                            .frame(height: height)
                            VStack{
                                Toggle(isOn: $viewModel.setting.adouble) {
                                    Text("加倍")
                                }
                                .toggleStyle(.button)
                            }
                            .frame(height: height)
                        }
                        .frame(width: width)
                        VStack (alignment: .leading, spacing: 20) {
                            VStack{
                                Text(viewModel.instance.room.bName)
                                    .foregroundStyle((turn == 1) ? .blue : .white)
//                                Text("A")
                            }
                            .frame(height: height)
                            .padding(.leading, leadingPad)
                            VStack{
                                Picker(selection: $viewModel.bpoint) {
                                    ForEach(viewModel.points, id: \.self) { curr in
                                        Text(curr)
                                    }
                                } label: {
                                }
                            }
                            .frame(height: height)
                            VStack{
                                Toggle(isOn: $viewModel.setting.bdouble) {
                                    Text("加倍")
                                }
                                .toggleStyle(.button)
                            }
                            .frame(height: height)
                        }
                        .frame(width: width)
                        VStack (alignment: .leading, spacing: 20) {
                            VStack{
                                Text(viewModel.instance.room.cName)
                                    .foregroundStyle((turn == 2) ? .blue : .white)
//                                Text("A")
                            }
                            .frame(height: height)
                            .padding(.leading, leadingPad)
                            VStack{
                                Picker(selection: $viewModel.cpoint) {
                                    ForEach(viewModel.points, id: \.self) { curr in
                                        Text(curr)
                                    }
                                } label: {
                                }
                            }
                            .frame(height: height)
                            VStack{
                                Toggle(isOn: $viewModel.setting.cdouble) {
                                    Text("加倍")
                                }
                                .toggleStyle(.button)
                            }
                            .frame(height: height)
                        }
                        .frame(width: width)
                    }
                    .padding(.bottom, 30)
                    HStack {
                        VStack (spacing: 40){
                            VStack{
//                                TextField("", text: $viewModel.bombs)
//                                    .autocorrectionDisabled()
//                                    .autocapitalization(.none)
//                                    .keyboardType(.decimalPad)
//                                    .frame(height: 8)
//                                    .padding(15)
//                                    .overlay {
//                                        RoundedRectangle(cornerRadius:  15)
//                                            .stroke(Color.gray70, lineWidth: 1)
//                                    }
//                                    .foregroundColor(.white)
//                                    .background(Color.gray60.opacity(0.05))
//                                    .cornerRadius(15)
                                RoundTextField(title: "炸弹", text: $viewModel.bombs, keyboardType: .decimal, height: 35)
                            }
                            .frame(height: height)
                            VStack{
                                Toggle(isOn: $viewModel.setting.spring) {
                                    Text("春天")
                                }
                                .toggleStyle(.button)
                            }
                            .frame(height: height)
                            VStack{
                                
                                Picker("landlord", selection: $viewModel.setting.landlordResult) {
                                    ForEach(viewModel.results, id: \.self) { result in
                                        Text(result).tag(result == "地主赢了")
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .frame(height: height)
                        }
                        .padding(.horizontal, 50)
                    }
                }
                .padding(.top, .topInsets + 20)
                Spacer()
                PrimaryButton(title: "添加", onPressed: {
                    if (viewModel.add()){
                        showingNewItemView = false
                    }
                })
            }
            .navigationTitle(viewModel.gameIdx == -1 ? "新一局" : "修改第\(viewModel.gameIdx+1)局")
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text("错误"),
                    message: Text(viewModel.errorMessage)
                )
            }
        }
        
    }
}

#Preview {
    AddColumn(showingNewItemView: Binding(get: {return true}, set: { _ in}), turn: 0)
}
