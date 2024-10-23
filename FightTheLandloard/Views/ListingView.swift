//
//  ContentView.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-04.
//

import SwiftUI

struct ListingView: View {
    @StateObject var viewModel: ListingViewModel = ListingViewModel()
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
                            Text((viewModel.instance.scorePerGame ? viewModel.instance.games[idx].A : viewModel.instance.scores[idx].A).description)
                                .frame(width: width)
                                .foregroundColor(viewModel.instance.games[idx].aC.color)
                            Text((viewModel.instance.scorePerGame ? viewModel.instance.games[idx].B : viewModel.instance.scores[idx].B).description)
                                .frame(width: width)
                                .foregroundColor(viewModel.instance.games[idx].bC.color)
                            Text((viewModel.instance.scorePerGame ? viewModel.instance.games[idx].C : viewModel.instance.scores[idx].C).description)
                                .frame(width: width)
                                .foregroundColor(viewModel.instance.games[idx].cC.color)
                        }
                        .frame(width: width * 4)
                        .swipeActions(allowsFullSwipe: false) {
                            Button {
                                viewModel.gameIdx = idx
                                viewModel.showingNewItemView = true
                            } label: {
                                Label("Mute", systemImage: "bell.slash.fill")
                            }
                            .tint(.indigo)
                            Button {
                                viewModel.deleteIdx = idx
                                viewModel.deletingItem = true
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                    }.onMove { from, to in
                        viewModel.instance.games.move(fromOffsets: from, toOffset: to)
                        viewModel.instance.updateScore(from: min(from.first ?? 0, to))
                    }
                    if viewModel.instance.scorePerGame {
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
                }
                .frame(width: .screenWidth)
            }
            .padding()
            .navigationTitle("今日第\(viewModel.instance.gameNum)局")
            .toolbar{
                Button {
                    viewModel.showingSettingView = true
                } label: {
                    Image(systemName: "gear")
                }
                Button {
                    viewModel.gameIdx = -1
                    viewModel.showingNewItemView = true
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    viewModel.showConfirm.toggle()
                } label: {
                    Image(systemName: "circle")
                }
            }
            .sheet(isPresented: $viewModel.showingNewItemView)
            {
                AddColumn( showingNewItemView: $viewModel.showingNewItemView, viewModel: AddColumnViewModel(idx: viewModel.gameIdx), turn: (viewModel.gameIdx == -1) ? (viewModel.instance.games.count + viewModel.instance.room.starter) % 3 : -1 )
            }
            .sheet(isPresented: $viewModel.showingSettingView)
            {
                SettingView(players: [viewModel.instance.room.aName, viewModel.instance.room.bName, viewModel.instance.room.cName]).environmentObject(DataSingleton.instance)
            }
            .confirmationDialog("确定", isPresented: $viewModel.showConfirm) {
                Button {
                    viewModel.instance.page = "welcome"
                } label: {
                    Label("确定结束牌局吗？",
                    systemImage: "questionmark.circle")
                }
            }
            .confirmationDialog("确定", isPresented: $viewModel.deletingItem) {
                Button {
                    viewModel.instance.delete(idx: viewModel.deleteIdx)
                } label: {
                    Label("确定删除第\(viewModel.deleteIdx+1)局吗？",
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
