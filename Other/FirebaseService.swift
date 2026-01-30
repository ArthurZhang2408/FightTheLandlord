//
//  FirebaseService.swift
//  FightTheLandlord
//
//  Created by Arthur Zhang on 2024-10-20.
//
//  Refactored: Integrated with local cache and offline sync system
//  Uses Local-First architecture - data is stored locally first, synced to cloud in background
//

import Foundation
import FirebaseFirestore
import Combine

class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    private let db = Firestore.firestore()

    // Use SyncManager as data source
    private let syncManager = SyncManager.shared
    private var cancellables = Set<AnyCancellable>()

    // Published data (synced from SyncManager)
    @Published var players: [Player] = []
    @Published var matches: [MatchRecord] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMatches: Bool = false

    // Sync status (exposed to UI)
    @Published var syncStatus: SyncStatus = .idle
    @Published var isOnline: Bool = true
    @Published var pendingOperationsCount: Int = 0
    @Published var gameRecordsSyncState: GameRecordsSyncState = .loading

    private init() {
        setupBindings()
        initializeSyncSystem()
    }

    // MARK: - Initialization

    /// Setup data bindings with SyncManager
    private func setupBindings() {
        // Bind players
        syncManager.$players
            .receive(on: DispatchQueue.main)
            .assign(to: &$players)

        // Bind matches
        syncManager.$matches
            .receive(on: DispatchQueue.main)
            .assign(to: &$matches)

        // Bind sync status
        syncManager.$syncStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$syncStatus)

        // Bind pending operations count
        syncManager.$pendingOperationsCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$pendingOperationsCount)

        // Bind network status
        NetworkMonitor.shared.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isOnline)

        // Bind loading status
        syncManager.$isSyncing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] syncing in
                self?.isLoading = syncing
                self?.isLoadingMatches = syncing
            }
            .store(in: &cancellables)

        // Bind game records sync state
        syncManager.$gameRecordsSyncState
            .receive(on: DispatchQueue.main)
            .assign(to: &$gameRecordsSyncState)
    }

    /// Initialize sync system
    private func initializeSyncSystem() {
        syncManager.initialize()
    }

    // MARK: - Players (maintaining original API)

    func loadPlayers() {
        // Now handled automatically by SyncManager
        // Kept for API compatibility
    }

    func addPlayer(name: String, color: PlayerColor? = nil, completion: @escaping (Result<Player, Error>) -> Void) {
        // Check for duplicate name
        if players.contains(where: { $0.name == name }) {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Player name already exists"])))
            return
        }

        var player = Player(name: name, playerColor: color ?? .blue)
        player.id = UUID().uuidString  // Generate local ID

        // Local-first: add to local first
        var updatedPlayers = players
        updatedPlayers.append(player)
        updatedPlayers.sort { $0.name < $1.name }

        // Update local cache
        LocalCacheManager.shared.cachePlayers(updatedPlayers)

        // If online, upload directly
        if NetworkMonitor.shared.isConnected {
            do {
                let ref = try db.collection("players").addDocument(from: player)
                var newPlayer = player
                newPlayer.id = ref.documentID
                completion(.success(newPlayer))
            } catch {
                // Upload failed, queue for retry
                PendingOperationQueue.shared.enqueueCreatePlayer(player)
                completion(.success(player))
            }
        } else {
            // Offline mode: queue for later
            PendingOperationQueue.shared.enqueueCreatePlayer(player)
            completion(.success(player))
        }
    }

    func updatePlayer(_ player: Player, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let playerId = player.id else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid player ID"])))
            return
        }

        // Update local cache
        var updatedPlayers = players
        if let index = updatedPlayers.firstIndex(where: { $0.id == playerId }) {
            updatedPlayers[index] = player
            LocalCacheManager.shared.cachePlayers(updatedPlayers)
        }

        // Sync to remote
        if NetworkMonitor.shared.isConnected {
            do {
                try db.collection("players").document(playerId).setData(from: player)
                completion(.success(()))
            } catch {
                PendingOperationQueue.shared.enqueueUpdatePlayer(player)
                completion(.success(()))
            }
        } else {
            PendingOperationQueue.shared.enqueueUpdatePlayer(player)
            completion(.success(()))
        }
    }

    func deletePlayer(id: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Delete from local cache
        var updatedPlayers = players
        updatedPlayers.removeAll { $0.id == id }
        LocalCacheManager.shared.cachePlayers(updatedPlayers)

        // Sync to remote
        if NetworkMonitor.shared.isConnected {
            db.collection("players").document(id).delete { error in
                if let error = error {
                    // Delete failed, queue for retry
                    PendingOperationQueue.shared.enqueueDeletePlayer(playerId: id)
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        } else {
            PendingOperationQueue.shared.enqueueDeletePlayer(playerId: id)
            completion(.success(()))
        }
    }

    // MARK: - Matches

    func loadAllMatches() {
        // Now handled automatically by SyncManager
        // Kept for API compatibility
    }

    func loadGameRecords(forMatch matchId: String, completion: @escaping (Result<[GameRecord], Error>) -> Void) {
        print("[FirebaseService] Loading game records for match: \(matchId)")

        syncManager.loadGameRecords(forMatchId: matchId) { records in
            DispatchQueue.main.async {
                print("[FirebaseService] Loaded \(records.count) game records for match \(matchId)")
                completion(.success(records))
            }
        }
    }

    func deleteMatch(matchId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        syncManager.deleteMatch(matchId: matchId)
        completion(.success(()))
    }

    func updateGameRecords(_ records: [GameRecord], matchId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Get current match and update
        if let match = matches.first(where: { $0.id == matchId }) {
            syncManager.updateMatch(match, gameRecords: records)
        }
        completion(.success(()))
    }

    func saveMatch(_ match: MatchRecord, completion: @escaping (Result<String, Error>) -> Void) {
        print("[FirebaseService] Saving match...")
        syncManager.saveMatch(match, gameRecords: []) { matchId in
            if let id = matchId {
                print("[FirebaseService] Match saved with ID: \(id)")
                completion(.success(id))
            } else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to save match"])))
            }
        }
    }

    /// Save match synchronously (returns matchId)
    /// Local-first: saves to local immediately, syncs to cloud in background
    func saveMatchSync(_ match: MatchRecord) throws -> String {
        print("[FirebaseService] Saving match synchronously...")
        let localId = match.id ?? UUID().uuidString

        var matchToSave = match
        matchToSave.id = localId

        // Save to local immediately
        var currentMatches = syncManager.matches
        currentMatches.insert(matchToSave, at: 0)
        LocalCacheManager.shared.cacheMatches(currentMatches)

        // Return local ID (don't wait for network)
        print("[FirebaseService] Match saved locally with ID: \(localId)")
        return localId
    }

    /// Save game records in background
    func saveGameRecordsBackground(_ records: [GameRecord], matchId: String) {
        guard !records.isEmpty else {
            print("[FirebaseService] No records to save")
            return
        }

        print("[FirebaseService] Saving \(records.count) game records in background...")

        // Save to local cache
        LocalCacheManager.shared.cacheGameRecords(records, forMatchId: matchId)

        // Get match and save through SyncManager
        if let match = syncManager.matches.first(where: { $0.id == matchId }) {
            syncManager.saveMatch(match, gameRecords: records, completion: nil)
        } else {
            // If match doesn't exist, create pending operation
            if NetworkMonitor.shared.isConnected {
                let batch = db.batch()
                for var record in records {
                    record.matchId = matchId
                    let ref = db.collection("gameRecords").document()
                    do {
                        try batch.setData(from: record, forDocument: ref)
                    } catch {
                        print("[FirebaseService] Error encoding game record: \(error)")
                        return
                    }
                }
                batch.commit { error in
                    if let error = error {
                        print("[FirebaseService] Batch commit failed: \(error)")
                    } else {
                        print("[FirebaseService] Batch commit succeeded")
                    }
                }
            }
        }
    }

    func loadMatch(matchId: String, completion: @escaping (Result<MatchRecord, Error>) -> Void) {
        // Look up in local first
        if let match = matches.first(where: { $0.id == matchId }) {
            completion(.success(match))
            return
        }

        // Not in local, load from Firebase
        if NetworkMonitor.shared.isConnected {
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
        } else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Offline and match not in cache"])))
        }
    }

    func updateMatch(_ match: MatchRecord, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let matchId = match.id else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Match ID is missing"])))
            return
        }

        // Get current game records
        let gameRecords = LocalCacheManager.shared.loadCachedGameRecords(forMatchId: matchId)
        syncManager.updateMatch(match, gameRecords: gameRecords)
        completion(.success(()))
    }

    func loadMatches(forPlayer playerId: String, completion: @escaping (Result<[MatchRecord], Error>) -> Void) {
        // Filter from local cache
        let playerMatches = matches.filter { match in
            match.playerAId == playerId ||
            match.playerBId == playerId ||
            match.playerCId == playerId
        }.sorted { $0.startedAt > $1.startedAt }

        completion(.success(playerMatches))
    }

    // MARK: - Game Records

    func saveGameRecords(_ records: [GameRecord], matchId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard !records.isEmpty else {
            print("[FirebaseService] No records to save")
            completion(.success(()))
            return
        }

        // Save to local
        LocalCacheManager.shared.cacheGameRecords(records, forMatchId: matchId)

        // Sync to remote
        if NetworkMonitor.shared.isConnected {
            let batch = db.batch()

            for var record in records {
                record.matchId = matchId
                let ref = db.collection("gameRecords").document()
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
        } else {
            // Offline mode: mark as pending
            if let match = matches.first(where: { $0.id == matchId }) {
                PendingOperationQueue.shared.enqueueCreateMatch(match, gameRecords: records)
            }
            completion(.success(()))
        }
    }

    func loadGameRecords(forPlayer playerId: String, completion: @escaping (Result<[GameRecord], Error>) -> Void) {
        // Load from local cache first (fast path)
        let allRecords = LocalCacheManager.shared.loadAllCachedGameRecords()
        let playerRecords = allRecords.filter { record in
            record.playerAId == playerId ||
            record.playerBId == playerId ||
            record.playerCId == playerId
        }.sorted { $0.playedAt > $1.playedAt }

        // If we have completed a full sync before, trust local cache immediately
        // This enables instant loading after app restart
        if LocalCacheManager.shared.hasCompletedFullSync && !playerRecords.isEmpty {
            print("[FirebaseService] hasCompletedFullSync=true, using \(playerRecords.count) cached game records for player (instant load)")
            completion(.success(playerRecords))
            return
        }

        // If we have cached records and game records are synced this session, use them
        if !playerRecords.isEmpty && syncManager.isGameRecordsSynced {
            print("[FirebaseService] Using \(playerRecords.count) cached game records for player")
            completion(.success(playerRecords))
            return
        }

        // If offline, return what we have
        guard NetworkMonitor.shared.isConnected else {
            print("[FirebaseService] Offline, returning \(playerRecords.count) cached records")
            completion(.success(playerRecords))
            return
        }

        // Online and cache might be incomplete - load from Firebase
        print("[FirebaseService] Loading game records from Firebase for player: \(playerId)")

        let group = DispatchGroup()
        var allRemoteRecords: [GameRecord] = []
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

                    allRemoteRecords.append(contentsOf: records)
                }
        }

        group.notify(queue: .main) {
            if let error = queryError {
                // If we have cached records, return them despite error
                if !playerRecords.isEmpty {
                    completion(.success(playerRecords))
                } else {
                    completion(.failure(error))
                }
            } else {
                let sortedRecords = allRemoteRecords.sorted { $0.playedAt > $1.playedAt }
                print("[FirebaseService] Loaded \(sortedRecords.count) game records from Firebase")
                completion(.success(sortedRecords))
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
            var cumulativeScore = 0

            // Calculate game statistics
            stats.totalGames = gameRecords.count

            for (gameIndex, record) in sortedGameRecords.enumerated() {
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
                if record.firstBidderIndex == position - 1 {
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
                cumulativeScore += score

                if score > stats.bestGameScore {
                    stats.bestGameScore = score
                    stats.bestGameScoreIndex = gameIndex
                }
                if score < stats.worstGameScore {
                    stats.worstGameScore = score
                    stats.worstGameScoreIndex = gameIndex
                }

                if cumulativeScore > stats.totalHighScore {
                    stats.totalHighScore = cumulativeScore
                    stats.totalHighGameIndex = gameIndex
                }
                if cumulativeScore < stats.totalLowScore {
                    stats.totalLowScore = cumulativeScore
                    stats.totalLowGameIndex = gameIndex
                }
            }

            stats.currentWinStreak = currentWinStreak
            stats.currentLossStreak = currentLossStreak

            // Match statistics
            let sortedMatches = matchRecords.sorted { $0.startedAt < $1.startedAt }
            var currentMatchWinStreak = 0
            var currentMatchLossStreak = 0

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

            stats.currentMatchWinStreak = currentMatchWinStreak
            stats.currentMatchLossStreak = currentMatchLossStreak

            completion(.success(stats))
        }
    }

    // MARK: - Sync Control

    /// Force sync manually
    func forceSync() {
        syncManager.forceSync()
    }

    /// Reset and re-sync all data
    func resetAndSync() {
        syncManager.resetAndSync()
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
