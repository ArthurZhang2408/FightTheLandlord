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
    var width: CGFloat = 90
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("", text: $viewModel.instance.room.aName)
                        .frame(height: height)
                        .padding(15)
                        .overlay {
                            RoundedRectangle(cornerRadius:  15)
                                .stroke(Color.gray70, lineWidth: 1)
                        }
                    TextField("", text: $viewModel.instance.room.bName)
                        .frame(height: height)
                        .padding(15)
                        .overlay {
                            RoundedRectangle(cornerRadius:  15)
                                .stroke(Color.gray70, lineWidth: 1)
                        }
                    TextField("", text: $viewModel.instance.room.cName)
                        .frame(height: height)
                        .padding(15)
                        .overlay {
                            RoundedRectangle(cornerRadius:  15)
                                .stroke(Color.gray70, lineWidth: 1)
                        }
                }
                List {
                    ForEach(viewModel.instance.games.indices, id: \.self) {idx in
                        HStack {
                            Text("\(idx+1): ")
                                .frame(width: width)
                            Text(viewModel.instance.games[idx].A.description)
                                .frame(width: width)
                                .foregroundColor(viewModel.instance.games[idx].aC.color)
                            Text(viewModel.instance.games[idx].B.description)
                                .frame(width: width)
                                .foregroundColor(viewModel.instance.games[idx].bC.color)
                            Text(viewModel.instance.games[idx].C.description)
                                .frame(width: width)
                                .foregroundColor(viewModel.instance.games[idx].cC.color)
                        }
                        .frame(width: width * 4)
                    }
                    HStack {
                        Text("总分: ")
                            .frame(width: width)
                        Text(viewModel.instance.aRe.description)
                            .frame(width: width)
                        Text(viewModel.instance.bRe.description)
                            .frame(width: width)
                        Text(viewModel.instance.cRe.description)
                            .frame(width: width)
                    }
                    .frame(width: width * 4)
                }
                .frame(width: .screenWidth)
            }
            .padding()
            .navigationTitle("今日第\(viewModel.instance.gameNum)局")
            .toolbar{
                Button {
                    viewModel.showingNewItemView = true
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    showConfirm.toggle()
                } label: {
                    Image(systemName: "circle")
                }
            }
            .sheet(isPresented: $viewModel.showingNewItemView)
            {
                AddColumn( showingNewItemView: $viewModel.showingNewItemView )
            }.confirmationDialog("确定", isPresented: $showConfirm) {
                Button {
                    viewModel.instance.page = "welcome"
                } label: {
                    Label("确定结束牌局吗？",
                    systemImage: "questionmark.circle")
                }
            }
            .alert(isPresented: $viewModel.instance.listingShowAlert) {
                Alert(
                    title: Text("错误"),
                    message: Text("没有可以继续的游戏，已开始新的牌局")
                )
            }
        }
    }
}

#Preview {
    ListingView().environmentObject(DataSingleton.instance)
}
