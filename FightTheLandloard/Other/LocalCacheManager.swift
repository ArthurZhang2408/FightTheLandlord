//
//  LocalCacheManager.swift
//  FightTheLandlord
//
//  本地缓存管理器 - 负责数据的本地持久化存储
//  采用 Local-First 架构，数据优先存储在本地，后台同步到云端
//

import Foundation

/// 本地缓存管理器 - 单例模式
/// 职责：管理所有本地数据的持久化存储
class LocalCacheManager {
    static let shared = LocalCacheManager()

    // MARK: - Cache Keys
    private enum CacheKey: String {
        case players = "cached_players"
        case matches = "cached_matches"
        case gameRecords = "cached_game_records"
        case lastSyncTimestamp = "last_sync_timestamp"
        case cacheVersion = "cache_version"
    }

    // 缓存版本，用于处理数据结构升级
    private let currentCacheVersion = 1

    // 文件管理器
    private let fileManager = FileManager.default

    // 缓存目录
    private var cacheDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("SyncCache", isDirectory: true)
    }

    // JSON编解码器
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private init() {
        createCacheDirectoryIfNeeded()
        migrateIfNeeded()
    }

    // MARK: - Directory Management

    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            do {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                print("[LocalCache] Created cache directory at \(cacheDirectory.path)")
            } catch {
                print("[LocalCache] Failed to create cache directory: \(error)")
            }
        }
    }

    private func migrateIfNeeded() {
        let savedVersion = UserDefaults.standard.integer(forKey: CacheKey.cacheVersion.rawValue)
        if savedVersion < currentCacheVersion {
            // 执行迁移逻辑
            print("[LocalCache] Migrating cache from version \(savedVersion) to \(currentCacheVersion)")
            UserDefaults.standard.set(currentCacheVersion, forKey: CacheKey.cacheVersion.rawValue)
        }
    }

    // MARK: - File Paths

    private func filePath(for key: CacheKey) -> URL {
        return cacheDirectory.appendingPathComponent("\(key.rawValue).json")
    }

    // MARK: - Generic Save/Load

    private func save<T: Encodable>(_ data: T, to key: CacheKey) throws {
        let path = filePath(for: key)
        let jsonData = try encoder.encode(data)
        try jsonData.write(to: path, options: .atomic)
        print("[LocalCache] Saved \(key.rawValue) (\(jsonData.count) bytes)")
    }

    private func load<T: Decodable>(_ type: T.Type, from key: CacheKey) throws -> T? {
        let path = filePath(for: key)
        guard fileManager.fileExists(atPath: path.path) else {
            return nil
        }
        let jsonData = try Data(contentsOf: path)
        return try decoder.decode(type, from: jsonData)
    }

    // MARK: - Players Cache

    /// 缓存玩家列表
    func cachePlayers(_ players: [Player]) {
        do {
            let cacheable = players.map { CacheablePlayer(from: $0) }
            try save(cacheable, to: .players)
        } catch {
            print("[LocalCache] Failed to cache players: \(error)")
        }
    }

    /// 加载缓存的玩家列表
    func loadCachedPlayers() -> [Player] {
        do {
            if let cached: [CacheablePlayer] = try load([CacheablePlayer].self, from: .players) {
                print("[LocalCache] Loaded \(cached.count) cached players")
                return cached.map { $0.toPlayer() }
            }
        } catch {
            print("[LocalCache] Failed to load cached players: \(error)")
        }
        return []
    }

    // MARK: - Matches Cache

    /// 缓存对局列表
    func cacheMatches(_ matches: [MatchRecord]) {
        do {
            let cacheable = matches.map { CacheableMatch(from: $0) }
            try save(cacheable, to: .matches)
        } catch {
            print("[LocalCache] Failed to cache matches: \(error)")
        }
    }

    /// 加载缓存的对局列表
    func loadCachedMatches() -> [MatchRecord] {
        do {
            if let cached: [CacheableMatch] = try load([CacheableMatch].self, from: .matches) {
                print("[LocalCache] Loaded \(cached.count) cached matches")
                return cached.map { $0.toMatchRecord() }
            }
        } catch {
            print("[LocalCache] Failed to load cached matches: \(error)")
        }
        return []
    }

    // MARK: - Game Records Cache

    /// 缓存单局记录（按matchId分组存储）
    func cacheGameRecords(_ records: [GameRecord], forMatchId matchId: String) {
        var allRecords = loadAllCachedGameRecords()

        // 移除该match的旧记录
        allRecords.removeAll { $0.matchId == matchId }

        // 添加新记录
        allRecords.append(contentsOf: records)

        do {
            let cacheable = allRecords.map { CacheableGameRecord(from: $0) }
            try save(cacheable, to: .gameRecords)
        } catch {
            print("[LocalCache] Failed to cache game records: \(error)")
        }
    }

    /// 加载特定对局的单局记录
    func loadCachedGameRecords(forMatchId matchId: String) -> [GameRecord] {
        let allRecords = loadAllCachedGameRecords()
        return allRecords.filter { $0.matchId == matchId }.sorted { $0.gameIndex < $1.gameIndex }
    }

    /// 加载所有缓存的单局记录
    func loadAllCachedGameRecords() -> [GameRecord] {
        do {
            if let cached: [CacheableGameRecord] = try load([CacheableGameRecord].self, from: .gameRecords) {
                return cached.map { $0.toGameRecord() }
            }
        } catch {
            print("[LocalCache] Failed to load cached game records: \(error)")
        }
        return []
    }

    /// 删除特定对局的缓存记录
    func deleteCachedGameRecords(forMatchId matchId: String) {
        var allRecords = loadAllCachedGameRecords()
        allRecords.removeAll { $0.matchId == matchId }

        do {
            let cacheable = allRecords.map { CacheableGameRecord(from: $0) }
            try save(cacheable, to: .gameRecords)
        } catch {
            print("[LocalCache] Failed to delete cached game records: \(error)")
        }
    }

    // MARK: - Sync Timestamp

    /// 获取上次同步时间戳
    var lastSyncTimestamp: Date? {
        get {
            return UserDefaults.standard.object(forKey: CacheKey.lastSyncTimestamp.rawValue) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: CacheKey.lastSyncTimestamp.rawValue)
        }
    }

    // MARK: - Cache Status

    /// 检查是否有本地缓存
    var hasCachedData: Bool {
        let playersPath = filePath(for: .players)
        let matchesPath = filePath(for: .matches)
        return fileManager.fileExists(atPath: playersPath.path) ||
               fileManager.fileExists(atPath: matchesPath.path)
    }

    /// 获取缓存大小（字节）
    var cacheSize: Int64 {
        var size: Int64 = 0
        if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        return size
    }

    /// 清空所有缓存
    func clearAllCache() {
        do {
            if fileManager.fileExists(atPath: cacheDirectory.path) {
                try fileManager.removeItem(at: cacheDirectory)
                createCacheDirectoryIfNeeded()
                print("[LocalCache] Cleared all cache")
            }
            UserDefaults.standard.removeObject(forKey: CacheKey.lastSyncTimestamp.rawValue)
        } catch {
            print("[LocalCache] Failed to clear cache: \(error)")
        }
    }
}

// MARK: - Cacheable Models

/// 可缓存的Player模型（不依赖Firebase的@DocumentID）
struct CacheablePlayer: Codable {
    let id: String?
    let name: String
    let createdAt: Date
    let playerColor: String?

    init(from player: Player) {
        self.id = player.id
        self.name = player.name
        self.createdAt = player.createdAt
        self.playerColor = player.playerColor?.rawValue
    }

    func toPlayer() -> Player {
        var player = Player(id: id, name: name, playerColor: playerColor.flatMap { PlayerColor(rawValue: $0) })
        player.createdAt = createdAt
        return player
    }
}

/// 可缓存的MatchRecord模型
struct CacheableMatch: Codable {
    let id: String?
    let startedAt: Date
    let endedAt: Date?
    let playerAId: String
    let playerBId: String
    let playerCId: String
    let playerAName: String
    let playerBName: String
    let playerCName: String
    let finalScoreA: Int
    let finalScoreB: Int
    let finalScoreC: Int
    let totalGames: Int
    let maxSnapshotA: Int
    let maxSnapshotB: Int
    let maxSnapshotC: Int
    let minSnapshotA: Int
    let minSnapshotB: Int
    let minSnapshotC: Int
    let initialStarter: Int

    init(from match: MatchRecord) {
        self.id = match.id
        self.startedAt = match.startedAt
        self.endedAt = match.endedAt
        self.playerAId = match.playerAId
        self.playerBId = match.playerBId
        self.playerCId = match.playerCId
        self.playerAName = match.playerAName
        self.playerBName = match.playerBName
        self.playerCName = match.playerCName
        self.finalScoreA = match.finalScoreA
        self.finalScoreB = match.finalScoreB
        self.finalScoreC = match.finalScoreC
        self.totalGames = match.totalGames
        self.maxSnapshotA = match.maxSnapshotA
        self.maxSnapshotB = match.maxSnapshotB
        self.maxSnapshotC = match.maxSnapshotC
        self.minSnapshotA = match.minSnapshotA
        self.minSnapshotB = match.minSnapshotB
        self.minSnapshotC = match.minSnapshotC
        self.initialStarter = match.initialStarter
    }

    func toMatchRecord() -> MatchRecord {
        var match = MatchRecord(
            playerAId: playerAId,
            playerBId: playerBId,
            playerCId: playerCId,
            playerAName: playerAName,
            playerBName: playerBName,
            playerCName: playerCName,
            starter: initialStarter
        )
        // 使用反射或直接赋值来设置私有属性
        // 由于 MatchRecord 是结构体，我们需要一个特殊的初始化方法
        match = MatchRecord.fromCache(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            playerAId: playerAId,
            playerBId: playerBId,
            playerCId: playerCId,
            playerAName: playerAName,
            playerBName: playerBName,
            playerCName: playerCName,
            finalScoreA: finalScoreA,
            finalScoreB: finalScoreB,
            finalScoreC: finalScoreC,
            totalGames: totalGames,
            maxSnapshotA: maxSnapshotA,
            maxSnapshotB: maxSnapshotB,
            maxSnapshotC: maxSnapshotC,
            minSnapshotA: minSnapshotA,
            minSnapshotB: minSnapshotB,
            minSnapshotC: minSnapshotC,
            initialStarter: initialStarter
        )
        return match
    }
}

/// 可缓存的GameRecord模型
struct CacheableGameRecord: Codable {
    let id: String?
    let matchId: String
    let gameIndex: Int
    let playedAt: Date
    let playerAId: String
    let playerBId: String
    let playerCId: String
    let playerAName: String
    let playerBName: String
    let playerCName: String
    let bombs: Int
    let apoint: Int
    let bpoint: Int
    let cpoint: Int
    let adouble: Bool
    let bdouble: Bool
    let cdouble: Bool
    let spring: Bool?
    let landlordResult: Bool
    let landlord: Int
    let scoreA: Int
    let scoreB: Int
    let scoreC: Int
    let firstBidder: Int?

    init(from record: GameRecord) {
        self.id = record.id
        self.matchId = record.matchId
        self.gameIndex = record.gameIndex
        self.playedAt = record.playedAt
        self.playerAId = record.playerAId
        self.playerBId = record.playerBId
        self.playerCId = record.playerCId
        self.playerAName = record.playerAName
        self.playerBName = record.playerBName
        self.playerCName = record.playerCName
        self.bombs = record.bombs
        self.apoint = record.apoint
        self.bpoint = record.bpoint
        self.cpoint = record.cpoint
        self.adouble = record.adouble
        self.bdouble = record.bdouble
        self.cdouble = record.cdouble
        self.spring = record.spring
        self.landlordResult = record.landlordResult
        self.landlord = record.landlord
        self.scoreA = record.scoreA
        self.scoreB = record.scoreB
        self.scoreC = record.scoreC
        self.firstBidder = record.firstBidder
    }

    func toGameRecord() -> GameRecord {
        return GameRecord.fromCache(
            id: id,
            matchId: matchId,
            gameIndex: gameIndex,
            playedAt: playedAt,
            playerAId: playerAId,
            playerBId: playerBId,
            playerCId: playerCId,
            playerAName: playerAName,
            playerBName: playerBName,
            playerCName: playerCName,
            bombs: bombs,
            apoint: apoint,
            bpoint: bpoint,
            cpoint: cpoint,
            adouble: adouble,
            bdouble: bdouble,
            cdouble: cdouble,
            spring: spring,
            landlordResult: landlordResult,
            landlord: landlord,
            scoreA: scoreA,
            scoreB: scoreB,
            scoreC: scoreC,
            firstBidder: firstBidder
        )
    }
}
