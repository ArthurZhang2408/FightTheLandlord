//
//  SyncManager.swift
//  FightTheLandlord
//
//  Coordinates the local cache and Firestore.
//    1. Serve cached data immediately on launch.
//    2. Keep Firestore listeners for players and matches; preload all game records.
//    3. Apply every mutation locally first, then upload (or queue when offline).
//

import Foundation
import Combine
import FirebaseFirestore

enum SyncStatus: Equatable {
    case idle
    case syncing
    case offline
    case error(String)
}

enum GameRecordsSyncState: Equatable {
    case loading
    case localOnly
    case syncing
    case synced
    case offline
    case error(String)
}

final class SyncManager: ObservableObject {
    static let shared = SyncManager()

    private let localCache = LocalCacheManager.shared
    private let pendingQueue = PendingOperationQueue.shared
    private let networkMonitor = NetworkMonitor.shared

    // MARK: Published state (always mutated on the main thread)

    @Published private(set) var syncStatus: SyncStatus = .idle
    @Published private(set) var lastSyncTime: Date?
    @Published private(set) var pendingOperationsCount: Int = 0
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var gameRecordsSyncState: GameRecordsSyncState = .loading
    /// True once cached data was loaded or the first remote snapshot arrived.
    @Published private(set) var hasLoadedInitialData: Bool = false

    @Published private(set) var players: [Player] = []
    @Published private(set) var matches: [MatchRecord] = []
    @Published private(set) var gameRecords: [GameRecord] = []

    // MARK: Private

    private var cancellables = Set<AnyCancellable>()
    private let db = Firestore.firestore()
    private var isInitialized = false
    private var isGameRecordsSynced = false
    private let syncQueue = DispatchQueue(label: "SyncManager.syncQueue")
    private var isSyncingOperations = false
    private var playersListener: ListenerRegistration?
    private var matchesListener: ListenerRegistration?

    private init() {
        networkMonitor.networkRestored
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.onNetworkRestored() }
            .store(in: &cancellables)

        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                if !connected { self?.syncStatus = .offline }
            }
            .store(in: &cancellables)
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    // MARK: - Initialization

    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true

        loadFromLocalCache()

        if networkMonitor.isConnected {
            startFirebaseListeners()
            processPendingOperations()
            preloadAllGameRecords()
        } else {
            syncStatus = .offline
            hasLoadedInitialData = true
        }
        updatePendingCount()
    }

    private func loadFromLocalCache() {
        let cachedPlayers = localCache.loadCachedPlayers()
        let cachedMatches = localCache.loadCachedMatches()
        let cachedRecords = localCache.allGameRecords

        if !cachedPlayers.isEmpty { players = cachedPlayers }
        if !cachedMatches.isEmpty { matches = cachedMatches }
        gameRecords = cachedRecords
        if !cachedPlayers.isEmpty || !cachedMatches.isEmpty { hasLoadedInitialData = true }

        if localCache.hasCompletedFullSync && !cachedRecords.isEmpty {
            isGameRecordsSynced = true
            gameRecordsSyncState = .synced
        } else if !cachedRecords.isEmpty {
            gameRecordsSyncState = .localOnly
        } else {
            gameRecordsSyncState = .loading
        }
        lastSyncTime = localCache.lastSyncTimestamp
    }

    // MARK: - Game record preload

    func preloadAllGameRecords() {
        guard networkMonitor.isConnected else {
            onMain {
                if !self.localCache.hasCompletedFullSync { self.gameRecordsSyncState = .offline }
            }
            return
        }

        db.collection("gameRecords")
            .order(by: "playedAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    self.onMain {
                        self.gameRecordsSyncState = .error("同步失败: \(error.localizedDescription)")
                    }
                    return
                }
                guard let documents = snapshot?.documents else { return }
                let remote = documents.compactMap { try? $0.data(as: GameRecord.self) }
                let remoteMatchIds = Set(remote.map { $0.matchId })
                // Keep records of matches that only exist locally (still queued for upload).
                let localOnly = self.localCache.allGameRecords.filter { !remoteMatchIds.contains($0.matchId) }
                let merged = remote + localOnly
                self.localCache.replaceAllGameRecords(merged)

                self.onMain {
                    self.gameRecords = merged
                    self.isGameRecordsSynced = true
                    self.gameRecordsSyncState = .synced
                    self.localCache.hasCompletedFullSync = true
                    self.localCache.lastSyncTimestamp = Date()
                    self.lastSyncTime = Date()
                }
            }
    }

    // MARK: - Listeners

    private func startFirebaseListeners() {
        playersListener = db.collection("players")
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handlePlayersSnapshot(snapshot, error: error)
            }

        matchesListener = db.collection("matches")
            .order(by: "startedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleMatchesSnapshot(snapshot, error: error)
            }
    }

    func stopFirebaseListeners() {
        playersListener?.remove()
        matchesListener?.remove()
        playersListener = nil
        matchesListener = nil
    }

    private func handlePlayersSnapshot(_ snapshot: QuerySnapshot?, error: Error?) {
        if let error = error {
            onMain { self.syncStatus = .error(error.localizedDescription) }
            return
        }
        guard let documents = snapshot?.documents else { return }
        let remote = documents.compactMap { try? $0.data(as: Player.self) }
        let merged = mergePlayersWithPending(remote)
        onMain {
            self.players = merged
            self.hasLoadedInitialData = true
            self.localCache.cachePlayers(merged)
            self.updateSyncStatus()
        }
    }

    private func handleMatchesSnapshot(_ snapshot: QuerySnapshot?, error: Error?) {
        if let error = error {
            onMain { self.syncStatus = .error(error.localizedDescription) }
            return
        }
        guard let documents = snapshot?.documents else { return }
        let remote = documents.compactMap { try? $0.data(as: MatchRecord.self) }
        let merged = mergeMatchesWithPending(remote)
        onMain {
            self.matches = merged
            self.hasLoadedInitialData = true
            self.localCache.cacheMatches(merged)
            self.localCache.lastSyncTimestamp = Date()
            self.lastSyncTime = Date()
            self.updateSyncStatus()
        }
    }

    // MARK: - Merging with queued work

    private func mergePlayersWithPending(_ remote: [Player]) -> [Player] {
        var result = remote
        let ops = pendingQueue.allOperations.filter {
            ($0.type == .createPlayer || $0.type == .updatePlayer) && $0.isOpen
        }
        for op in ops {
            guard let player = pendingQueue.decodePlayerPayload(op), let id = player.id else { continue }
            if let index = result.firstIndex(where: { $0.id == id }) {
                if op.type == .updatePlayer { result[index] = player }
            } else {
                result.append(player)
            }
        }
        let deleted = Set(pendingQueue.allOperations
            .filter { $0.type == .deletePlayer && $0.isOpen }
            .compactMap { pendingQueue.decodeIdPayload($0) })
        result.removeAll { $0.id.map(deleted.contains) ?? false }
        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func mergeMatchesWithPending(_ remote: [MatchRecord]) -> [MatchRecord] {
        var result = remote
        let ops = pendingQueue.allOperations.filter {
            ($0.type == .createMatch || $0.type == .updateMatch) && $0.isOpen
        }
        for op in ops {
            guard let payload = pendingQueue.decodeMatchPayload(op) else { continue }
            let match = payload.match.match
            if let index = result.firstIndex(where: { $0.id == match.id }) {
                result[index] = match
            } else {
                result.append(match)
            }
        }
        let deleted = Set(pendingQueue.allOperations
            .filter { $0.type == .deleteMatch && $0.isOpen }
            .compactMap { pendingQueue.decodeIdPayload($0) })
        result.removeAll { $0.id.map(deleted.contains) ?? false }
        return result.sorted { $0.startedAt > $1.startedAt }
    }

    // MARK: - Network recovery

    private func onNetworkRestored() {
        syncStatus = .syncing
        isSyncing = true
        if playersListener == nil { startFirebaseListeners() }
        processPendingOperations()
        if !isGameRecordsSynced { preloadAllGameRecords() }
    }

    // MARK: - Pending operation processing

    func processPendingOperations() {
        guard networkMonitor.isConnected, !isSyncingOperations else { return }
        isSyncingOperations = true
        syncStatus = .syncing
        isSyncing = true
        syncQueue.async { [weak self] in self?.processNextOperation() }
    }

    private func processNextOperation() {
        guard let operation = pendingQueue.dequeue() else {
            onMain {
                self.isSyncingOperations = false
                self.syncStatus = self.networkMonitor.isConnected ? .idle : .offline
                self.isSyncing = false
                self.pendingQueue.removeCompleted()
                self.updatePendingCount()
            }
            return
        }

        executeOperation(operation) { [weak self] success, error in
            guard let self = self else { return }
            if success {
                self.pendingQueue.markCompleted(operation.id)
            } else {
                self.pendingQueue.markFailed(operation.id, error: error ?? "Unknown error")
            }
            self.onMain { self.updatePendingCount() }
            self.syncQueue.async { self.processNextOperation() }
        }
    }

    private func executeOperation(_ operation: PendingOperation, completion: @escaping (Bool, String?) -> Void) {
        switch operation.type {
        case .createMatch, .updateMatch:
            guard let payload = pendingQueue.decodeMatchPayload(operation) else {
                completion(false, "Failed to decode payload")
                return
            }
            writeMatchToFirebase(payload.match.match, records: payload.gameRecords.map { $0.record }, completion: completion)
        case .deleteMatch:
            guard let id = pendingQueue.decodeIdPayload(operation) else {
                completion(false, "Failed to decode payload")
                return
            }
            deleteMatchInFirebase(matchId: id, completion: completion)
        case .createPlayer, .updatePlayer:
            guard let player = pendingQueue.decodePlayerPayload(operation), let id = player.id else {
                completion(false, "Failed to decode payload")
                return
            }
            writePlayerToFirebase(player, id: id, completion: completion)
        case .deletePlayer:
            guard let id = pendingQueue.decodeIdPayload(operation) else {
                completion(false, "Failed to decode payload")
                return
            }
            db.collection("players").document(id).delete { error in
                completion(error == nil, error?.localizedDescription)
            }
        case .createGameRecords, .updateGameRecords, .deleteGameRecords:
            completion(true, nil)   // handled together with the match
        }
    }

    // MARK: - Firestore writers

    private func writePlayerToFirebase(_ player: Player, id: String, completion: @escaping (Bool, String?) -> Void) {
        do {
            try db.collection("players").document(id).setData(from: player) { error in
                completion(error == nil, error?.localizedDescription)
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }

    /// Writes the match document and replaces its game records.
    private func writeMatchToFirebase(_ match: MatchRecord, records: [GameRecord], completion: @escaping (Bool, String?) -> Void) {
        guard let matchId = match.id else {
            completion(false, "Match ID is missing")
            return
        }
        do {
            try db.collection("matches").document(matchId).setData(from: match) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }
                self.replaceGameRecordsInFirebase(records, matchId: matchId, completion: completion)
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }

    private func replaceGameRecordsInFirebase(_ records: [GameRecord], matchId: String, completion: @escaping (Bool, String?) -> Void) {
        db.collection("gameRecords")
            .whereField("matchId", isEqualTo: matchId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }
                let batch = self.db.batch()
                snapshot?.documents.forEach { batch.deleteDocument($0.reference) }
                for var record in records {
                    record.matchId = matchId
                    record.id = nil
                    let ref = self.db.collection("gameRecords").document()
                    do {
                        try batch.setData(from: record, forDocument: ref)
                    } catch {
                        completion(false, error.localizedDescription)
                        return
                    }
                }
                batch.commit { error in
                    completion(error == nil, error?.localizedDescription)
                }
            }
    }

    private func deleteMatchInFirebase(matchId: String, completion: @escaping (Bool, String?) -> Void) {
        db.collection("gameRecords")
            .whereField("matchId", isEqualTo: matchId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }
                let batch = self.db.batch()
                snapshot?.documents.forEach { batch.deleteDocument($0.reference) }
                batch.deleteDocument(self.db.collection("matches").document(matchId))
                batch.commit { error in
                    completion(error == nil, error?.localizedDescription)
                }
            }
    }

    // MARK: - Public mutations (local-first)

    func addPlayer(_ player: Player) {
        guard let id = player.id else { return }
        var updated = players.filter { $0.id != id }
        updated.append(player)
        updated.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        players = updated
        localCache.cachePlayers(updated)

        if networkMonitor.isConnected {
            writePlayerToFirebase(player, id: id) { [weak self] success, _ in
                if !success {
                    self?.pendingQueue.enqueueCreatePlayer(player)
                    self?.onMain { self?.updatePendingCount() }
                }
            }
        } else {
            pendingQueue.enqueueCreatePlayer(player)
            updatePendingCount()
        }
    }

    func updatePlayer(_ player: Player) {
        guard let id = player.id else { return }
        if let index = players.firstIndex(where: { $0.id == id }) {
            players[index] = player
            localCache.cachePlayers(players)
        }
        if networkMonitor.isConnected {
            writePlayerToFirebase(player, id: id) { [weak self] success, _ in
                if !success {
                    self?.pendingQueue.enqueueUpdatePlayer(player)
                    self?.onMain { self?.updatePendingCount() }
                }
            }
        } else {
            pendingQueue.enqueueUpdatePlayer(player)
            updatePendingCount()
        }
    }

    func deletePlayer(id: String) {
        players.removeAll { $0.id == id }
        localCache.cachePlayers(players)
        if networkMonitor.isConnected {
            db.collection("players").document(id).delete { [weak self] error in
                if error != nil {
                    self?.pendingQueue.enqueueDeletePlayer(playerId: id)
                    self?.onMain { self?.updatePendingCount() }
                }
            }
        } else {
            pendingQueue.enqueueDeletePlayer(playerId: id)
            updatePendingCount()
        }
    }

    /// Creates or updates a match together with its game records.
    func upsertMatch(_ match: MatchRecord, records: [GameRecord]) {
        guard let matchId = match.id else { return }
        var normalized = records
        for i in normalized.indices { normalized[i].matchId = matchId }

        var updated = matches
        if let index = updated.firstIndex(where: { $0.id == matchId }) {
            updated[index] = match
        } else {
            updated.append(match)
        }
        updated.sort { $0.startedAt > $1.startedAt }
        matches = updated
        localCache.cacheMatches(updated)
        localCache.setGameRecords(normalized, forMatchId: matchId)
        gameRecords = localCache.allGameRecords

        if networkMonitor.isConnected {
            writeMatchToFirebase(match, records: normalized) { [weak self] success, _ in
                if !success {
                    self?.pendingQueue.enqueueUpsertMatch(match, gameRecords: normalized)
                    self?.onMain { self?.updatePendingCount() }
                }
            }
        } else {
            pendingQueue.enqueueUpsertMatch(match, gameRecords: normalized)
            updatePendingCount()
        }
    }

    func deleteMatch(matchId: String) {
        matches.removeAll { $0.id == matchId }
        localCache.cacheMatches(matches)
        localCache.deleteGameRecords(forMatchId: matchId)
        gameRecords = localCache.allGameRecords

        if networkMonitor.isConnected {
            deleteMatchInFirebase(matchId: matchId) { [weak self] success, _ in
                if !success {
                    self?.pendingQueue.enqueueDeleteMatch(matchId: matchId)
                    self?.onMain { self?.updatePendingCount() }
                }
            }
        } else {
            pendingQueue.enqueueDeleteMatch(matchId: matchId)
            updatePendingCount()
        }
    }

    /// Fetches the records of a match from Firestore when nothing is cached for it.
    func refreshGameRecordsIfMissing(forMatchId matchId: String) {
        guard networkMonitor.isConnected, localCache.gameRecords(forMatchId: matchId).isEmpty else { return }
        db.collection("gameRecords")
            .whereField("matchId", isEqualTo: matchId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self, error == nil, let documents = snapshot?.documents else { return }
                let records = documents.compactMap { try? $0.data(as: GameRecord.self) }
                guard !records.isEmpty else { return }
                self.localCache.setGameRecords(records, forMatchId: matchId)
                self.onMain { self.gameRecords = self.localCache.allGameRecords }
            }
    }

    // MARK: - Helpers

    private func updateSyncStatus() {
        if networkMonitor.isConnected {
            syncStatus = pendingQueue.hasPendingOperations ? .syncing : .idle
        } else {
            syncStatus = .offline
        }
        isSyncing = syncStatus == .syncing
    }

    private func updatePendingCount() {
        pendingOperationsCount = pendingQueue.pendingCount
    }

    func forceSync() {
        guard networkMonitor.isConnected else { return }
        stopFirebaseListeners()
        startFirebaseListeners()
        processPendingOperations()
        preloadAllGameRecords()
    }

    func resetAndSync() {
        stopFirebaseListeners()
        localCache.clearAllCache()
        pendingQueue.clearAll()
        players = []
        matches = []
        gameRecords = []
        isGameRecordsSynced = false
        hasLoadedInitialData = false
        isInitialized = false
        updatePendingCount()
        initialize()
    }
}
