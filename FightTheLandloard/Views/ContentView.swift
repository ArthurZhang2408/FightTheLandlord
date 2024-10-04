//
//  ContentView.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-04.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel: ListingViewModel = ListingViewModel()
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
            .navigationTitle("斗地主计分牌")
            .toolbar{
                Button {
                    viewModel.showingNewItemView = true
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    viewModel.list = []
                } label: {
                    Image(systemName: "circle")
                }
            }
            .sheet(isPresented: $viewModel.showingNewItemView)
            {
                AddColumn( showingNewItemView: $viewModel.showingNewItemView, list: $viewModel.list, A: viewModel.A, B: viewModel.B, C: viewModel.C )
            }
        }
    }
}

#Preview {
    ContentView()
}
