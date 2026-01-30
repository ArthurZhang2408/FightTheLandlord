//
//  PendingOperationQueue.swift
//  FightTheLandlord
//
//  Pending Operation Queue - Stores operations generated while offline
//  Uses operation log pattern to ensure all local operations eventually sync to cloud
//

import Foundation

/// Operation type
enum PendingOperationType: String, Codable {
    case createMatch        // Create new match
    case updateMatch        // Update match
    case deleteMatch        // Delete match
    case createPlayer       // Create player
    case updatePlayer       // Update player
    case deletePlayer       // Delete player
    case createGameRecords  // Create game records (batch)
    case updateGameRecords  // Update game records
    case deleteGameRecords  // Delete game records
}

/// Operation status
enum PendingOperationStatus: String, Codable {
    case pending    // Waiting to execute
    case inProgress // In progress
    case failed     // Failed (will retry)
    case completed  // Completed
}

/// Pending operation
struct PendingOperation: Codable, Identifiable {
    let id: String
    let type: PendingOperationType
    let createdAt: Date
    var status: PendingOperationStatus
    var retryCount: Int
    var lastError: String?
    var lastAttemptAt: Date?

    // Operation data (JSON encoded)
    let payload: Data

    // Temporary ID for association (offline-created objects may not have a real ID)
    let localId: String?

    // Dependent operation IDs (operations that must complete first)
    let dependsOn: [String]?

    init(
        type: PendingOperationType,
        payload: Data,
        localId: String? = nil,
        dependsOn: [String]? = nil
    ) {
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
}

/// Pending operation queue manager
class PendingOperationQueue {
    static let shared = PendingOperationQueue()

    // Maximum retry count
    private let maxRetryCount = 5

    // Retry delay (exponential backoff)
    private func retryDelay(for retryCount: Int) -> TimeInterval {
        return min(pow(2.0, Double(retryCount)), 60.0) // Max 60 seconds
    }

    // File manager
    private let fileManager = FileManager.default
    private var queueFilePath: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("SyncCache/pending_operations.json")
    }

    // JSON encoder/decoder
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

    // In-memory operation queue
    private var operations: [PendingOperation] = []

    // Thread-safe lock
    private let lock = NSLock()

    private init() {
        loadFromDisk()
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
            print("[PendingQueue] Loaded \(operations.count) pending operations")
        } catch {
            print("[PendingQueue] Failed to load operations: \(error)")
            operations = []
        }
    }

    private func saveToDisk() {
        do {
            // Ensure directory exists
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

    // MARK: - Queue Operations

    /// Add operation to queue
    func enqueue(_ operation: PendingOperation) {
        lock.lock()
        defer { lock.unlock() }

        operations.append(operation)
        saveToDisk()
        print("[PendingQueue] Enqueued operation: \(operation.type.rawValue) (id: \(operation.id))")
    }

    /// Get next pending operation
    func dequeue() -> PendingOperation? {
        lock.lock()
        defer { lock.unlock() }

        // Find the first operation that can be executed (status=pending and dependencies completed)
        let completedIds = Set(operations.filter { $0.status == .completed }.map { $0.id })

        for index in operations.indices {
            let op = operations[index]
            guard op.status == .pending || op.status == .failed else { continue }

            // Check retry count
            if op.retryCount >= maxRetryCount {
                continue
            }

            // Check retry delay
            if let lastAttempt = op.lastAttemptAt {
                let delay = retryDelay(for: op.retryCount)
                if Date().timeIntervalSince(lastAttempt) < delay {
                    continue
                }
            }

            // Check dependencies
            if let deps = op.dependsOn {
                let allDepsCompleted = deps.allSatisfy { completedIds.contains($0) }
                if !allDepsCompleted {
                    continue
                }
            }

            // Mark as in progress
            operations[index].status = .inProgress
            operations[index].lastAttemptAt = Date()
            saveToDisk()
            return operations[index]
        }

        return nil
    }

    /// Mark operation as completed
    func markCompleted(_ operationId: String) {
        lock.lock()
        defer { lock.unlock() }

        if let index = operations.firstIndex(where: { $0.id == operationId }) {
            operations[index].status = .completed
            saveToDisk()
            print("[PendingQueue] Operation completed: \(operationId)")
        }
    }

    /// Mark operation as failed
    func markFailed(_ operationId: String, error: String) {
        lock.lock()
        defer { lock.unlock() }

        if let index = operations.firstIndex(where: { $0.id == operationId }) {
            operations[index].status = .failed
            operations[index].retryCount += 1
            operations[index].lastError = error
            saveToDisk()
            print("[PendingQueue] Operation failed: \(operationId), retry count: \(operations[index].retryCount)")
        }
    }

    /// Remove completed operations
    func removeCompleted() {
        lock.lock()
        defer { lock.unlock() }

        let beforeCount = operations.count
        operations.removeAll { $0.status == .completed }
        saveToDisk()

        let removedCount = beforeCount - operations.count
        if removedCount > 0 {
            print("[PendingQueue] Removed \(removedCount) completed operations")
        }
    }

    /// Get count of all pending operations
    var pendingCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return operations.filter { $0.status == .pending || $0.status == .failed }.count
    }

    /// Get count of all failed operations
    var failedCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return operations.filter { $0.status == .failed && $0.retryCount >= maxRetryCount }.count
    }

    /// Check if there are pending operations
    var hasPendingOperations: Bool {
        return pendingCount > 0
    }

    /// Clear all operations
    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        operations = []
        saveToDisk()
        print("[PendingQueue] Cleared all operations")
    }

    /// Get all operations (for debugging)
    var allOperations: [PendingOperation] {
        lock.lock()
        defer { lock.unlock() }
        return operations
    }

    // MARK: - Convenience Methods for Creating Operations

    /// Create a save Match operation
    func enqueueCreateMatch(_ match: MatchRecord, gameRecords: [GameRecord]) {
        // Create Match operation payload
        struct CreateMatchPayload: Codable {
            let match: CacheableMatch
            let gameRecords: [CacheableGameRecord]
        }

        let payload = CreateMatchPayload(
            match: CacheableMatch(from: match),
            gameRecords: gameRecords.map { CacheableGameRecord(from: $0) }
        )

        do {
            let data = try encoder.encode(payload)
            let operation = PendingOperation(
                type: .createMatch,
                payload: data,
                localId: match.id
            )
            enqueue(operation)
        } catch {
            print("[PendingQueue] Failed to encode CreateMatch payload: \(error)")
        }
    }

    /// Create an update Match operation
    func enqueueUpdateMatch(_ match: MatchRecord, gameRecords: [GameRecord]) {
        struct UpdateMatchPayload: Codable {
            let match: CacheableMatch
            let gameRecords: [CacheableGameRecord]
        }

        let payload = UpdateMatchPayload(
            match: CacheableMatch(from: match),
            gameRecords: gameRecords.map { CacheableGameRecord(from: $0) }
        )

        do {
            let data = try encoder.encode(payload)
            let operation = PendingOperation(
                type: .updateMatch,
                payload: data,
                localId: match.id
            )
            enqueue(operation)
        } catch {
            print("[PendingQueue] Failed to encode UpdateMatch payload: \(error)")
        }
    }

    /// Create a delete Match operation
    func enqueueDeleteMatch(matchId: String) {
        struct DeleteMatchPayload: Codable {
            let matchId: String
        }

        let payload = DeleteMatchPayload(matchId: matchId)

        do {
            let data = try encoder.encode(payload)
            let operation = PendingOperation(
                type: .deleteMatch,
                payload: data,
                localId: matchId
            )
            enqueue(operation)
        } catch {
            print("[PendingQueue] Failed to encode DeleteMatch payload: \(error)")
        }
    }

    /// Create an add Player operation
    func enqueueCreatePlayer(_ player: Player) {
        let payload = CacheablePlayer(from: player)

        do {
            let data = try encoder.encode(payload)
            let operation = PendingOperation(
                type: .createPlayer,
                payload: data,
                localId: player.id
            )
            enqueue(operation)
        } catch {
            print("[PendingQueue] Failed to encode CreatePlayer payload: \(error)")
        }
    }

    /// Create an update Player operation
    func enqueueUpdatePlayer(_ player: Player) {
        let payload = CacheablePlayer(from: player)

        do {
            let data = try encoder.encode(payload)
            let operation = PendingOperation(
                type: .updatePlayer,
                payload: data,
                localId: player.id
            )
            enqueue(operation)
        } catch {
            print("[PendingQueue] Failed to encode UpdatePlayer payload: \(error)")
        }
    }

    /// Create a delete Player operation
    func enqueueDeletePlayer(playerId: String) {
        struct DeletePlayerPayload: Codable {
            let playerId: String
        }

        let payload = DeletePlayerPayload(playerId: playerId)

        do {
            let data = try encoder.encode(payload)
            let operation = PendingOperation(
                type: .deletePlayer,
                payload: data,
                localId: playerId
            )
            enqueue(operation)
        } catch {
            print("[PendingQueue] Failed to encode DeletePlayer payload: \(error)")
        }
    }
}
