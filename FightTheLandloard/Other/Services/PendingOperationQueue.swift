//
//  PendingOperationQueue.swift
//  FightTheLandlord
//
//  Operation log for work that could not reach Firestore (offline or failed).
//  Operations are persisted to disk and replayed with exponential backoff.
//

import Foundation

enum PendingOperationType: String, Codable {
    case createMatch
    case updateMatch
    case deleteMatch
    case createPlayer
    case updatePlayer
    case deletePlayer
    case createGameRecords
    case updateGameRecords
    case deleteGameRecords
}

enum PendingOperationStatus: String, Codable {
    case pending
    case inProgress
    case failed
    case completed
}

struct PendingOperation: Codable, Identifiable {
    let id: String
    let type: PendingOperationType
    let createdAt: Date
    var status: PendingOperationStatus
    var retryCount: Int
    var lastError: String?
    var lastAttemptAt: Date?
    let payload: Data
    let localId: String?
    let dependsOn: [String]?

    init(type: PendingOperationType, payload: Data, localId: String? = nil, dependsOn: [String]? = nil) {
        self.id = UUID().uuidString
        self.type = type
        self.createdAt = Date()
        self.status = .pending
        self.retryCount = 0
        self.lastError = nil
        self.lastAttemptAt = nil
        self.payload = payload
        self.localId = localId
        self.dependsOn = dependsOn
    }

    var isOpen: Bool { status == .pending || status == .inProgress || status == .failed }
}

/// Payload shared by create/update match operations.
struct MatchOperationPayload: Codable {
    let match: CacheableMatch
    let gameRecords: [CacheableGameRecord]
}

struct IdPayload: Codable {
    let id: String
}

final class PendingOperationQueue {
    static let shared = PendingOperationQueue()

    private let maxRetryCount = 5
    private let fileManager = FileManager.default
    private let lock = NSLock()
    private var operations: [PendingOperation] = []

    private var queueFilePath: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("SyncCache/pending_operations.json")
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private init() {
        loadFromDisk()
    }

    private func retryDelay(for retryCount: Int) -> TimeInterval {
        min(pow(2.0, Double(retryCount)), 60.0)
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard fileManager.fileExists(atPath: queueFilePath.path) else {
            operations = []
            return
        }
        do {
            let data = try Data(contentsOf: queueFilePath)
            operations = try decoder.decode([PendingOperation].self, from: data)
        } catch {
            print("[PendingQueue] Failed to load operations: \(error)")
            operations = []
        }
    }

    private func saveToDisk() {
        do {
            let directory = queueFilePath.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let data = try encoder.encode(operations)
            try data.write(to: queueFilePath, options: .atomic)
        } catch {
            print("[PendingQueue] Failed to save operations: \(error)")
        }
    }

    // MARK: - Queue

    func enqueue(_ operation: PendingOperation) {
        lock.lock()
        defer { lock.unlock() }
        operations.append(operation)
        saveToDisk()
    }

    /// Next operation that is ready to run, marked in progress.
    func dequeue() -> PendingOperation? {
        lock.lock()
        defer { lock.unlock() }
        let completedIds = Set(operations.filter { $0.status == .completed }.map { $0.id })

        for index in operations.indices {
            let op = operations[index]
            guard op.status == .pending || op.status == .failed else { continue }
            guard op.retryCount < maxRetryCount else { continue }
            if let lastAttempt = op.lastAttemptAt,
               Date().timeIntervalSince(lastAttempt) < retryDelay(for: op.retryCount) {
                continue
            }
            if let deps = op.dependsOn, !deps.allSatisfy({ completedIds.contains($0) }) {
                continue
            }
            operations[index].status = .inProgress
            operations[index].lastAttemptAt = Date()
            saveToDisk()
            return operations[index]
        }
        return nil
    }

    func markCompleted(_ operationId: String) {
        lock.lock()
        defer { lock.unlock() }
        if let index = operations.firstIndex(where: { $0.id == operationId }) {
            operations[index].status = .completed
            saveToDisk()
        }
    }

    func markFailed(_ operationId: String, error: String) {
        lock.lock()
        defer { lock.unlock() }
        if let index = operations.firstIndex(where: { $0.id == operationId }) {
            operations[index].status = .failed
            operations[index].retryCount += 1
            operations[index].lastError = error
            saveToDisk()
        }
    }

    func removeCompleted() {
        lock.lock()
        defer { lock.unlock() }
        operations.removeAll { $0.status == .completed }
        saveToDisk()
    }

    /// Drops older open operations that target the same match/player so only the
    /// latest state is uploaded.
    func supersedeOperations(localId: String, types: Set<PendingOperationType>) {
        lock.lock()
        defer { lock.unlock() }
        operations.removeAll { $0.localId == localId && types.contains($0.type) && $0.status != .inProgress }
        saveToDisk()
    }

    /// Operations that will still be attempted (exhausted ones are not counted).
    var pendingCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return operations.filter { ($0.status == .pending || $0.status == .failed) && $0.retryCount < maxRetryCount }.count
    }

    /// Gives exhausted operations another chance (e.g. after the network came back).
    func resetRetries() {
        lock.lock()
        defer { lock.unlock() }
        for index in operations.indices where operations[index].status == .failed {
            operations[index].retryCount = 0
            operations[index].lastAttemptAt = nil
        }
        saveToDisk()
    }

    var hasPendingOperations: Bool { pendingCount > 0 }

    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        operations = []
        saveToDisk()
    }

    var allOperations: [PendingOperation] {
        lock.lock()
        defer { lock.unlock() }
        return operations
    }

    // MARK: - Builders

    private func encodeAndEnqueue<T: Encodable>(_ payload: T, type: PendingOperationType, localId: String?) {
        do {
            let data = try encoder.encode(payload)
            enqueue(PendingOperation(type: type, payload: data, localId: localId))
        } catch {
            print("[PendingQueue] Failed to encode \(type.rawValue) payload: \(error)")
        }
    }

    func enqueueUpsertMatch(_ match: MatchRecord, gameRecords: [GameRecord]) {
        if let id = match.id {
            supersedeOperations(localId: id, types: [.createMatch, .updateMatch])
        }
        let payload = MatchOperationPayload(match: CacheableMatch(match), gameRecords: gameRecords.map(CacheableGameRecord.init))
        encodeAndEnqueue(payload, type: .updateMatch, localId: match.id)
    }

    func enqueueDeleteMatch(matchId: String) {
        supersedeOperations(localId: matchId, types: [.createMatch, .updateMatch, .deleteMatch])
        encodeAndEnqueue(IdPayload(id: matchId), type: .deleteMatch, localId: matchId)
    }

    func enqueueCreatePlayer(_ player: Player) {
        encodeAndEnqueue(CacheablePlayer(player), type: .createPlayer, localId: player.id)
    }

    func enqueueUpdatePlayer(_ player: Player) {
        if let id = player.id { supersedeOperations(localId: id, types: [.updatePlayer]) }
        encodeAndEnqueue(CacheablePlayer(player), type: .updatePlayer, localId: player.id)
    }

    func enqueueDeletePlayer(playerId: String) {
        supersedeOperations(localId: playerId, types: [.createPlayer, .updatePlayer])
        encodeAndEnqueue(IdPayload(id: playerId), type: .deletePlayer, localId: playerId)
    }

    // MARK: - Decoding helpers

    func decodeMatchPayload(_ op: PendingOperation) -> MatchOperationPayload? {
        try? decoder.decode(MatchOperationPayload.self, from: op.payload)
    }

    func decodePlayerPayload(_ op: PendingOperation) -> Player? {
        (try? decoder.decode(CacheablePlayer.self, from: op.payload))?.player
    }

    func decodeIdPayload(_ op: PendingOperation) -> String? {
        if let payload = try? decoder.decode(IdPayload.self, from: op.payload) { return payload.id }
        // Legacy payload shapes.
        struct LegacyMatch: Codable { let matchId: String }
        struct LegacyPlayer: Codable { let playerId: String }
        if let legacy = try? decoder.decode(LegacyMatch.self, from: op.payload) { return legacy.matchId }
        if let legacy = try? decoder.decode(LegacyPlayer.self, from: op.payload) { return legacy.playerId }
        return op.localId
    }
}
