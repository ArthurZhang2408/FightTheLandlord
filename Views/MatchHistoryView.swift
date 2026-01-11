//
//  MatchHistoryView.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-20.
//

import SwiftUI

struct MatchHistoryView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var matchToDelete: MatchRecord?
    @State private var showingDeleteConfirm = false
    
    var body: some View {
        NavigationView {
            VStack {
                if firebaseService.isLoadingMatches {
                    ProgressView()
                } else if firebaseService.matches.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 50))
                            .foregroundColor(.gray50)
                        Text("暂无历史对局")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("结束一场对局后会在这里显示")
                            .font(.subheadline)
                            .foregroundColor(.gray50)
                    }
                    .padding(.top, 100)
                } else {
                    List {
                        ForEach(firebaseService.matches) { match in
                            NavigationLink(destination: MatchDetailView(match: match)) {
                                MatchRowView(match: match)
                            }
                            .swipeActions(allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    matchToDelete = match
                                    showingDeleteConfirm = true
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("历史对局")
            .confirmationDialog("确定删除该对局吗？", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    if let match = matchToDelete, let id = match.id {
                        firebaseService.deleteMatch(matchId: id) { _ in }
                    }
                }
                Button("取消", role: .cancel) {}
            }
        }
    }
}

struct MatchRowView: View {
    let match: MatchRecord
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dateFormatter.string(from: match.startedAt))
                    .font(.subheadline)
                    .foregroundColor(.gray40)
                Spacer()
                Text("\(match.totalGames)局")
                    .font(.caption)
                    .foregroundColor(.gray50)
            }
            
            HStack(spacing: 16) {
                PlayerScoreLabel(name: match.playerAName, score: match.finalScoreA)
                PlayerScoreLabel(name: match.playerBName, score: match.finalScoreB)
                PlayerScoreLabel(name: match.playerCName, score: match.finalScoreC)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PlayerScoreLabel: View {
    let name: String
    let score: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.caption)
                .foregroundColor(.gray30)
                .lineLimit(1)
            Text("\(score)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(score > 0 ? .green : (score < 0 ? .red : .white))
        }
    }
}

struct MatchDetailView: View {
    let match: MatchRecord
    @State private var gameRecords: [GameRecord] = []
    @State private var isLoading = true
    @State private var showingEditSheet = false
    @State private var editingGameIndex: Int = -1
    @State private var showingDeleteConfirm = false
    @State private var deleteIdx: Int = -1
    
    // For editing - convert GameRecords to GameSettings
    @State private var games: [GameSetting] = []
    @State private var scores: [ScoreTriple] = []
    @State private var aRe: Int = 0
    @State private var bRe: Int = 0
    @State private var cRe: Int = 0
    
    // Display scores: use calculated scores if available, otherwise fall back to match's stored scores
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
    
    var width: CGFloat = 90
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else {
                // All content in a single List for proper scrolling
                List {
                    // Header section
                    Section {
                        VStack(spacing: 8) {
                            Text(dateFormatter.string(from: match.startedAt))
                                .font(.subheadline)
                                .foregroundColor(.gray40)
                            
                            HStack(spacing: 20) {
                                VStack {
                                    Text(match.playerAName)
                                        .font(.headline)
                                    Text("\(displayScoreA)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(displayScoreA > 0 ? .green : (displayScoreA < 0 ? .red : .white))
                                }
                                VStack {
                                    Text(match.playerBName)
                                        .font(.headline)
                                    Text("\(displayScoreB)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(displayScoreB > 0 ? .green : (displayScoreB < 0 ? .red : .white))
                                }
                                VStack {
                                    Text(match.playerCName)
                                        .font(.headline)
                                    Text("\(displayScoreC)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(displayScoreC > 0 ? .green : (displayScoreC < 0 ? .red : .white))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    
                    // Games section - same style as ListingView
                    Section(header: Text("每局详情 (\(games.count)局)")) {
                        if games.isEmpty {
                            Text("暂无详细记录")
                                .foregroundColor(.gray50)
                        } else {
                            ForEach(games.indices, id: \.self) { idx in
                                HStack {
                                    Text("\(idx+1): ")
                                        .frame(width: width)
                                    Text(games[idx].A.description)
                                        .frame(width: width)
                                        .foregroundColor(games[idx].aC.color)
                                    Text(games[idx].B.description)
                                        .frame(width: width)
                                        .foregroundColor(games[idx].bC.color)
                                    Text(games[idx].C.description)
                                        .frame(width: width)
                                        .foregroundColor(games[idx].cC.color)
                                }
                                .frame(width: width * 4)
                                .swipeActions(allowsFullSwipe: false) {
                                    Button {
                                        editingGameIndex = idx
                                        showingEditSheet = true
                                    } label: {
                                        Label("修改", systemImage: "pencil")
                                    }
                                    .tint(.indigo)
                                }
                            }
                        }
                    }
                    
                    // Statistics section for each player
                    if !gameRecords.isEmpty {
                        Section(header: Text("玩家统计")) {
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
                        }
                    }
                }
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
        .sheet(isPresented: $showingEditSheet) {
            HistoryEditView(
                showingEditSheet: $showingEditSheet,
                games: $games,
                scores: $scores,
                aRe: $aRe,
                bRe: $bRe,
                cRe: $cRe,
                editingIndex: editingGameIndex,
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
                // Convert GameRecords to GameSettings
                games = records.map { record in
                    var setting = GameSetting()
                    setting.bombs = record.bombs
                    setting.apoint = record.apoint
                    setting.bpoint = record.bpoint
                    setting.cpoint = record.cpoint
                    setting.adouble = record.adouble
                    setting.bdouble = record.bdouble
                    setting.cdouble = record.cdouble
                    setting.spring = record.spring
                    setting.landlordResult = record.landlordResult
                    setting.landlord = record.landlord
                    setting.A = record.scoreA
                    setting.B = record.scoreB
                    setting.C = record.scoreC
                    // Set colors based on landlord and result
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

struct HistoryEditView: View {
    @Binding var showingEditSheet: Bool
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
    
    init(showingEditSheet: Binding<Bool>, games: Binding<[GameSetting]>, scores: Binding<[ScoreTriple]>, 
         aRe: Binding<Int>, bRe: Binding<Int>, cRe: Binding<Int>,
         editingIndex: Int, match: MatchRecord, playerAName: String, playerBName: String, playerCName: String) {
        self._showingEditSheet = showingEditSheet
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
        self._viewModel = StateObject(wrappedValue: HistoryEditViewModel(game: games.wrappedValue[editingIndex]))
    }
    
    var height: CGFloat = 40
    var width: CGFloat = .screenWidth/3.5
    var leadingPad: CGFloat = 13
    
    var body: some View {
        NavigationView {
            VStack {
                VStack(alignment: .center) {
                    HStack {
                        VStack(alignment: .leading, spacing: 20) {
                            VStack {
                                Text(playerAName)
                                    .foregroundStyle(.white)
                            }
                            .frame(height: height)
                            .padding(.leading, leadingPad)
                            VStack {
                                Picker(selection: $viewModel.apoint) {
                                    ForEach(viewModel.points, id: \.self) { curr in
                                        Text(curr)
                                    }
                                } label: {}
                            }
                            .frame(height: height)
                            VStack {
                                Toggle(isOn: $viewModel.setting.adouble) {
                                    Text("加倍")
                                }
                                .toggleStyle(.button)
                            }
                            .frame(height: height)
                        }
                        .frame(width: width)
                        VStack(alignment: .leading, spacing: 20) {
                            VStack {
                                Text(playerBName)
                                    .foregroundStyle(.white)
                            }
                            .frame(height: height)
                            .padding(.leading, leadingPad)
                            VStack {
                                Picker(selection: $viewModel.bpoint) {
                                    ForEach(viewModel.points, id: \.self) { curr in
                                        Text(curr)
                                    }
                                } label: {}
                            }
                            .frame(height: height)
                            VStack {
                                Toggle(isOn: $viewModel.setting.bdouble) {
                                    Text("加倍")
                                }
                                .toggleStyle(.button)
                            }
                            .frame(height: height)
                        }
                        .frame(width: width)
                        VStack(alignment: .leading, spacing: 20) {
                            VStack {
                                Text(playerCName)
                                    .foregroundStyle(.white)
                            }
                            .frame(height: height)
                            .padding(.leading, leadingPad)
                            VStack {
                                Picker(selection: $viewModel.cpoint) {
                                    ForEach(viewModel.points, id: \.self) { curr in
                                        Text(curr)
                                    }
                                } label: {}
                            }
                            .frame(height: height)
                            VStack {
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
                        VStack(spacing: 40) {
                            VStack {
                                RoundTextField(title: "炸弹", text: $viewModel.bombs, keyboardType: .decimal, height: 35)
                            }
                            .frame(height: height)
                            VStack {
                                Toggle(isOn: $viewModel.setting.spring) {
                                    Text("春天")
                                }
                                .toggleStyle(.button)
                            }
                            .frame(height: height)
                            VStack {
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
                PrimaryButton(title: "保存修改") {
                    if viewModel.save() {
                        // Update local state
                        games[editingIndex] = viewModel.setting
                        updateLocalScores()
                        // Save to Firebase
                        saveToFirebase()
                        showingEditSheet = false
                    }
                }
            }
            .navigationTitle("修改第\(editingIndex + 1)局")
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text("错误"),
                    message: Text(viewModel.errorMessage)
                )
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
        
        // Create updated match record
        var updatedMatch = match
        updatedMatch.finalize(games: games, scores: scores)
        
        // Update match
        FirebaseService.shared.updateMatch(updatedMatch) { result in
            if case .failure(let error) = result {
                print("Error updating match: \(error.localizedDescription)")
            }
        }
        
        // Create game records
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
        
        // Update game records
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
        
        // Apply spring multiplier (doubles the score)
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

// MARK: - Match Player Stats Row

struct MatchPlayerStatRow: View {
    let playerName: String
    let position: Int
    let games: [GameRecord]
    let finalScore: Int
    
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
    private var springCount: Int { playerGames.filter { $0.0.spring && $0.1 && $0.0.landlordResult }.count }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(playerName)
                    .font(.headline)
                    .foregroundColor(.primary500)
                Spacer()
                Text("\(finalScore)")
                    .font(.headline)
                    .foregroundColor(finalScore > 0 ? .green : (finalScore < 0 ? .red : .white))
            }
            
            HStack(spacing: 16) {
                StatItem(label: "胜率", value: games.count > 0 ? String(format: "%.0f%%", Double(gamesWon)/Double(games.count)*100) : "0%")
                StatItem(label: "地主", value: "\(landlordWins)/\(landlordCount)")
                StatItem(label: "农民", value: "\(farmerWins)/\(farmerCount)")
                StatItem(label: "春天", value: "\(springCount)")
                if doubledGames > 0 {
                    StatItem(label: "加倍胜率", value: String(format: "%.0f%%", Double(doubledWins)/Double(doubledGames)*100))
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .fontWeight(.medium)
            Text(label)
                .foregroundColor(.gray50)
        }
    }
}

// MARK: - Full Match Stats View

struct FullMatchStatsView: View {
    let matchId: String
    
    @State private var match: MatchRecord?
    @State private var gameRecords: [GameRecord] = []
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding(.top, 100)
            } else if let match = match {
                VStack(spacing: 20) {
                    // Match summary
                    MatchSummarySection(match: match, games: gameRecords)
                    
                    // Per-player statistics for this match
                    if !gameRecords.isEmpty {
                        ForEach([
                            (match.playerAId, match.playerAName, 1),
                            (match.playerBId, match.playerBName, 2),
                            (match.playerCId, match.playerCName, 3)
                        ], id: \.0) { (playerId, playerName, position) in
                            PlayerMatchStatsSection(
                                playerName: playerName,
                                position: position,
                                games: gameRecords,
                                match: match
                            )
                        }
                    }
                }
                .padding()
            } else {
                Text("无法加载对局数据")
                    .foregroundColor(.gray50)
                    .padding(.top, 100)
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

#Preview {
    MatchHistoryView()
}
