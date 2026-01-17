//
//  MatchHistoryView.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-20.
//

import SwiftUI
import Charts

struct MatchHistoryView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var dataSingleton = DataSingleton.instance
    @State private var matchToDelete: MatchRecord?
    @State private var showingDeleteConfirm = false
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if firebaseService.isLoadingMatches {
                    ProgressView("加载中...")
                } else if firebaseService.matches.isEmpty {
                    emptyStateView
                } else {
                    matchListView
                }
            }
            .navigationTitle("历史对局")
            .navigationDestination(for: MatchRecord.self) { match in
                MatchDetailView(match: match)
            }
            .alert("确定删除该对局吗？", isPresented: $showingDeleteConfirm) {
                Button("取消", role: .cancel) {
                    matchToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let match = matchToDelete, let id = match.id {
                        firebaseService.deleteMatch(matchId: id) { _ in }
                    }
                    matchToDelete = nil
                }
            }
            .onChange(of: dataSingleton.navigateToMatchId) { newMatchId in
                if let matchId = newMatchId {
                    if let match = firebaseService.matches.first(where: { $0.id == matchId }) {
                        navigationPath.append(match)
                        dataSingleton.navigateToMatchId = nil
                    }
                }
            }
            .onChange(of: firebaseService.matches) { _ in
                if let matchId = dataSingleton.navigateToMatchId {
                    if let match = firebaseService.matches.first(where: { $0.id == matchId }) {
                        navigationPath.append(match)
                        dataSingleton.navigateToMatchId = nil
                    }
                }
            }
            .onAppear {
                if let matchId = dataSingleton.navigateToMatchId {
                    if let match = firebaseService.matches.first(where: { $0.id == matchId }) {
                        navigationPath.append(match)
                        dataSingleton.navigateToMatchId = nil
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            Text("暂无历史对局")
                .font(.title2)
                .fontWeight(.medium)
            Text("结束一场对局后会在这里显示")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var matchListView: some View {
        List {
            ForEach(firebaseService.matches) { match in
                Button {
                    navigationPath.append(match)
                } label: {
                    MatchRowView(match: match)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        matchToDelete = match
                        showingDeleteConfirm = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct MatchRowView: View {
    let match: MatchRecord
    @ObservedObject private var dataSingleton = DataSingleton.instance
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score == 0 { return .primary }
        let isPositive = score > 0
        if dataSingleton.greenWin {
            return isPositive ? .green : .red
        } else {
            return isPositive ? .red : .green
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dateFormatter.string(from: match.startedAt))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(match.totalGames)局")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                PlayerScoreLabel(name: match.playerAName, score: match.finalScoreA, color: scoreColor(match.finalScoreA))
                PlayerScoreLabel(name: match.playerBName, score: match.finalScoreB, color: scoreColor(match.finalScoreB))
                PlayerScoreLabel(name: match.playerCName, score: match.finalScoreC, color: scoreColor(match.finalScoreC))
            }
        }
        .padding(.vertical, 4)
    }
}

struct PlayerScoreLabel: View {
    let name: String
    let score: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            Text("\(score)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// Wrapper to make Int identifiable for sheet(item:)
struct EditingGameItem: Identifiable {
    let id = UUID()
    let index: Int
}

struct MatchDetailView: View {
    let match: MatchRecord
    @State private var gameRecords: [GameRecord] = []
    @State private var isLoading = true
    @State private var editingGame: EditingGameItem? = nil
    @State private var showingDeleteConfirm = false
    @State private var deleteIdx: Int = -1
    @ObservedObject private var dataSingleton = DataSingleton.instance
    
    @State private var games: [GameSetting] = []
    @State private var scores: [ScoreTriple] = []
    @State private var aRe: Int = 0
    @State private var bRe: Int = 0
    @State private var cRe: Int = 0
    
    private var displayScoreA: Int {
        games.isEmpty ? match.finalScoreA : aRe
    }
    private var displayScoreB: Int {
        games.isEmpty ? match.finalScoreB : bRe
    }
    private var displayScoreC: Int {
        games.isEmpty ? match.finalScoreC : cRe
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score == 0 { return .primary }
        let isPositive = score > 0
        if dataSingleton.greenWin {
            return isPositive ? .green : .red
        } else {
            return isPositive ? .red : .green
        }
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载中...")
            } else {
                List {
                    Section {
                        VStack(spacing: 12) {
                            Text(dateFormatter.string(from: match.startedAt))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 20) {
                                VStack {
                                    Text(match.playerAName)
                                        .font(.headline)
                                    Text("\(displayScoreA)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(scoreColor(displayScoreA))
                                }
                                VStack {
                                    Text(match.playerBName)
                                        .font(.headline)
                                    Text("\(displayScoreB)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(scoreColor(displayScoreB))
                                }
                                VStack {
                                    Text(match.playerCName)
                                        .font(.headline)
                                    Text("\(displayScoreC)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(scoreColor(displayScoreC))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    
                    Section {
                        if games.isEmpty {
                            Text("暂无详细记录")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(games.indices, id: \.self) { idx in
                                GameRecordRow(
                                    gameNumber: idx + 1,
                                    game: games[idx],
                                    playerNames: (match.playerAName, match.playerBName, match.playerCName)
                                )
                                .swipeActions(allowsFullSwipe: false) {
                                    Button {
                                        // Use item-based sheet to ensure proper index binding
                                        editingGame = EditingGameItem(index: idx)
                                    } label: {
                                        Label("修改", systemImage: "pencil")
                                    }
                                    .tint(.indigo)
                                }
                            }
                        }
                    } header: {
                        Text("每局详情 (\(games.count)局)")
                    }
                    
                    // Score Line Chart
                    if games.count >= 2 {
                        Section {
                            ScoreLineChart(
                                scores: scores,
                                playerNames: (match.playerAName, match.playerBName, match.playerCName)
                            )
                            .frame(height: 200)
                        } header: {
                            Text("得分走势")
                        }
                    }
                    
                    if !gameRecords.isEmpty {
                        Section {
                            ForEach([
                                (match.playerAId, match.playerAName, 1),
                                (match.playerBId, match.playerBName, 2),
                                (match.playerCId, match.playerCName, 3)
                            ], id: \.0) { (playerId, playerName, position) in
                                MatchPlayerStatRow(
                                    playerName: playerName,
                                    position: position,
                                    games: gameRecords,
                                    finalScore: position == 1 ? displayScoreA : (position == 2 ? displayScoreB : displayScoreC)
                                )
                            }
                        } header: {
                            Text("玩家统计")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("对局详情")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let matchId = match.id {
                    NavigationLink(destination: FullMatchStatsView(matchId: matchId)) {
                        Image(systemName: "chart.bar")
                    }
                }
            }
        }
        .onAppear {
            loadGameRecords()
        }
        .sheet(item: $editingGame) { editItem in
            HistoryEditView(
                editingGame: $editingGame,
                games: $games,
                scores: $scores,
                aRe: $aRe,
                bRe: $bRe,
                cRe: $cRe,
                editingIndex: editItem.index,
                match: match,
                playerAName: match.playerAName,
                playerBName: match.playerBName,
                playerCName: match.playerCName
            )
        }
    }
    
    private func loadGameRecords() {
        guard let matchId = match.id else {
            isLoading = false
            return
        }
        
        FirebaseService.shared.loadGameRecords(forMatch: matchId) { result in
            isLoading = false
            switch result {
            case .success(let records):
                gameRecords = records
                games = records.map { record in
                    var setting = GameSetting()
                    setting.bombs = record.bombs
                    setting.apoint = record.apoint
                    setting.bpoint = record.bpoint
                    setting.cpoint = record.cpoint
                    setting.adouble = record.adouble
                    setting.bdouble = record.bdouble
                    setting.cdouble = record.cdouble
                    setting.spring = record.isSpring
                    setting.landlordResult = record.landlordResult
                    setting.landlord = record.landlord
                    setting.A = record.scoreA
                    setting.B = record.scoreB
                    setting.C = record.scoreC
                    if record.landlord == 1 {
                        setting.aC = record.landlordResult ? "green" : "red"
                    } else if record.landlord == 2 {
                        setting.bC = record.landlordResult ? "green" : "red"
                    } else {
                        setting.cC = record.landlordResult ? "green" : "red"
                    }
                    return setting
                }
                updateScores()
            case .failure(let error):
                print("Error loading game records: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateScores() {
        aRe = 0
        bRe = 0
        cRe = 0
        scores = []
        for game in games {
            aRe += game.A
            bRe += game.B
            cRe += game.C
            scores.append(ScoreTriple(A: aRe, B: bRe, C: cRe))
        }
    }
}

struct GameRecordRow: View {
    let gameNumber: Int
    let game: GameSetting
    let playerNames: (String, String, String)
    @ObservedObject private var dataSingleton = DataSingleton.instance
    
    private func scoreColor(for colorString: String) -> Color {
        return colorString.color
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(gameNumber)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor.opacity(0.8)))
            
            HStack(spacing: 0) {
                GameScoreItem(name: playerNames.0, score: game.A, isLandlord: game.landlord == 1, color: scoreColor(for: game.aC))
                GameScoreItem(name: playerNames.1, score: game.B, isLandlord: game.landlord == 2, color: scoreColor(for: game.bC))
                GameScoreItem(name: playerNames.2, score: game.C, isLandlord: game.landlord == 3, color: scoreColor(for: game.cC))
            }
        }
        .padding(.vertical, 4)
    }
}

struct GameScoreItem: View {
    let name: String
    let score: Int
    let isLandlord: Bool
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                if isLandlord {
                    Text("👑")
                        .font(.caption2)
                }
                Text(name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Text(score >= 0 ? "+\(score)" : "\(score)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HistoryEditView: View {
    @Binding var editingGame: EditingGameItem?
    @Binding var games: [GameSetting]
    @Binding var scores: [ScoreTriple]
    @Binding var aRe: Int
    @Binding var bRe: Int
    @Binding var cRe: Int
    let editingIndex: Int
    let match: MatchRecord
    let playerAName: String
    let playerBName: String
    let playerCName: String
    
    @StateObject private var viewModel: HistoryEditViewModel
    
    init(editingGame: Binding<EditingGameItem?>, games: Binding<[GameSetting]>, scores: Binding<[ScoreTriple]>, 
         aRe: Binding<Int>, bRe: Binding<Int>, cRe: Binding<Int>,
         editingIndex: Int, match: MatchRecord, playerAName: String, playerBName: String, playerCName: String) {
        self._editingGame = editingGame
        self._games = games
        self._scores = scores
        self._aRe = aRe
        self._bRe = bRe
        self._cRe = cRe
        self.editingIndex = editingIndex
        self.match = match
        self.playerAName = playerAName
        self.playerBName = playerBName
        self.playerCName = playerCName
        // Since we use sheet(item:), editingIndex is always valid when this is called
        let gamesArray = games.wrappedValue
        let safeGame = (editingIndex >= 0 && editingIndex < gamesArray.count) ? gamesArray[editingIndex] : GameSetting()
        self._viewModel = StateObject(wrappedValue: HistoryEditViewModel(game: safeGame))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PlayerBidCardHistory(
                        name: playerAName,
                        isFirstBidder: false,
                        selectedBid: $viewModel.apoint,
                        isDoubled: $viewModel.setting.adouble,
                        options: viewModel.points
                    )
                    PlayerBidCardHistory(
                        name: playerBName,
                        isFirstBidder: false,
                        selectedBid: $viewModel.bpoint,
                        isDoubled: $viewModel.setting.bdouble,
                        options: viewModel.points
                    )
                    PlayerBidCardHistory(
                        name: playerCName,
                        isFirstBidder: false,
                        selectedBid: $viewModel.cpoint,
                        isDoubled: $viewModel.setting.cdouble,
                        options: viewModel.points
                    )
                } header: {
                    Text("玩家叫分")
                }
                
                Section {
                    HStack {
                        Label("炸弹数量", systemImage: "bolt.fill")
                        Spacer()
                        HStack(spacing: 16) {
                            Button {
                                let current = Int(viewModel.bombs) ?? 0
                                if current > 0 {
                                    viewModel.bombs = "\(current - 1)"
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Text(viewModel.bombs.isEmpty ? "0" : viewModel.bombs)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .frame(minWidth: 30)
                            
                            Button {
                                let current = Int(viewModel.bombs) ?? 0
                                viewModel.bombs = "\(current + 1)"
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Toggle(isOn: $viewModel.setting.spring) {
                        Label("春天", systemImage: "sun.max.fill")
                    }
                } header: {
                    Text("倍数")
                }
                
                Section {
                    Picker("比赛结果", selection: $viewModel.setting.landlordResult) {
                        Text("地主赢").tag(true)
                        Text("农民赢").tag(false)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("结果")
                }
            }
            .navigationTitle("修改第\(editingIndex + 1)局")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        editingGame = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if viewModel.save() {
                            games[editingIndex] = viewModel.setting
                            updateLocalScores()
                            saveToFirebase()
                            editingGame = nil
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("错误", isPresented: $viewModel.showAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    private func updateLocalScores() {
        aRe = 0
        bRe = 0
        cRe = 0
        scores = []
        for game in games {
            aRe += game.A
            bRe += game.B
            cRe += game.C
            scores.append(ScoreTriple(A: aRe, B: bRe, C: cRe))
        }
    }
    
    private func saveToFirebase() {
        guard let matchId = match.id else { return }
        
        var updatedMatch = match
        updatedMatch.finalize(games: games, scores: scores)
        
        FirebaseService.shared.updateMatch(updatedMatch) { result in
            if case .failure(let error) = result {
                print("Error updating match: \(error.localizedDescription)")
            }
        }
        
        var gameRecords: [GameRecord] = []
        for (index, game) in games.enumerated() {
            let firstBidder = (index + match.initialStarter) % 3
            let record = GameRecord(
                matchId: matchId,
                gameIndex: index,
                playerAId: match.playerAId,
                playerBId: match.playerBId,
                playerCId: match.playerCId,
                playerAName: match.playerAName,
                playerBName: match.playerBName,
                playerCName: match.playerCName,
                gameSetting: game,
                firstBidder: firstBidder
            )
            gameRecords.append(record)
        }
        
        FirebaseService.shared.updateGameRecords(gameRecords, matchId: matchId) { result in
            if case .failure(let error) = result {
                print("Error updating game records: \(error.localizedDescription)")
            }
        }
    }
}

class HistoryEditViewModel: ObservableObject {
    @Published var bombs: String = ""
    @Published var apoint: String = "不叫"
    @Published var bpoint: String = "不叫"
    @Published var cpoint: String = "不叫"
    @Published var showAlert: Bool = false
    @Published var errorMessage: String = ""
    let results: [String] = ["地主赢了", "地主输了"]
    var basepoint: Int = 100
    @Published var setting: GameSetting
    let points: [String] = ["不叫", "1分", "2分", "3分"]
    
    init(game: GameSetting) {
        self.setting = game
        self.bombs = game.bombs == 0 ? "" : "\(game.bombs)"
        self.apoint = game.apoint.point
        self.bpoint = game.bpoint.point
        self.cpoint = game.cpoint.point
    }
    
    private func validate() -> Bool {
        errorMessage = ""
        if apoint == "3分" {
            guard bpoint != "3分" && cpoint != "3分" else {
                errorMessage = "多人叫3分"
                return false
            }
            setting.landlord = 1
            basepoint = 300
        } else if bpoint == "3分" {
            guard apoint != "3分" && cpoint != "3分" else {
                errorMessage = "多人叫3分"
                return false
            }
            setting.landlord = 2
            basepoint = 300
        } else if cpoint == "3分" {
            guard apoint != "3分" && bpoint != "3分" else {
                errorMessage = "多人叫3分"
                return false
            }
            setting.landlord = 3
            basepoint = 300
        } else if apoint == "2分" {
            guard bpoint != "2分" && cpoint != "2分" else {
                errorMessage = "多人叫2分"
                return false
            }
            setting.landlord = 1
            basepoint = 200
        } else if bpoint == "2分" {
            guard apoint != "2分" && cpoint != "2分" else {
                errorMessage = "多人叫2分"
                return false
            }
            setting.landlord = 2
            basepoint = 200
        } else if cpoint == "2分" {
            guard apoint != "2分" && bpoint != "2分" else {
                errorMessage = "多人叫2分"
                return false
            }
            setting.landlord = 3
            basepoint = 200
        } else if apoint == "1分" {
            guard bpoint != "1分" && cpoint != "1分" else {
                errorMessage = "多人叫1分"
                return false
            }
            setting.landlord = 1
        } else if bpoint == "1分" {
            guard apoint != "1分" && cpoint != "1分" else {
                errorMessage = "多人叫1分"
                return false
            }
            setting.landlord = 2
        } else if cpoint == "1分" {
            guard apoint != "1分" && bpoint != "1分" else {
                errorMessage = "多人叫1分"
                return false
            }
            setting.landlord = 3
        } else {
            errorMessage = "没有人叫分"
            return false
        }
        return true
    }
    
    public func save() -> Bool {
        guard validate() else {
            showAlert = true
            return false
        }
        let xrate: Int = Int(bombs) ?? 0
        basepoint <<= xrate
        
        if setting.spring {
            basepoint *= 2
        }
        
        var a: Int, b: Int, c: Int
        setting.aC = "white"
        setting.bC = "white"
        setting.cC = "white"
        switch setting.landlord {
        case 1:
            if setting.adouble {
                basepoint *= 2
            }
            b = (setting.bdouble) ? basepoint*2 : basepoint
            c = (setting.cdouble) ? basepoint*2 : basepoint
            a = b + c
            if setting.landlordResult {
                b *= -1
                c *= -1
                setting.aC = "green"
            } else {
                a *= -1
                setting.aC = "red"
            }
        case 2:
            if setting.bdouble {
                basepoint *= 2
            }
            a = (setting.adouble) ? basepoint*2 : basepoint
            c = (setting.cdouble) ? basepoint*2 : basepoint
            b = a + c
            if setting.landlordResult {
                a *= -1
                c *= -1
                setting.bC = "green"
            } else {
                b *= -1
                setting.bC = "red"
            }
        default:
            if setting.cdouble {
                basepoint *= 2
            }
            b = (setting.bdouble) ? basepoint*2 : basepoint
            a = (setting.adouble) ? basepoint*2 : basepoint
            c = b + a
            if setting.landlordResult {
                b *= -1
                a *= -1
                setting.cC = "green"
            } else {
                c *= -1
                setting.cC = "red"
            }
        }
        setting.bombs = Int(bombs) ?? 0
        setting.apoint = apoint.point
        setting.bpoint = bpoint.point
        setting.cpoint = cpoint.point
        setting.A = a
        setting.B = b
        setting.C = c
        return true
    }
}

// MARK: - Player Bid Card (for History Edit)

struct PlayerBidCardHistory: View {
    let name: String
    let isFirstBidder: Bool
    @Binding var selectedBid: String
    @Binding var isDoubled: Bool
    let options: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Player name row
            HStack {
                if isFirstBidder {
                    Image(systemName: "hand.point.right.fill")
                        .foregroundColor(.orange)
                }
                Text(name)
                    .font(.headline)
                
                Spacer()
                
                // Double toggle with label
                HStack(spacing: 6) {
                    Text("加倍")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Toggle("", isOn: $isDoubled)
                        .labelsHidden()
                }
            }
            
            // Bid picker (full width)
            Picker("叫分", selection: $selectedBid) {
                ForEach(options, id: \.self) { option in
                    Text(option)
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }
}

struct MatchPlayerStatRow: View {
    let playerName: String
    let position: Int
    let games: [GameRecord]
    let finalScore: Int
    @ObservedObject private var dataSingleton = DataSingleton.instance
    
    private var playerGames: [(GameRecord, Bool, Int)] {
        games.map { record in
            let isLandlord = record.landlord == position
            let score: Int
            switch position {
            case 1: score = record.scoreA
            case 2: score = record.scoreB
            default: score = record.scoreC
            }
            return (record, isLandlord, score)
        }
    }
    
    private var gamesWon: Int { playerGames.filter { $0.2 > 0 }.count }
    private var gamesLost: Int { playerGames.filter { $0.2 < 0 }.count }
    private var landlordCount: Int { playerGames.filter { $0.1 }.count }
    private var landlordWins: Int { playerGames.filter { $0.1 && $0.2 > 0 }.count }
    private var farmerCount: Int { playerGames.filter { !$0.1 }.count }
    private var farmerWins: Int { playerGames.filter { !$0.1 && $0.2 > 0 }.count }
    private var springCount: Int { playerGames.filter { $0.0.isSpring && $0.1 && $0.0.landlordResult }.count }
    private var doubledGames: Int {
        playerGames.filter { record, _, _ in
            switch position {
            case 1: return record.adouble
            case 2: return record.bdouble
            default: return record.cdouble
            }
        }.count
    }
    private var doubledWins: Int {
        playerGames.filter { record, _, score in
            let doubled: Bool
            switch position {
            case 1: doubled = record.adouble
            case 2: doubled = record.bdouble
            default: doubled = record.cdouble
            }
            return doubled && score > 0
        }.count
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score == 0 { return .primary }
        let isPositive = score > 0
        if dataSingleton.greenWin {
            return isPositive ? .green : .red
        } else {
            return isPositive ? .red : .green
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(playerName)
                    .font(.headline)
                Spacer()
                Text("\(finalScore)")
                    .font(.headline)
                    .foregroundColor(scoreColor(finalScore))
            }
            
            HStack(spacing: 16) {
                MiniStatItem(label: "胜率", value: games.count > 0 ? String(format: "%.0f%%", Double(gamesWon)/Double(games.count)*100) : "0%")
                MiniStatItem(label: "地主", value: "\(landlordWins)/\(landlordCount)")
                MiniStatItem(label: "农民", value: "\(farmerWins)/\(farmerCount)")
                MiniStatItem(label: "春天", value: "\(springCount)")
                if doubledGames > 0 {
                    MiniStatItem(label: "加倍胜率", value: String(format: "%.0f%%", Double(doubledWins)/Double(doubledGames)*100))
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct MiniStatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .fontWeight(.medium)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

struct FullMatchStatsView: View {
    let matchId: String
    
    @State private var match: MatchRecord?
    @State private var gameRecords: [GameRecord] = []
    @State private var isLoading = true
    @ObservedObject private var dataSingleton = DataSingleton.instance
    
    private func scoreColor(_ score: Int) -> Color {
        if score == 0 { return .primary }
        let isPositive = score > 0
        if dataSingleton.greenWin {
            return isPositive ? .green : .red
        } else {
            return isPositive ? .red : .green
        }
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载中...")
            } else if let match = match {
                List {
                    Section {
                        MatchSummarySection(match: match, games: gameRecords)
                    }
                    
                    if !gameRecords.isEmpty {
                        ForEach([
                            (match.playerAId, match.playerAName, 1),
                            (match.playerBId, match.playerBName, 2),
                            (match.playerCId, match.playerCName, 3)
                        ], id: \.0) { (playerId, playerName, position) in
                            Section {
                                PlayerMatchStatsSection(
                                    playerName: playerName,
                                    position: position,
                                    games: gameRecords,
                                    match: match
                                )
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                Text("无法加载对局数据")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("详细统计")
        .onAppear {
            loadMatchData()
        }
    }
    
    private func loadMatchData() {
        FirebaseService.shared.loadMatch(matchId: matchId) { result in
            switch result {
            case .success(let m):
                self.match = m
                FirebaseService.shared.loadGameRecords(forMatch: matchId) { result in
                    self.isLoading = false
                    if case .success(let records) = result {
                        self.gameRecords = records
                    }
                }
            case .failure:
                self.isLoading = false
            }
        }
    }
}

// MARK: - Score Line Chart

struct ScoreLineChart: View {
    let scores: [ScoreTriple]
    let playerNames: (String, String, String)
    var showExpandButton: Bool = true
    @State private var showFullscreen = false
    
    private struct ScorePoint: Identifiable {
        let id = UUID()
        let gameIndex: Int
        let player: String
        let score: Int
    }
    
    private var dataPoints: [ScorePoint] {
        var points: [ScorePoint] = []
        // Add starting point (0, 0, 0)
        points.append(ScorePoint(gameIndex: 0, player: playerNames.0, score: 0))
        points.append(ScorePoint(gameIndex: 0, player: playerNames.1, score: 0))
        points.append(ScorePoint(gameIndex: 0, player: playerNames.2, score: 0))
        
        for (idx, score) in scores.enumerated() {
            points.append(ScorePoint(gameIndex: idx + 1, player: playerNames.0, score: score.A))
            points.append(ScorePoint(gameIndex: idx + 1, player: playerNames.1, score: score.B))
            points.append(ScorePoint(gameIndex: idx + 1, player: playerNames.2, score: score.C))
        }
        return points
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            VStack(spacing: 8) {
                if showExpandButton {
                    HStack {
                        Spacer()
                        Button {
                            showFullscreen = true
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Chart {
                    ForEach(dataPoints) { point in
                        LineMark(
                            x: .value("局数", point.gameIndex),
                            y: .value("分数", point.score)
                        )
                        .foregroundStyle(by: .value("玩家", point.player))
                        
                        PointMark(
                            x: .value("局数", point.gameIndex),
                            y: .value("分数", point.score)
                        )
                        .foregroundStyle(by: .value("玩家", point.player))
                    }
                }
                .chartXAxisLabel("局数")
                .chartYAxisLabel("累计得分")
                .chartLegend(position: .bottom)
            }
            .fullScreenCover(isPresented: $showFullscreen) {
                FullscreenChartView(scores: scores, playerNames: playerNames)
            }
        } else {
            // Fallback for older iOS versions
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    ForEach([(playerNames.0, Color.blue), (playerNames.1, Color.green), (playerNames.2, Color.orange)], id: \.0) { name, color in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(color)
                                .frame(width: 8, height: 8)
                            Text(name)
                                .font(.caption)
                        }
                    }
                }
                
                if let lastScore = scores.last {
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(lastScore.A)")
                                .font(.headline)
                                .foregroundColor(.blue)
                            Text(playerNames.0)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        VStack {
                            Text("\(lastScore.B)")
                                .font(.headline)
                                .foregroundColor(.green)
                            Text(playerNames.1)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        VStack {
                            Text("\(lastScore.C)")
                                .font(.headline)
                                .foregroundColor(.orange)
                            Text(playerNames.2)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Fullscreen Chart View (Landscape)

@available(iOS 16.0, *)
struct FullscreenChartView: View {
    let scores: [ScoreTriple]
    let playerNames: (String, String, String)
    @Environment(\.dismiss) private var dismiss
    
    private struct ScorePoint: Identifiable {
        let id = UUID()
        let gameIndex: Int
        let player: String
        let score: Int
    }
    
    private var dataPoints: [ScorePoint] {
        var points: [ScorePoint] = []
        points.append(ScorePoint(gameIndex: 0, player: playerNames.0, score: 0))
        points.append(ScorePoint(gameIndex: 0, player: playerNames.1, score: 0))
        points.append(ScorePoint(gameIndex: 0, player: playerNames.2, score: 0))
        
        for (idx, score) in scores.enumerated() {
            points.append(ScorePoint(gameIndex: idx + 1, player: playerNames.0, score: score.A))
            points.append(ScorePoint(gameIndex: idx + 1, player: playerNames.1, score: score.B))
            points.append(ScorePoint(gameIndex: idx + 1, player: playerNames.2, score: score.C))
        }
        return points
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                
                VStack {
                    if isLandscape {
                        // Landscape: chart takes full width
                        chartView
                            .padding()
                    } else {
                        // Portrait: show hint to rotate
                        VStack(spacing: 20) {
                            Image(systemName: "rotate.right")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("旋转设备查看完整图表")
                                .foregroundColor(.secondary)
                            
                            chartView
                                .frame(height: 300)
                                .padding()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("得分走势")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var chartView: some View {
        Chart {
            ForEach(dataPoints) { point in
                LineMark(
                    x: .value("局数", point.gameIndex),
                    y: .value("分数", point.score)
                )
                .foregroundStyle(by: .value("玩家", point.player))
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                PointMark(
                    x: .value("局数", point.gameIndex),
                    y: .value("分数", point.score)
                )
                .foregroundStyle(by: .value("玩家", point.player))
                .symbolSize(50)
            }
        }
        .chartXAxisLabel("局数")
        .chartYAxisLabel("累计得分")
        .chartLegend(position: .bottom)
    }
}

#Preview {
    MatchHistoryView()
}
