//
//  SyncManager.swift
//  FightTheLandlord
//
//  Data Sync Manager - Coordinates local cache and remote database synchronization
//
//  Core Responsibilities:
//  1. Load data from local cache immediately on startup for fast UI
//  2. Sync with Firebase in background, update local cache
//  3. Queue operations when offline, execute when online
//  4. Handle data conflicts using Last-Write-Wins strategy
//

import Foundation
import Combine
import FirebaseFirestore

/// Sync status enumeration
enum SyncStatus: Equatable {
    case idle           // Idle
    case syncing        // Syncing in progress
    case offline        // Offline mode
    case error(String)  // Error occurred
}

/// Game records sync state for UI feedback
enum GameRecordsSyncState: Equatable {
    case loading        // Loading from local cache
    case localOnly      // Showing local data, not yet synced with server
    case syncing        // Syncing with server in background
    case synced         // Fully synced with server
    case offline        // Offline, showing cached data
    case error(String)  // Sync error occurred
}

/// Sync Manager - Singleton pattern
class SyncManager: ObservableObject {
    static let shared = SyncManager()

    // MARK: - Dependencies

    private let localCache = LocalCacheManager.shared
    private let pendingQueue = PendingOperationQueue.shared
    private let networkMonitor = NetworkMonitor.shared

    // MARK: - Published State

    @Published private(set) var syncStatus: SyncStatus = .idle
    @Published private(set) var lastSyncTime: Date?
    @Published private(set) var pendingOperationsCount: Int = 0
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var isGameRecordsSynced: Bool = false
    @Published private(set) var gameRecordsSyncState: GameRecordsSyncState = .loading

    // Synced data
    @Published var players: [Player] = []
    @Published var matches: [MatchRecord] = []

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private let db = Firestore.firestore()
    private var isInitialized = false

    // Sync queue
    private let syncQueue = DispatchQueue(label: "SyncManager.syncQueue")
    private var isSyncingOperations = false

    // Firestore listeners
    private var playersListener: ListenerRegistration?
    private var matchesListener: ListenerRegistration?

    // MARK: - Initialization

    private init() {
        setupNetworkMonitoring()
    }

    /// Setup network status monitoring
    private func setupNetworkMonitoring() {
        // Listen for network restoration
        networkMonitor.networkRestored
            .sink { [weak self] _ in
                self?.onNetworkRestored()
            }
            .store(in: &cancellables)

        // Listen for network status changes
        networkMonitor.$isConnected
            .sink { [weak self] connected in
                if !connected {
                    self?.syncStatus = .offline
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Initialization Flow

    /// Initialize sync system - called on app startup
    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true

        print("[SyncManager] Initializing...")

        // 1. Load data from local cache immediately (fast startup)
        loadFromLocalCache()

        // 2. If online, start Firebase listeners and sync
        if networkMonitor.isConnected {
            startFirebaseListeners()
            processPendingOperations()
            // Preload all game records in background
            preloadAllGameRecords()
        } else {
            syncStatus = .offline
            print("[SyncManager] Starting in offline mode")
        }

        // Update pending operations count
        updatePendingCount()
    }

    /// Load data from local cache
    private func loadFromLocalCache() {
        let cachedPlayers = localCache.loadCachedPlayers()
        let cachedMatches = localCache.loadCachedMatches()

        if !cachedPlayers.isEmpty {
            self.players = cachedPlayers
            print("[SyncManager] Loaded \(cachedPlayers.count) players from cache")
        }

        if !cachedMatches.isEmpty {
            self.matches = cachedMatches
            print("[SyncManager] Loaded \(cachedMatches.count) matches from cache")
        }

        // Check if we have completed a full sync before
        let cachedGameRecordsCount = localCache.loadAllCachedGameRecords().count
        if localCache.hasCompletedFullSync && cachedGameRecordsCount > 0 {
            // Trust local cache - we've synced before, data is ready to use
            isGameRecordsSynced = true
            // Don't set to .syncing here - let preloadAllGameRecords handle state transitions
            // This avoids showing "syncing" or "offline" incorrectly at startup
            gameRecordsSyncState = .synced
            print("[SyncManager] hasCompletedFullSync=true, trusting \(cachedGameRecordsCount) cached game records")
        } else if cachedGameRecordsCount > 0 {
            // Have some cached data but never completed full sync
            gameRecordsSyncState = .localOnly
            print("[SyncManager] Found \(cachedGameRecordsCount) cached game records (never completed full sync)")
        } else {
            // No cached data
            gameRecordsSyncState = .loading
            print("[SyncManager] No cached game records")
        }

        lastSyncTime = localCache.lastSyncTimestamp
    }

    // MARK: - Game Records Preloading

    /// Preload all game records from Firebase to local cache
    func preloadAllGameRecords() {
        guard networkMonitor.isConnected else {
            print("[SyncManager] Cannot preload game records: offline")
            // Only change to offline if we don't have trusted data
            DispatchQueue.main.async {
                if !self.localCache.hasCompletedFullSync {
                    self.gameRecordsSyncState = .offline
                }
                // If hasCompletedFullSync is true, keep showing .synced (trusted local data)
            }
            return
        }

        print("[SyncManager] Preloading all game records...")
        // Don't change state to .syncing if we already have trusted data
        // This keeps the UI clean - no unnecessary "syncing" indicators

        db.collection("gameRecords")
            .order(by: "playedAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("[SyncManager] Failed to preload game records: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        // If we have previously synced data, still allow using it
                        if self.localCache.hasCompletedFullSync {
                            self.gameRecordsSyncState = .error("同步失败: \(error.localizedDescription)")
                        } else {
                            self.gameRecordsSyncState = .error("加载失败: \(error.localizedDescription)")
                        }
                    }
                    return
                }

                guard let documents = snapshot?.documents else { return }

                let records = documents.compactMap { doc in
                    try? doc.data(as: GameRecord.self)
                }

                // Group by matchId and cache
                let groupedRecords = Dictionary(grouping: records) { $0.matchId }
                for (matchId, matchRecords) in groupedRecords {
                    self.localCache.cacheGameRecords(matchRecords, forMatchId: matchId)
                }

                DispatchQueue.main.async {
                    self.isGameRecordsSynced = true
                    self.gameRecordsSyncState = .synced
                    self.localCache.hasCompletedFullSync = true
                    self.localCache.lastSyncTimestamp = Date()
                    self.lastSyncTime = Date()
                    print("[SyncManager] Preloaded \(records.count) game records for \(groupedRecords.count) matches, marked hasCompletedFullSync=true")
                }
            }
    }

    // MARK: - Firebase Listeners

    /// Start Firebase real-time listeners
    private func startFirebaseListeners() {
        print("[SyncManager] Starting Firebase listeners...")

        // Players listener
        playersListener = db.collection("players")
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handlePlayersSnapshot(snapshot, error: error)
            }

        // Matches listener
        matchesListener = db.collection("matches")
            .order(by: "startedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleMatchesSnapshot(snapshot, error: error)
            }
    }

    /// Handle Players snapshot update
    private func handlePlayersSnapshot(_ snapshot: QuerySnapshot?, error: Error?) {
        if let error = error {
            print("[SyncManager] Players listener error: \(error.localizedDescription)")
            syncStatus = .error(error.localizedDescription)
            return
        }

        guard let documents = snapshot?.documents else { return }

        let remotePlayers = documents.compactMap { doc in
            try? doc.data(as: Player.self)
        }

        // Merge remote data with pending local operations
        let mergedPlayers = mergePlayersWithPending(remotePlayers)

        DispatchQueue.main.async {
            self.players = mergedPlayers
            self.localCache.cachePlayers(mergedPlayers)
            self.updateSyncStatus()
        }

        print("[SyncManager] Synced \(mergedPlayers.count) players")
    }

    /// Handle Matches snapshot update
    private func handleMatchesSnapshot(_ snapshot: QuerySnapshot?, error: Error?) {
        if let error = error {
            print("[SyncManager] Matches listener error: \(error.localizedDescription)")
            syncStatus = .error(error.localizedDescription)
            return
        }

        guard let documents = snapshot?.documents else { return }

        let remoteMatches = documents.compactMap { doc in
            try? doc.data(as: MatchRecord.self)
        }

        // Merge remote data with pending local operations
        let mergedMatches = mergeMatchesWithPending(remoteMatches)

        DispatchQueue.main.async {
            self.matches = mergedMatches
            self.localCache.cacheMatches(mergedMatches)
            self.localCache.lastSyncTimestamp = Date()
            self.lastSyncTime = Date()
            self.updateSyncStatus()
        }

        print("[SyncManager] Synced \(mergedMatches.count) matches")
    }

    /// Stop Firebase listeners
    func stopFirebaseListeners() {
        playersListener?.remove()
        matchesListener?.remove()
        playersListener = nil
        matchesListener = nil
        print("[SyncManager] Stopped Firebase listeners")
    }

    // MARK: - Data Merging

    /// Merge remote Players with pending local operations
    private func mergePlayersWithPending(_ remotePlayers: [Player]) -> [Player] {
        var result = remotePlayers

        // Check for pending player creations (with temporary ID)
        let pendingOps = pendingQueue.allOperations.filter {
            ($0.type == .createPlayer || $0.type == .updatePlayer) &&
            ($0.status == .pending || $0.status == .inProgress || $0.status == .failed)
        }

        for op in pendingOps {
            if let localId = op.localId,
               !result.contains(where: { $0.id == localId }) {
                // This is a locally created player not yet on remote
                if let player = decodePlayerFromOperation(op) {
                    result.append(player)
                }
            }
        }

        return result.sorted { $0.name < $1.name }
    }

    /// Merge remote Matches with pending local operations
    private func mergeMatchesWithPending(_ remoteMatches: [MatchRecord]) -> [MatchRecord] {
        var result = remoteMatches

        // Check for pending match creations
        let pendingOps = pendingQueue.allOperations.filter {
            ($0.type == .createMatch || $0.type == .updateMatch) &&
            ($0.status == .pending || $0.status == .inProgress || $0.status == .failed)
        }

        for op in pendingOps {
            if let localId = op.localId {
                // Check if match already exists on remote
                if !result.contains(where: { $0.id == localId }) {
                    // Locally created match not yet on remote
                    if let match = decodeMatchFromOperation(op) {
                        result.append(match)
                    }
                }
            }
        }

        return result.sorted { $0.startedAt > $1.startedAt }
    }

    /// Decode Player from operation
    private func decodePlayerFromOperation(_ op: PendingOperation) -> Player? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let cacheable = try? decoder.decode(CacheablePlayer.self, from: op.payload) {
            return cacheable.toPlayer()
        }
        return nil
    }

    /// Decode Match from operation
    private func decodeMatchFromOperation(_ op: PendingOperation) -> MatchRecord? {
        struct CreateMatchPayload: Codable {
            let match: CacheableMatch
            let gameRecords: [CacheableGameRecord]
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let payload = try? decoder.decode(CreateMatchPayload.self, from: op.payload) {
            return payload.match.toMatchRecord()
        }
        return nil
    }

    // MARK: - Network Recovery

    /// Called when network is restored
    private func onNetworkRestored() {
        print("[SyncManager] Network restored, starting sync...")
        syncStatus = .syncing
        isSyncing = true

        // Restart Firebase listeners
        if playersListener == nil {
            startFirebaseListeners()
        }

        // Process pending operations
        processPendingOperations()

        // Preload game records if not already synced
        if !isGameRecordsSynced {
            preloadAllGameRecords()
        }
    }

    // MARK: - Pending Operations Processing

    /// Process pending operations queue
    func processPendingOperations() {
        guard networkMonitor.isConnected else {
            print("[SyncManager] Cannot process operations: offline")
            return
        }

        guard !isSyncingOperations else {
            print("[SyncManager] Already processing operations")
            return
        }

        isSyncingOperations = true
        syncStatus = .syncing
        isSyncing = true

        syncQueue.async { [weak self] in
            self?.processNextOperation()
        }
    }

    /// Process next operation in queue
    private func processNextOperation() {
        guard let operation = pendingQueue.dequeue() else {
            // Queue is empty
            DispatchQueue.main.async {
                self.isSyncingOperations = false
                self.syncStatus = .idle
                self.isSyncing = false
                self.pendingQueue.removeCompleted()
                self.updatePendingCount()
            }
            print("[SyncManager] All pending operations processed")
            return
        }

        print("[SyncManager] Processing operation: \(operation.type.rawValue)")

        executeOperation(operation) { [weak self] success, error in
            if success {
                self?.pendingQueue.markCompleted(operation.id)
            } else {
                self?.pendingQueue.markFailed(operation.id, error: error ?? "Unknown error")
            }

            // Process next
            self?.syncQueue.async {
                self?.processNextOperation()
            }
        }
    }

    /// Execute a single operation
    private func executeOperation(_ operation: PendingOperation, completion: @escaping (Bool, String?) -> Void) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        switch operation.type {
        case .createMatch:
            executeCreateMatch(operation, decoder: decoder, completion: completion)
        case .updateMatch:
            executeUpdateMatch(operation, decoder: decoder, completion: completion)
        case .deleteMatch:
            executeDeleteMatch(operation, decoder: decoder, completion: completion)
        case .createPlayer:
            executeCreatePlayer(operation, decoder: decoder, completion: completion)
        case .updatePlayer:
            executeUpdatePlayer(operation, decoder: decoder, completion: completion)
        case .deletePlayer:
            executeDeletePlayer(operation, decoder: decoder, completion: completion)
        case .createGameRecords, .updateGameRecords, .deleteGameRecords:
            // GameRecords are usually handled together with Match
            completion(true, nil)
        }
    }

    // MARK: - Operation Executors

    private func executeCreateMatch(_ op: PendingOperation, decoder: JSONDecoder, completion: @escaping (Bool, String?) -> Void) {
        struct CreateMatchPayload: Codable {
            let match: CacheableMatch
            let gameRecords: [CacheableGameRecord]
        }

        guard let payload = try? decoder.decode(CreateMatchPayload.self, from: op.payload) else {
            completion(false, "Failed to decode payload")
            return
        }

        let match = payload.match.toMatchRecord()
        let gameRecords = payload.gameRecords.map { $0.toGameRecord() }

        // Idempotency check - see if already exists
        if let localId = op.localId {
            db.collection("matches").document(localId).getDocument { [weak self] snapshot, error in
                if let snapshot = snapshot, snapshot.exists {
                    // Already exists, skip
                    print("[SyncManager] Match already exists, skipping create")
                    completion(true, nil)
                    return
                }

                // Create new match
                self?.createMatchInFirebase(match, gameRecords: gameRecords, completion: completion)
            }
        } else {
            createMatchInFirebase(match, gameRecords: gameRecords, completion: completion)
        }
    }

    private func createMatchInFirebase(_ match: MatchRecord, gameRecords: [GameRecord], completion: @escaping (Bool, String?) -> Void) {
        // Use the existing match ID instead of letting Firebase generate a new one
        // This prevents duplicate records (one with local ID, one with Firebase ID)
        guard let matchId = match.id else {
            completion(false, "Match ID is missing")
            return
        }

        do {
            // Use setData with the existing ID instead of addDocument
            try db.collection("matches").document(matchId).setData(from: match) { [weak self] error in
                guard let self = self else { return }

                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }

                // Save GameRecords
                if !gameRecords.isEmpty {
                    let batch = self.db.batch()
                    for var record in gameRecords {
                        record.matchId = matchId
                        let recordRef = self.db.collection("gameRecords").document()
                        do {
                            try batch.setData(from: record, forDocument: recordRef)
                        } catch {
                            completion(false, error.localizedDescription)
                            return
                        }
                    }
                    batch.commit { error in
                        if let error = error {
                            completion(false, error.localizedDescription)
                        } else {
                            completion(true, nil)
                        }
                    }
                } else {
                    completion(true, nil)
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }

    private func executeUpdateMatch(_ op: PendingOperation, decoder: JSONDecoder, completion: @escaping (Bool, String?) -> Void) {
        struct UpdateMatchPayload: Codable {
            let match: CacheableMatch
            let gameRecords: [CacheableGameRecord]
        }

        guard let payload = try? decoder.decode(UpdateMatchPayload.self, from: op.payload) else {
            completion(false, "Failed to decode payload")
            return
        }

        let match = payload.match.toMatchRecord()
        guard let matchId = match.id else {
            completion(false, "Match ID is missing")
            return
        }

        do {
            try db.collection("matches").document(matchId).setData(from: match) { error in
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }

                // Update GameRecords
                let gameRecords = payload.gameRecords.map { $0.toGameRecord() }
                self.updateGameRecordsInFirebase(gameRecords, matchId: matchId, completion: completion)
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }

    private func updateGameRecordsInFirebase(_ records: [GameRecord], matchId: String, completion: @escaping (Bool, String?) -> Void) {
        // Delete old records first, then add new ones
        db.collection("gameRecords")
            .whereField("matchId", isEqualTo: matchId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }

                let batch = self.db.batch()

                // Delete old records
                snapshot?.documents.forEach { doc in
                    batch.deleteDocument(doc.reference)
                }

                // Add new records
                for var record in records {
                    record.matchId = matchId
                    let ref = self.db.collection("gameRecords").document()
                    do {
                        try batch.setData(from: record, forDocument: ref)
                    } catch {
                        completion(false, error.localizedDescription)
                        return
                    }
                }

                batch.commit { error in
                    if let error = error {
                        completion(false, error.localizedDescription)
                    } else {
                        self.localCache.cacheGameRecords(records, forMatchId: matchId)
                        completion(true, nil)
                    }
                }
            }
    }

    private func executeDeleteMatch(_ op: PendingOperation, decoder: JSONDecoder, completion: @escaping (Bool, String?) -> Void) {
        struct DeleteMatchPayload: Codable {
            let matchId: String
        }

        guard let payload = try? decoder.decode(DeleteMatchPayload.self, from: op.payload) else {
            completion(false, "Failed to decode payload")
            return
        }

        let matchId = payload.matchId

        // Delete GameRecords first
        db.collection("gameRecords")
            .whereField("matchId", isEqualTo: matchId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                let batch = self.db.batch()

                snapshot?.documents.forEach { doc in
                    batch.deleteDocument(doc.reference)
                }

                batch.deleteDocument(self.db.collection("matches").document(matchId))

                batch.commit { error in
                    if let error = error {
                        completion(false, error.localizedDescription)
                    } else {
                        self.localCache.deleteCachedGameRecords(forMatchId: matchId)
                        completion(true, nil)
                    }
                }
            }
    }

    private func executeCreatePlayer(_ op: PendingOperation, decoder: JSONDecoder, completion: @escaping (Bool, String?) -> Void) {
        guard let cacheable = try? decoder.decode(CacheablePlayer.self, from: op.payload) else {
            completion(false, "Failed to decode payload")
            return
        }

        let player = cacheable.toPlayer()

        // Check if name already exists
        db.collection("players")
            .whereField("name", isEqualTo: player.name)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }

                if let docs = snapshot?.documents, !docs.isEmpty {
                    // Name already exists, treat as success (idempotent)
                    completion(true, nil)
                    return
                }

                // Create player
                do {
                    try self?.db.collection("players").addDocument(from: player) { error in
                        if let error = error {
                            completion(false, error.localizedDescription)
                        } else {
                            completion(true, nil)
                        }
                    }
                } catch {
                    completion(false, error.localizedDescription)
                }
            }
    }

    private func executeUpdatePlayer(_ op: PendingOperation, decoder: JSONDecoder, completion: @escaping (Bool, String?) -> Void) {
        guard let cacheable = try? decoder.decode(CacheablePlayer.self, from: op.payload) else {
            completion(false, "Failed to decode payload")
            return
        }

        let player = cacheable.toPlayer()
        guard let playerId = player.id else {
            completion(false, "Player ID is missing")
            return
        }

        do {
            try db.collection("players").document(playerId).setData(from: player) { error in
                if let error = error {
                    completion(false, error.localizedDescription)
                } else {
                    completion(true, nil)
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }

    private func executeDeletePlayer(_ op: PendingOperation, decoder: JSONDecoder, completion: @escaping (Bool, String?) -> Void) {
        struct DeletePlayerPayload: Codable {
            let playerId: String
        }

        guard let payload = try? decoder.decode(DeletePlayerPayload.self, from: op.payload) else {
            completion(false, "Failed to decode payload")
            return
        }

        db.collection("players").document(payload.playerId).delete { error in
            if let error = error {
                completion(false, error.localizedDescription)
            } else {
                completion(true, nil)
            }
        }
    }

    // MARK: - Public API for Data Operations

    /// Save match (local-first)
    func saveMatch(_ match: MatchRecord, gameRecords: [GameRecord], completion: ((String?) -> Void)? = nil) {
        // Generate local ID if missing
        var matchToSave = match
        let localId = match.id ?? UUID().uuidString
        matchToSave.id = localId

        // 1. Save to local cache immediately
        var currentMatches = matches
        currentMatches.insert(matchToSave, at: 0)
        matches = currentMatches
        localCache.cacheMatches(currentMatches)

        // Ensure all game records have the correct matchId before caching
        var recordsToCache = gameRecords
        for i in recordsToCache.indices {
            if recordsToCache[i].matchId != localId {
                print("[SyncManager] Warning: Fixing mismatched matchId in game record \(i)")
                recordsToCache[i].matchId = localId
            }
        }
        localCache.cacheGameRecords(recordsToCache, forMatchId: localId)

        // Verify the cache was written correctly
        let cachedRecords = localCache.loadCachedGameRecords(forMatchId: localId)
        print("[SyncManager] Saved match locally: \(localId) with \(gameRecords.count) records, verified \(cachedRecords.count) in cache")

        // 2. If online, upload directly
        if networkMonitor.isConnected {
            createMatchInFirebase(matchToSave, gameRecords: gameRecords) { success, error in
                if success {
                    print("[SyncManager] Match uploaded to Firebase")
                } else {
                    // Upload failed, queue for retry
                    print("[SyncManager] Firebase upload failed, queuing operation")
                    self.pendingQueue.enqueueCreateMatch(matchToSave, gameRecords: gameRecords)
                    self.updatePendingCount()
                }
                completion?(localId)
            }
        } else {
            // 3. Offline mode, queue for later
            pendingQueue.enqueueCreateMatch(matchToSave, gameRecords: gameRecords)
            updatePendingCount()
            print("[SyncManager] Offline mode, operation queued")
            completion?(localId)
        }
    }

    /// Update match
    func updateMatch(_ match: MatchRecord, gameRecords: [GameRecord]) {
        guard let matchId = match.id else { return }

        // 1. Update local cache
        if let index = matches.firstIndex(where: { $0.id == matchId }) {
            matches[index] = match
            localCache.cacheMatches(matches)
            localCache.cacheGameRecords(gameRecords, forMatchId: matchId)
        }

        // 2. Sync to remote
        if networkMonitor.isConnected {
            do {
                try db.collection("matches").document(matchId).setData(from: match)
                updateGameRecordsInFirebase(gameRecords, matchId: matchId) { _, _ in }
            } catch {
                pendingQueue.enqueueUpdateMatch(match, gameRecords: gameRecords)
                updatePendingCount()
            }
        } else {
            pendingQueue.enqueueUpdateMatch(match, gameRecords: gameRecords)
            updatePendingCount()
        }
    }

    /// Delete match
    func deleteMatch(matchId: String) {
        // 1. Delete from local cache
        matches.removeAll { $0.id == matchId }
        localCache.cacheMatches(matches)
        localCache.deleteCachedGameRecords(forMatchId: matchId)

        // 2. Sync to remote
        if networkMonitor.isConnected {
            db.collection("gameRecords")
                .whereField("matchId", isEqualTo: matchId)
                .getDocuments { [weak self] snapshot, _ in
                    guard let self = self else { return }
                    let batch = self.db.batch()
                    snapshot?.documents.forEach { batch.deleteDocument($0.reference) }
                    batch.deleteDocument(self.db.collection("matches").document(matchId))
                    batch.commit { _ in }
                }
        } else {
            pendingQueue.enqueueDeleteMatch(matchId: matchId)
            updatePendingCount()
        }
    }

    /// Load game records for a match
    func loadGameRecords(forMatchId matchId: String, completion: @escaping ([GameRecord]) -> Void) {
        // Load from local cache first
        let cachedRecords = localCache.loadCachedGameRecords(forMatchId: matchId)

        // If we have cached records, return them immediately
        if !cachedRecords.isEmpty {
            print("[SyncManager] Returning \(cachedRecords.count) cached records for match \(matchId)")
            completion(cachedRecords)

            // Still try to refresh from Firebase in background if online
            if networkMonitor.isConnected {
                db.collection("gameRecords")
                    .whereField("matchId", isEqualTo: matchId)
                    .getDocuments { [weak self] snapshot, error in
                        guard error == nil, let documents = snapshot?.documents else { return }

                        let records = documents.compactMap { doc in
                            try? doc.data(as: GameRecord.self)
                        }.sorted { $0.gameIndex < $1.gameIndex }

                        // Update cache if Firebase has different data
                        if records.count != cachedRecords.count && !records.isEmpty {
                            self?.localCache.cacheGameRecords(records, forMatchId: matchId)
                            completion(records)
                        }
                    }
            }
            return
        }

        // Cache is empty - check if we're online
        if networkMonitor.isConnected {
            print("[SyncManager] No cached records, loading from Firebase for match \(matchId)")
            db.collection("gameRecords")
                .whereField("matchId", isEqualTo: matchId)
                .getDocuments { [weak self] snapshot, error in
                    if let error = error {
                        print("[SyncManager] Firebase error: \(error.localizedDescription)")
                        completion([])
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        completion([])
                        return
                    }

                    let records = documents.compactMap { doc in
                        try? doc.data(as: GameRecord.self)
                    }.sorted { $0.gameIndex < $1.gameIndex }

                    // Update cache
                    if !records.isEmpty {
                        self?.localCache.cacheGameRecords(records, forMatchId: matchId)
                    }

                    print("[SyncManager] Loaded \(records.count) records from Firebase for match \(matchId)")
                    completion(records)
                }
        } else {
            // Offline and no cache
            print("[SyncManager] Offline and no cached records for match \(matchId)")
            completion([])
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

    /// Force sync manually
    func forceSync() {
        guard networkMonitor.isConnected else {
            print("[SyncManager] Cannot force sync: offline")
            return
        }

        // Stop and restart listeners
        stopFirebaseListeners()
        startFirebaseListeners()
        processPendingOperations()

        // Re-preload game records
        preloadAllGameRecords()
    }

    /// Reset all local data and re-sync
    func resetAndSync() {
        // Clear local cache
        localCache.clearAllCache()
        pendingQueue.clearAll()

        // Clear in-memory data
        players = []
        matches = []
        isGameRecordsSynced = false

        // Reinitialize
        isInitialized = false
        initialize()
    }
}
