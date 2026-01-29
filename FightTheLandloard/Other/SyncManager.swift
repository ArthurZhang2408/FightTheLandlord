//
//  SyncManager.swift
//  FightTheLandlord
//
//  数据同步管理器 - 协调本地缓存与远程数据库的同步
//
//  核心职责：
//  1. 启动时从本地缓存快速加载数据到UI
//  2. 后台与Firebase同步，更新本地缓存
//  3. 离线时将操作存入队列，联网后执行
//  4. 处理数据冲突（使用Last-Write-Wins策略）
//

import Foundation
import Combine
import FirebaseFirestore

/// 同步状态
enum SyncStatus: Equatable {
    case idle           // 空闲
    case syncing        // 同步中
    case offline        // 离线模式
    case error(String)  // 错误
}

/// 同步管理器 - 单例模式
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

    // 同步后的数据
    @Published var players: [Player] = []
    @Published var matches: [MatchRecord] = []

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private let db = Firestore.firestore()
    private var isInitialized = false

    // 同步队列
    private let syncQueue = DispatchQueue(label: "SyncManager.syncQueue")
    private var isSyncingOperations = false

    // Firestore listeners
    private var playersListener: ListenerRegistration?
    private var matchesListener: ListenerRegistration?

    // MARK: - Initialization

    private init() {
        setupNetworkMonitoring()
    }

    /// 设置网络状态监听
    private func setupNetworkMonitoring() {
        // 监听网络恢复
        networkMonitor.networkRestored
            .sink { [weak self] _ in
                self?.onNetworkRestored()
            }
            .store(in: &cancellables)

        // 监听网络状态变化
        networkMonitor.$isConnected
            .sink { [weak self] connected in
                if !connected {
                    self?.syncStatus = .offline
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Initialization Flow

    /// 初始化同步系统 - 应用启动时调用
    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true

        print("[SyncManager] Initializing...")

        // 1. 立即从本地缓存加载数据（快速启动）
        loadFromLocalCache()

        // 2. 如果在线，启动Firebase监听并同步
        if networkMonitor.isConnected {
            startFirebaseListeners()
            processPendingOperations()
        } else {
            syncStatus = .offline
            print("[SyncManager] Starting in offline mode")
        }

        // 更新待处理操作计数
        updatePendingCount()
    }

    /// 从本地缓存加载数据
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

        lastSyncTime = localCache.lastSyncTimestamp
    }

    // MARK: - Firebase Listeners

    /// 启动Firebase实时监听
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

    /// 处理Players快照更新
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

        // 合并远程数据与本地待处理操作
        let mergedPlayers = mergePlayersWithPending(remotePlayers)

        DispatchQueue.main.async {
            self.players = mergedPlayers
            self.localCache.cachePlayers(mergedPlayers)
            self.updateSyncStatus()
        }

        print("[SyncManager] Synced \(mergedPlayers.count) players")
    }

    /// 处理Matches快照更新
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

        // 合并远程数据与本地待处理操作
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

    /// 停止Firebase监听
    func stopFirebaseListeners() {
        playersListener?.remove()
        matchesListener?.remove()
        playersListener = nil
        matchesListener = nil
        print("[SyncManager] Stopped Firebase listeners")
    }

    // MARK: - Data Merging

    /// 合并远程Players与本地待处理操作
    private func mergePlayersWithPending(_ remotePlayers: [Player]) -> [Player] {
        var result = remotePlayers

        // 检查是否有待创建的玩家（使用临时ID）
        let pendingOps = pendingQueue.allOperations.filter {
            ($0.type == .createPlayer || $0.type == .updatePlayer) &&
            ($0.status == .pending || $0.status == .inProgress || $0.status == .failed)
        }

        for op in pendingOps {
            if let localId = op.localId,
               !result.contains(where: { $0.id == localId }) {
                // 这是一个本地创建的玩家，远程还不存在
                if let player = decodePlayerFromOperation(op) {
                    result.append(player)
                }
            }
        }

        return result.sorted { $0.name < $1.name }
    }

    /// 合并远程Matches与本地待处理操作
    private func mergeMatchesWithPending(_ remoteMatches: [MatchRecord]) -> [MatchRecord] {
        var result = remoteMatches

        // 检查是否有待创建的对局
        let pendingOps = pendingQueue.allOperations.filter {
            ($0.type == .createMatch || $0.type == .updateMatch) &&
            ($0.status == .pending || $0.status == .inProgress || $0.status == .failed)
        }

        for op in pendingOps {
            if let localId = op.localId {
                // 检查远程是否已存在此对局
                if !result.contains(where: { $0.id == localId }) {
                    // 本地创建的对局，远程还不存在
                    if let match = decodeMatchFromOperation(op) {
                        result.append(match)
                    }
                }
            }
        }

        return result.sorted { $0.startedAt > $1.startedAt }
    }

    /// 从操作中解码Player
    private func decodePlayerFromOperation(_ op: PendingOperation) -> Player? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let cacheable = try? decoder.decode(CacheablePlayer.self, from: op.payload) {
            return cacheable.toPlayer()
        }
        return nil
    }

    /// 从操作中解码Match
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

    /// 网络恢复时调用
    private func onNetworkRestored() {
        print("[SyncManager] Network restored, starting sync...")
        syncStatus = .syncing
        isSyncing = true

        // 重新启动Firebase监听
        if playersListener == nil {
            startFirebaseListeners()
        }

        // 处理待处理操作
        processPendingOperations()
    }

    // MARK: - Pending Operations Processing

    /// 处理待处理操作队列
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

    /// 处理下一个操作
    private func processNextOperation() {
        guard let operation = pendingQueue.dequeue() else {
            // 队列已空
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

            // 处理下一个
            self?.syncQueue.async {
                self?.processNextOperation()
            }
        }
    }

    /// 执行单个操作
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
            // GameRecords 通常与 Match 一起处理
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

        // 检查是否已存在（幂等性检查）
        if let localId = op.localId {
            db.collection("matches").document(localId).getDocument { [weak self] snapshot, error in
                if let snapshot = snapshot, snapshot.exists {
                    // 已存在，跳过
                    print("[SyncManager] Match already exists, skipping create")
                    completion(true, nil)
                    return
                }

                // 创建新对局
                self?.createMatchInFirebase(match, gameRecords: gameRecords, completion: completion)
            }
        } else {
            createMatchInFirebase(match, gameRecords: gameRecords, completion: completion)
        }
    }

    private func createMatchInFirebase(_ match: MatchRecord, gameRecords: [GameRecord], completion: @escaping (Bool, String?) -> Void) {
        do {
            let ref = try db.collection("matches").addDocument(from: match)
            let matchId = ref.documentID

            // 保存GameRecords
            if !gameRecords.isEmpty {
                let batch = db.batch()
                for var record in gameRecords {
                    record.matchId = matchId
                    let recordRef = db.collection("gameRecords").document()
                    try batch.setData(from: record, forDocument: recordRef)
                }
                batch.commit { error in
                    if let error = error {
                        completion(false, error.localizedDescription)
                    } else {
                        // 更新本地缓存
                        self.localCache.cacheGameRecords(gameRecords, forMatchId: matchId)
                        completion(true, nil)
                    }
                }
            } else {
                completion(true, nil)
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

                // 更新GameRecords
                let gameRecords = payload.gameRecords.map { $0.toGameRecord() }
                self.updateGameRecordsInFirebase(gameRecords, matchId: matchId, completion: completion)
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }

    private func updateGameRecordsInFirebase(_ records: [GameRecord], matchId: String, completion: @escaping (Bool, String?) -> Void) {
        // 先删除旧记录，再添加新记录
        db.collection("gameRecords")
            .whereField("matchId", isEqualTo: matchId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }

                let batch = self.db.batch()

                // 删除旧记录
                snapshot?.documents.forEach { doc in
                    batch.deleteDocument(doc.reference)
                }

                // 添加新记录
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

        // 先删除GameRecords
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

        // 检查名称是否已存在
        db.collection("players")
            .whereField("name", isEqualTo: player.name)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }

                if let docs = snapshot?.documents, !docs.isEmpty {
                    // 名称已存在，视为成功（幂等）
                    completion(true, nil)
                    return
                }

                // 创建玩家
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

    /// 保存对局（本地优先）
    func saveMatch(_ match: MatchRecord, gameRecords: [GameRecord], completion: ((String?) -> Void)? = nil) {
        // 生成本地ID（如果没有）
        var matchToSave = match
        let localId = match.id ?? UUID().uuidString
        matchToSave.id = localId

        // 1. 立即保存到本地缓存
        var currentMatches = matches
        currentMatches.insert(matchToSave, at: 0)
        matches = currentMatches
        localCache.cacheMatches(currentMatches)
        localCache.cacheGameRecords(gameRecords, forMatchId: localId)

        print("[SyncManager] Saved match locally: \(localId)")

        // 2. 如果在线，直接上传
        if networkMonitor.isConnected {
            createMatchInFirebase(matchToSave, gameRecords: gameRecords) { success, error in
                if success {
                    print("[SyncManager] Match uploaded to Firebase")
                } else {
                    // 上传失败，加入待处理队列
                    print("[SyncManager] Firebase upload failed, queuing operation")
                    self.pendingQueue.enqueueCreateMatch(matchToSave, gameRecords: gameRecords)
                    self.updatePendingCount()
                }
                completion?(localId)
            }
        } else {
            // 3. 离线模式，加入待处理队列
            pendingQueue.enqueueCreateMatch(matchToSave, gameRecords: gameRecords)
            updatePendingCount()
            print("[SyncManager] Offline mode, operation queued")
            completion?(localId)
        }
    }

    /// 更新对局
    func updateMatch(_ match: MatchRecord, gameRecords: [GameRecord]) {
        guard let matchId = match.id else { return }

        // 1. 更新本地缓存
        if let index = matches.firstIndex(where: { $0.id == matchId }) {
            matches[index] = match
            localCache.cacheMatches(matches)
            localCache.cacheGameRecords(gameRecords, forMatchId: matchId)
        }

        // 2. 同步到远程
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

    /// 删除对局
    func deleteMatch(matchId: String) {
        // 1. 从本地缓存删除
        matches.removeAll { $0.id == matchId }
        localCache.cacheMatches(matches)
        localCache.deleteCachedGameRecords(forMatchId: matchId)

        // 2. 同步到远程
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

    /// 加载对局的单局记录
    func loadGameRecords(forMatchId matchId: String, completion: @escaping ([GameRecord]) -> Void) {
        // 先从本地缓存加载
        let cachedRecords = localCache.loadCachedGameRecords(forMatchId: matchId)
        if !cachedRecords.isEmpty {
            completion(cachedRecords)
        }

        // 如果在线，从Firebase加载并更新缓存
        if networkMonitor.isConnected {
            db.collection("gameRecords")
                .whereField("matchId", isEqualTo: matchId)
                .getDocuments { [weak self] snapshot, error in
                    guard error == nil, let documents = snapshot?.documents else {
                        if cachedRecords.isEmpty {
                            completion([])
                        }
                        return
                    }

                    let records = documents.compactMap { doc in
                        try? doc.data(as: GameRecord.self)
                    }.sorted { $0.gameIndex < $1.gameIndex }

                    // 更新缓存
                    self?.localCache.cacheGameRecords(records, forMatchId: matchId)

                    // 如果与缓存不同，回调新数据
                    if records.count != cachedRecords.count {
                        completion(records)
                    }
                }
        } else if cachedRecords.isEmpty {
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

    /// 手动触发同步
    func forceSync() {
        guard networkMonitor.isConnected else {
            print("[SyncManager] Cannot force sync: offline")
            return
        }

        // 停止并重新启动监听
        stopFirebaseListeners()
        startFirebaseListeners()
        processPendingOperations()
    }

    /// 清除所有本地数据并重新同步
    func resetAndSync() {
        // 清除本地缓存
        localCache.clearAllCache()
        pendingQueue.clearAll()

        // 清除内存数据
        players = []
        matches = []

        // 重新初始化
        isInitialized = false
        initialize()
    }
}
