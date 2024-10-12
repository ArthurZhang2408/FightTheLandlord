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
    var width: CGFloat = 80
    var body: some View {
        NavigationView {
            VStack {
                VStack (alignment: .center) {
                    HStack {
                        VStack (spacing: 20) {
                            VStack{
                                Text("名字：")
                            }
                            .frame(height: height)
                            VStack{
                                Text("叫分：")
                            }
                            .frame(height: height)
                            VStack{
                                Text("加倍：")
                            }
                            .frame(height: height)
                        }
                        .frame(width: width)
                        VStack (spacing: 20) {
                            VStack{
                                Text(viewModel.instance.room.aName)
                            }
                            .frame(height: height)
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
                                    Label("", systemImage: "flag.fill")
                                }
                                .toggleStyle(.button)
                            }
                            .frame(height: height)
                        }
                        .frame(width: width)
                        VStack (spacing: 20) {
                            VStack{
                                Text(viewModel.instance.room.bName)
                            }
                            .frame(height: height)
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
                                    Label("", systemImage: "flag.fill")
                                }
                                .toggleStyle(.button)
                            }
                            .frame(height: height)
                        }
                        .frame(width: width)
                        VStack (spacing: 20) {
                            VStack{
                                Text(viewModel.instance.room.cName)
                            }
                            .frame(height: height)
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
                                    Label("", systemImage: "flag.fill")
                                }
                                .toggleStyle(.button)
                            }
                            .frame(height: height)
                        }
                        .frame(width: width)
                    }
                    .padding(.bottom, 10)
                    HStack {
                        VStack (spacing: 20){
                            VStack{
                                Text("炸弹：")
                            }
                            .frame(height: height)
                            .frame(width: width)
                            
                            VStack{
                                Text("地主：")
                            }
                            .frame(height: height)
                            .frame(width: width)
                        }
                        //                    .padding(.trailing, 60)
                        VStack (spacing: 20){
                            VStack{
                                TextField("", text: $viewModel.bombs)
                                    .autocorrectionDisabled()
                                    .autocapitalization(/*@START_MENU_TOKEN@*/.none/*@END_MENU_TOKEN@*/)
                                    .keyboardType(.decimalPad)
                                    .frame(height: 8)
                                    .padding(15)
                                    .overlay {
                                        RoundedRectangle(cornerRadius:  15)
                                            .stroke(Color.gray70, lineWidth: 1)
                                    }
                                    .foregroundColor(.white)
                                    .background(Color.gray60.opacity(0.05))
                                    .cornerRadius(15)
                            }
                            .frame(width: 240)
                            .frame(height: height)
                            VStack{
                                
                                Picker("landlord", selection: $viewModel.landlordResult) {
                                    ForEach(viewModel.results, id: \.self) { result in
                                        Text(result)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .frame(width: 240)
                            .frame(height: height)
                        }
                        .padding(.trailing, 14)
                    }
                }
                .padding(.top, .topInsets + 20)
                .padding(.leading, 20)
                .padding(.trailing, 20)
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
    AddColumn(showingNewItemView: Binding(get: {return true}, set: { _ in}))
}
