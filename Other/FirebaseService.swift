//
//  FirebaseService.swift
//  FightTheLandloard
//
//  Created by Arthur Zhang on 2024-10-20.
//

import Foundation
import FirebaseFirestore

class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    private let db = Firestore.firestore()
    
    @Published var players: [Player] = []
    @Published var matches: [MatchRecord] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMatches: Bool = false
    
    private init() {
        loadPlayers()
        loadAllMatches()
    }
    
    // MARK: - Players
    
    func loadPlayers() {
        isLoading = true
        db.collection("players").order(by: "name").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                print("Error loading players: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            self.players = documents.compactMap { doc in
                try? doc.data(as: Player.self)
            }
        }
    }
    
    func addPlayer(name: String, completion: @escaping (Result<Player, Error>) -> Void) {
        // Check for duplicate names
        if players.contains(where: { $0.name == name }) {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "玩家名称已存在"])))
            return
        }
        
        let player = Player(name: name)
        
        do {
            let ref = try db.collection("players").addDocument(from: player)
            var newPlayer = player
            newPlayer.id = ref.documentID
            completion(.success(newPlayer))
        } catch {
            completion(.failure(error))
        }
    }
    
    func deletePlayer(id: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("players").document(id).delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Matches (对局)
    
    func loadAllMatches() {
        isLoadingMatches = true
        db.collection("matches").order(by: "startedAt", descending: true).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoadingMatches = false
            
            if let error = error {
                print("Error loading matches: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            self.matches = documents.compactMap { doc in
                try? doc.data(as: MatchRecord.self)
            }
        }
    }
    
    func loadGameRecords(forMatch matchId: String, completion: @escaping (Result<[GameRecord], Error>) -> Void) {
        db.collection("gameRecords")
            .whereField("matchId", isEqualTo: matchId)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error loading game records: \(error.localizedDescription)")
                        completion(.failure(error))
                        return
                    }
                    
                    var records = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: GameRecord.self)
                    } ?? []
                    
                    // Sort by gameIndex locally to avoid needing a composite index
                    records.sort { $0.gameIndex < $1.gameIndex }
                    
                    print("Loaded \(records.count) game records for match \(matchId)")
                    completion(.success(records))
                }
            }
    }
    
    func deleteMatch(matchId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // First delete all game records for this match
        db.collection("gameRecords")
            .whereField("matchId", isEqualTo: matchId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let batch = self.db.batch()
                
                // Delete all game records
                snapshot?.documents.forEach { doc in
                    batch.deleteDocument(doc.reference)
                }
                
                // Delete the match itself
                batch.deleteDocument(self.db.collection("matches").document(matchId))
                
                batch.commit { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
    }
    
    func updateGameRecords(_ records: [GameRecord], matchId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // First delete all existing game records for this match
        db.collection("gameRecords")
            .whereField("matchId", isEqualTo: matchId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let batch = self.db.batch()
                
                // Delete old records
                snapshot?.documents.forEach { doc in
                    batch.deleteDocument(doc.reference)
                }
                
                // Add new records
                for record in records {
                    let ref = self.db.collection("gameRecords").document()
                    do {
                        try batch.setData(from: record, forDocument: ref)
                    } catch {
                        completion(.failure(error))
                        return
                    }
                }
                
                batch.commit { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
    }
    
    func saveMatch(_ match: MatchRecord, completion: @escaping (Result<String, Error>) -> Void) {
        do {
            let ref = try db.collection("matches").addDocument(from: match)
            completion(.success(ref.documentID))
        } catch {
            completion(.failure(error))
        }
    }
    
    func loadMatch(matchId: String, completion: @escaping (Result<MatchRecord, Error>) -> Void) {
        db.collection("matches").document(matchId).getDocument { snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Match not found"])))
                    return
                }
                
                do {
                    let match = try snapshot.data(as: MatchRecord.self)
                    completion(.success(match))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func updateMatch(_ match: MatchRecord, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let matchId = match.id else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Match ID is missing"])))
            return
        }
        
        do {
            try db.collection("matches").document(matchId).setData(from: match)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    func loadMatches(forPlayer playerId: String, completion: @escaping (Result<[MatchRecord], Error>) -> Void) {
        // Query matches where this player participated (as A, B, or C)
        let group = DispatchGroup()
        var allMatches: [MatchRecord] = []
        var queryError: Error?
        
        for field in ["playerAId", "playerBId", "playerCId"] {
            group.enter()
            db.collection("matches")
                .whereField(field, isEqualTo: playerId)
                .getDocuments { snapshot, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        queryError = error
                        return
                    }
                    
                    let matches = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: MatchRecord.self)
                    } ?? []
                    
                    allMatches.append(contentsOf: matches)
                }
        }
        
        group.notify(queue: .main) {
            if let error = queryError {
                completion(.failure(error))
            } else {
                // Remove duplicates (in case player played in same match as different position)
                var seenIds = Set<String>()
                let uniqueMatches = allMatches.filter { match in
                    guard let id = match.id, !seenIds.contains(id) else { return false }
                    seenIds.insert(id)
                    return true
                }
                completion(.success(uniqueMatches.sorted { ($0.startedAt) > ($1.startedAt) }))
            }
        }
    }
    
    // MARK: - Game Records
    
    func saveGameRecords(_ records: [GameRecord], matchId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let batch = db.batch()
        
        for var record in records {
            var recordWithMatchId = record
            recordWithMatchId.matchId = matchId
            
            let ref = db.collection("gameRecords").document()
            do {
                try batch.setData(from: recordWithMatchId, forDocument: ref)
            } catch {
                completion(.failure(error))
                return
            }
        }
        
        batch.commit { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func loadGameRecords(forPlayer playerId: String, completion: @escaping (Result<[GameRecord], Error>) -> Void) {
        let group = DispatchGroup()
        var allRecords: [GameRecord] = []
        var queryError: Error?
        
        for field in ["playerAId", "playerBId", "playerCId"] {
            group.enter()
            db.collection("gameRecords")
                .whereField(field, isEqualTo: playerId)
                .getDocuments { snapshot, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        queryError = error
                        return
                    }
                    
                    let records = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: GameRecord.self)
                    } ?? []
                    
                    allRecords.append(contentsOf: records)
                }
        }
        
        group.notify(queue: .main) {
            if let error = queryError {
                completion(.failure(error))
            } else {
                completion(.success(allRecords.sorted { $0.playedAt > $1.playedAt }))
            }
        }
    }
    
    // MARK: - Statistics Calculation
    
    func calculateStatistics(forPlayer playerId: String, completion: @escaping (Result<PlayerStatistics, Error>) -> Void) {
        guard let player = players.first(where: { $0.id == playerId }) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Player not found"])))
            return
        }
        
        var stats = PlayerStatistics(playerId: playerId, playerName: player.name)
        
        let group = DispatchGroup()
        var gameRecords: [GameRecord] = []
        var matchRecords: [MatchRecord] = []
        var loadError: Error?
        
        // Load game records
        group.enter()
        loadGameRecords(forPlayer: playerId) { result in
            defer { group.leave() }
            switch result {
            case .success(let records):
                gameRecords = records
            case .failure(let error):
                loadError = error
            }
        }
        
        // Load match records
        group.enter()
        loadMatches(forPlayer: playerId) { result in
            defer { group.leave() }
            switch result {
            case .success(let matches):
                matchRecords = matches
            case .failure(let error):
                loadError = error
            }
        }
        
        group.notify(queue: .main) {
            if let error = loadError {
                completion(.failure(error))
                return
            }
            
            // Sort game records by date for streak calculation
            let sortedGameRecords = gameRecords.sorted { $0.playedAt < $1.playedAt }
            var currentWinStreak = 0
            var currentLossStreak = 0
            
            // Calculate game statistics
            stats.totalGames = gameRecords.count
            
            for record in sortedGameRecords {
                let position = self.getPlayerPosition(playerId: playerId, record: record)
                let isLandlord = record.landlord == position
                let score = self.getPlayerScore(position: position, record: record)
                let won = score > 0
                let doubled = self.getPlayerDoubled(position: position, record: record)
                
                // Win/Loss count and streaks
                if won {
                    stats.gamesWon += 1
                    currentWinStreak += 1
                    currentLossStreak = 0
                    stats.maxWinStreak = max(stats.maxWinStreak, currentWinStreak)
                } else if score < 0 {
                    stats.gamesLost += 1
                    currentLossStreak += 1
                    currentWinStreak = 0
                    stats.maxLossStreak = max(stats.maxLossStreak, currentLossStreak)
                }
                
                // Role breakdown
                if isLandlord {
                    stats.gamesAsLandlord += 1
                    if won {
                        stats.landlordWins += 1
                    } else {
                        stats.landlordLosses += 1
                    }
                    // Spring count (landlord wins with spring)
                    if record.isSpring && record.landlordResult {
                        stats.springCount += 1
                    }
                } else {
                    stats.gamesAsFarmer += 1
                    if won {
                        stats.farmerWins += 1
                    } else {
                        stats.farmerLosses += 1
                    }
                    // Spring against count (landlord wins with spring, player is farmer)
                    if record.isSpring && record.landlordResult {
                        stats.springAgainstCount += 1
                    }
                }
                
                // Doubled game statistics
                if doubled {
                    stats.doubledGames += 1
                    if won {
                        stats.doubledWins += 1
                    } else {
                        stats.doubledLosses += 1
                    }
                }
                
                // Bid distribution when first bidder
                // firstBidder uses 0-indexed (0=A, 1=B, 2=C), position uses 1-indexed (1=A, 2=B, 3=C)
                if record.firstBidder == position - 1 {
                    stats.firstBidderGames += 1
                    let bid = self.getPlayerBid(position: position, record: record)
                    switch bid {
                    case 0: stats.bidZeroCount += 1
                    case 1: stats.bidOneCount += 1
                    case 2: stats.bidTwoCount += 1
                    case 3: stats.bidThreeCount += 1
                    default: break
                    }
                }
                
                // Score stats
                stats.totalScore += score
                stats.bestGameScore = max(stats.bestGameScore, score)
                stats.worstGameScore = min(stats.worstGameScore, score)
            }
            
            // Store current streaks
            stats.currentWinStreak = currentWinStreak
            stats.currentLossStreak = currentLossStreak
            
            // Sort matches by date for streak calculation
            let sortedMatches = matchRecords.sorted { $0.startedAt < $1.startedAt }
            var currentMatchWinStreak = 0
            var currentMatchLossStreak = 0
            
            // Calculate match statistics
            stats.totalMatches = matchRecords.count
            
            for match in sortedMatches {
                let position = self.getPlayerPositionInMatch(playerId: playerId, match: match)
                let finalScore = self.getPlayerFinalScore(position: position, match: match)
                let maxSnapshot = self.getPlayerMaxSnapshot(position: position, match: match)
                let minSnapshot = self.getPlayerMinSnapshot(position: position, match: match)
                
                if finalScore > 0 {
                    stats.matchesWon += 1
                    currentMatchWinStreak += 1
                    currentMatchLossStreak = 0
                    stats.maxMatchWinStreak = max(stats.maxMatchWinStreak, currentMatchWinStreak)
                } else if finalScore < 0 {
                    stats.matchesLost += 1
                    currentMatchLossStreak += 1
                    currentMatchWinStreak = 0
                    stats.maxMatchLossStreak = max(stats.maxMatchLossStreak, currentMatchLossStreak)
                } else {
                    stats.matchesTied += 1
                }
                
                stats.bestMatchScore = max(stats.bestMatchScore, finalScore)
                stats.worstMatchScore = min(stats.worstMatchScore, finalScore)
                stats.bestSnapshot = max(stats.bestSnapshot, maxSnapshot)
                stats.worstSnapshot = min(stats.worstSnapshot, minSnapshot)
            }
            
            // Store current match streaks
            stats.currentMatchWinStreak = currentMatchWinStreak
            stats.currentMatchLossStreak = currentMatchLossStreak
            
            completion(.success(stats))
        }
    }
    
    // MARK: - Helper Methods
    
    private func getPlayerPosition(playerId: String, record: GameRecord) -> Int {
        if record.playerAId == playerId { return 1 }
        if record.playerBId == playerId { return 2 }
        return 3
    }
    
    private func getPlayerScore(position: Int, record: GameRecord) -> Int {
        switch position {
        case 1: return record.scoreA
        case 2: return record.scoreB
        default: return record.scoreC
        }
    }
    
    private func getPlayerDoubled(position: Int, record: GameRecord) -> Bool {
        switch position {
        case 1: return record.adouble
        case 2: return record.bdouble
        default: return record.cdouble
        }
    }
    
    private func getPlayerBid(position: Int, record: GameRecord) -> Int {
        switch position {
        case 1: return record.apoint
        case 2: return record.bpoint
        default: return record.cpoint
        }
    }
    
    private func getPlayerPositionInMatch(playerId: String, match: MatchRecord) -> Int {
        if match.playerAId == playerId { return 1 }
        if match.playerBId == playerId { return 2 }
        return 3
    }
    
    private func getPlayerFinalScore(position: Int, match: MatchRecord) -> Int {
        switch position {
        case 1: return match.finalScoreA
        case 2: return match.finalScoreB
        default: return match.finalScoreC
        }
    }
    
    private func getPlayerMaxSnapshot(position: Int, match: MatchRecord) -> Int {
        switch position {
        case 1: return match.maxSnapshotA
        case 2: return match.maxSnapshotB
        default: return match.maxSnapshotC
        }
    }
    
    private func getPlayerMinSnapshot(position: Int, match: MatchRecord) -> Int {
        switch position {
        case 1: return match.minSnapshotA
        case 2: return match.minSnapshotB
        default: return match.minSnapshotC
        }
    }
}
