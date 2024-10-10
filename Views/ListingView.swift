//
//  ContentView.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-04.
//

import SwiftUI

struct ListingView: View {
    @StateObject var viewModel: ListingViewModel = ListingViewModel()
    @State var showConfirm: Bool = false
    @EnvironmentObject var instance: DataSingleton
    var height: CGFloat = 10
    var width: CGFloat = 120
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("", text: $viewModel.A)
                        .frame(height: height)
                        .padding(15)
                        .overlay {
                            RoundedRectangle(cornerRadius:  15)
                                .stroke(Color.gray70, lineWidth: 1)
                        }
                    TextField("", text: $viewModel.B)
                        .frame(height: height)
                        .padding(15)
                        .overlay {
                            RoundedRectangle(cornerRadius:  15)
                                .stroke(Color.gray70, lineWidth: 1)
                        }
                    TextField("", text: $viewModel.C)
                        .frame(height: height)
                        .padding(15)
                        .overlay {
                            RoundedRectangle(cornerRadius:  15)
                                .stroke(Color.gray70, lineWidth: 1)
                        }
                }
                List(viewModel.list) { inst in
                    HStack {
                        Text(inst.A.description)
                            .frame(width: width)
                        Text(inst.B.description)
                            .frame(width: width)
                        Text(inst.C.description)
                            .frame(width: width)
                    }
                    .frame(width: width * 3)
                }
            }
            .padding()
            .navigationTitle("今日第\(instance.gameNum)局")
            .toolbar{
                Button {
                    viewModel.showingNewItemView = true
                } label: {
                    Image(systemName: "plus")
                }
                Button {
//                    viewModel.list = []
                    showConfirm.toggle()
                } label: {
                    Image(systemName: "circle")
                }
            }
            .sheet(isPresented: $viewModel.showingNewItemView)
            {
                AddColumn( showingNewItemView: $viewModel.showingNewItemView, list: $viewModel.list, A: viewModel.A, B: viewModel.B, C: viewModel.C )
            }.confirmationDialog("确定", isPresented: $showConfirm) {
                Button {
                    viewModel.list = []
                    viewModel.instance.page = "welcome"
                } label: {
                    Label("确定结束牌局吗？",
                    systemImage: "questionmark.circle")
                }
            }
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text("错误"),
                    message: Text("没有可以继续的游戏，已开始新的牌局")
                )
            }
        }
    }
}

#Preview {
    ListingView()
}
