//
//  PendingOperationQueue.swift
//  FightTheLandlord
//
//  待处理操作队列 - 存储离线时产生的操作，等待网络恢复后执行
//  采用操作日志模式，确保所有本地操作最终同步到云端
//

import Foundation

/// 操作类型
enum PendingOperationType: String, Codable {
    case createMatch        // 创建新对局
    case updateMatch        // 更新对局
    case deleteMatch        // 删除对局
    case createPlayer       // 创建玩家
    case updatePlayer       // 更新玩家
    case deletePlayer       // 删除玩家
    case createGameRecords  // 创建单局记录（批量）
    case updateGameRecords  // 更新单局记录
    case deleteGameRecords  // 删除单局记录
}

/// 操作状态
enum PendingOperationStatus: String, Codable {
    case pending    // 等待执行
    case inProgress // 执行中
    case failed     // 执行失败（将重试）
    case completed  // 已完成
}

/// 待处理操作
struct PendingOperation: Codable, Identifiable {
    let id: String
    let type: PendingOperationType
    let createdAt: Date
    var status: PendingOperationStatus
    var retryCount: Int
    var lastError: String?
    var lastAttemptAt: Date?

    // 操作数据（JSON编码）
    let payload: Data

    // 用于关联的临时ID（离线创建的对象可能没有真正的ID）
    let localId: String?

    // 依赖的操作ID（必须先完成的操作）
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

/// 待处理操作队列管理器
class PendingOperationQueue {
    static let shared = PendingOperationQueue()

    // 最大重试次数
    private let maxRetryCount = 5

    // 重试延迟（指数退避）
    private func retryDelay(for retryCount: Int) -> TimeInterval {
        return min(pow(2.0, Double(retryCount)), 60.0) // 最大60秒
    }

    // 文件管理
    private let fileManager = FileManager.default
    private var queueFilePath: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("SyncCache/pending_operations.json")
    }

    // JSON编解码器
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

    // 内存中的操作队列
    private var operations: [PendingOperation] = []

    // 线程安全锁
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
            // 确保目录存在
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

    /// 添加操作到队列
    func enqueue(_ operation: PendingOperation) {
        lock.lock()
        defer { lock.unlock() }

        operations.append(operation)
        saveToDisk()
        print("[PendingQueue] Enqueued operation: \(operation.type.rawValue) (id: \(operation.id))")
    }

    /// 获取下一个待处理的操作
    func dequeue() -> PendingOperation? {
        lock.lock()
        defer { lock.unlock() }

        // 找到第一个可以执行的操作（status=pending 且依赖已完成）
        let completedIds = Set(operations.filter { $0.status == .completed }.map { $0.id })

        for index in operations.indices {
            let op = operations[index]
            guard op.status == .pending || op.status == .failed else { continue }

            // 检查重试次数
            if op.retryCount >= maxRetryCount {
                continue
            }

            // 检查重试延迟
            if let lastAttempt = op.lastAttemptAt {
                let delay = retryDelay(for: op.retryCount)
                if Date().timeIntervalSince(lastAttempt) < delay {
                    continue
                }
            }

            // 检查依赖
            if let deps = op.dependsOn {
                let allDepsCompleted = deps.allSatisfy { completedIds.contains($0) }
                if !allDepsCompleted {
                    continue
                }
            }

            // 标记为进行中
            operations[index].status = .inProgress
            operations[index].lastAttemptAt = Date()
            saveToDisk()
            return operations[index]
        }

        return nil
    }

    /// 标记操作完成
    func markCompleted(_ operationId: String) {
        lock.lock()
        defer { lock.unlock() }

        if let index = operations.firstIndex(where: { $0.id == operationId }) {
            operations[index].status = .completed
            saveToDisk()
            print("[PendingQueue] Operation completed: \(operationId)")
        }
    }

    /// 标记操作失败
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

    /// 移除已完成的操作
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

    /// 获取所有待处理操作数量
    var pendingCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return operations.filter { $0.status == .pending || $0.status == .failed }.count
    }

    /// 获取所有失败操作数量
    var failedCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return operations.filter { $0.status == .failed && $0.retryCount >= maxRetryCount }.count
    }

    /// 是否有待处理操作
    var hasPendingOperations: Bool {
        return pendingCount > 0
    }

    /// 清空所有操作
    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        operations = []
        saveToDisk()
        print("[PendingQueue] Cleared all operations")
    }

    /// 获取所有操作（用于调试）
    var allOperations: [PendingOperation] {
        lock.lock()
        defer { lock.unlock() }
        return operations
    }

    // MARK: - Convenience Methods for Creating Operations

    /// 创建保存Match的操作
    func enqueueCreateMatch(_ match: MatchRecord, gameRecords: [GameRecord]) {
        // 创建Match操作的payload
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

    /// 创建更新Match的操作
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

    /// 创建删除Match的操作
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

    /// 创建添加Player的操作
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

    /// 创建更新Player的操作
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

    /// 创建删除Player的操作
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
