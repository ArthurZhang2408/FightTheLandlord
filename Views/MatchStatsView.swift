//
//  MatchStatsView.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-20.
//

import SwiftUI

/// Statistics view for a single match (shown after ending a match or from history)
struct MatchStatsView: View {
    let matchId: String
    @Binding var isPresented: Bool
    
    @State private var match: MatchRecord?
    @State private var gameRecords: [GameRecord] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView()
                } else if let match = match {
                    ScrollView {
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
                    }
                } else {
                    Text("无法加载对局数据")
                        .foregroundColor(.gray50)
                }
            }
            .navigationTitle("对局统计")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                loadMatchData()
            }
        }
    }
    
    private func loadMatchData() {
        // Load match record
        FirebaseService.shared.loadMatch(matchId: matchId) { result in
            switch result {
            case .success(let m):
                self.match = m
                // Load game records
                FirebaseService.shared.loadGameRecords(forMatch: matchId) { result in
                    self.isLoading = false
                    switch result {
                    case .success(let records):
                        self.gameRecords = records
                    case .failure(let error):
                        print("Error loading game records: \(error.localizedDescription)")
                    }
                }
            case .failure(let error):
                self.isLoading = false
                print("Error loading match: \(error.localizedDescription)")
            }
        }
    }
}

struct MatchSummarySection: View {
    let match: MatchRecord
    let games: [GameRecord]
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("对局总结")
                .font(.headline)
            
            Text(dateFormatter.string(from: match.startedAt))
                .font(.subheadline)
                .foregroundColor(.gray40)
            
            HStack(spacing: 30) {
                VStack {
                    Text(match.playerAName)
                        .font(.subheadline)
                    Text("\(match.finalScoreA)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(match.finalScoreA > 0 ? .green : (match.finalScoreA < 0 ? .red : .white))
                }
                VStack {
                    Text(match.playerBName)
                        .font(.subheadline)
                    Text("\(match.finalScoreB)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(match.finalScoreB > 0 ? .green : (match.finalScoreB < 0 ? .red : .white))
                }
                VStack {
                    Text(match.playerCName)
                        .font(.subheadline)
                    Text("\(match.finalScoreC)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(match.finalScoreC > 0 ? .green : (match.finalScoreC < 0 ? .red : .white))
                }
            }
            
            HStack {
                StatBadge(label: "总局数", value: "\(match.totalGames)")
                StatBadge(label: "春天", value: "\(games.filter { $0.isSpring }.count)")
            }
        }
        .padding()
        .background(Color.gray80.opacity(0.3))
        .cornerRadius(12)
    }
}

struct PlayerMatchStatsSection: View {
    let playerName: String
    let position: Int
    let games: [GameRecord]
    let match: MatchRecord
    
    private var playerGames: [(GameRecord, Bool, Int)] {
        // Returns (record, isLandlord, score)
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
    
    private var gamesWon: Int {
        playerGames.filter { $0.2 > 0 }.count
    }
    
    private var gamesLost: Int {
        playerGames.filter { $0.2 < 0 }.count
    }
    
    private var gamesAsLandlord: Int {
        playerGames.filter { $0.1 }.count
    }
    
    private var gamesAsFarmer: Int {
        playerGames.filter { !$0.1 }.count
    }
    
    private var landlordWins: Int {
        playerGames.filter { $0.1 && $0.2 > 0 }.count
    }
    
    private var farmerWins: Int {
        playerGames.filter { !$0.1 && $0.2 > 0 }.count
    }
    
    private var springCount: Int {
        // Spring as landlord (landlord wins with spring)
        playerGames.filter { $0.0.isSpring && $0.1 && $0.0.landlordResult }.count
    }
    
    private var springAgainstCount: Int {
        // Spring against as farmer (landlord wins with spring, player is farmer)
        playerGames.filter { $0.0.isSpring && !$0.1 && $0.0.landlordResult }.count
    }
    
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
    
    private var totalScore: Int {
        switch position {
        case 1: return match.finalScoreA
        case 2: return match.finalScoreB
        default: return match.finalScoreC
        }
    }
    
    private var bestGame: Int {
        playerGames.map { $0.2 }.max() ?? 0
    }
    
    private var worstGame: Int {
        playerGames.map { $0.2 }.min() ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(playerName)
                .font(.headline)
                .foregroundColor(.primary500)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatBadge(label: "总局数", value: "\(games.count)")
                StatBadge(label: "赢", value: "\(gamesWon)")
                StatBadge(label: "输", value: "\(gamesLost)")
                
                StatBadge(label: "地主", value: "\(gamesAsLandlord)")
                StatBadge(label: "地主胜", value: "\(landlordWins)")
                StatBadge(label: "地主率", value: gamesAsLandlord > 0 ? String(format: "%.0f%%", Double(landlordWins)/Double(gamesAsLandlord)*100) : "0%")
                
                StatBadge(label: "农民", value: "\(gamesAsFarmer)")
                StatBadge(label: "农民胜", value: "\(farmerWins)")
                StatBadge(label: "农民率", value: gamesAsFarmer > 0 ? String(format: "%.0f%%", Double(farmerWins)/Double(gamesAsFarmer)*100) : "0%")
                
                StatBadge(label: "春天", value: "\(springCount)")
                StatBadge(label: "被春", value: "\(springAgainstCount)")
                StatBadge(label: "加倍", value: "\(doubledGames)")
                
                StatBadge(label: "加倍胜率", value: doubledGames > 0 ? String(format: "%.0f%%", Double(doubledWins)/Double(doubledGames)*100) : "0%")
                StatBadge(label: "最高分", value: "\(bestGame)")
                StatBadge(label: "最低分", value: "\(worstGame)")
            }
        }
        .padding()
        .background(Color.gray80.opacity(0.2))
        .cornerRadius(12)
    }
}

struct StatBadge: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption)
                .foregroundColor(.gray50)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray70.opacity(0.3))
        .cornerRadius(8)
    }
}

#Preview {
    MatchStatsView(matchId: "test", isPresented: .constant(true))
}
