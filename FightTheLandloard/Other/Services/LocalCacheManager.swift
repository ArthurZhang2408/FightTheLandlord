//
//  LocalCacheManager.swift
//  FightTheLandlord
//
//  Local persistence for the local-first architecture. Data lives in memory and is
//  mirrored to JSON files in the Documents directory. Firestore's `@DocumentID`
//  cannot be encoded by `JSONEncoder`, hence the `Cacheable*` mirrors.
//

import Foundation

final class LocalCacheManager {
    static let shared = LocalCacheManager()

    private enum CacheKey: String {
        case players = "cached_players"
        case matches = "cached_matches"
        case gameRecords = "cached_game_records"
        case lastSyncTimestamp = "last_sync_timestamp"
        case cacheVersion = "cache_version"
        case hasCompletedFullSync = "has_completed_full_sync"
    }

    private let currentCacheVersion = 1
    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "LocalCacheManager.io", qos: .utility)
    private let lock = NSLock()

    private var cacheDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("SyncCache", isDirectory: true)
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

    // In-memory copies (guarded by `lock`).
    private var gameRecordsMemory: [GameRecord]?

    private init() {
        createCacheDirectoryIfNeeded()
        migrateIfNeeded()
    }

    // MARK: - Directory

    private func createCacheDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: cacheDirectory.path) else { return }
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            print("[LocalCache] Failed to create cache directory: \(error)")
        }
    }

    private func migrateIfNeeded() {
        let savedVersion = UserDefaults.standard.integer(forKey: CacheKey.cacheVersion.rawValue)
        if savedVersion < currentCacheVersion {
            UserDefaults.standard.set(currentCacheVersion, forKey: CacheKey.cacheVersion.rawValue)
        }
    }

    private func filePath(for key: CacheKey) -> URL {
        cacheDirectory.appendingPathComponent("\(key.rawValue).json")
    }

    // MARK: - Generic persistence

    private func writeAsync<T: Encodable>(_ value: T, to key: CacheKey) {
        let path = filePath(for: key)
        ioQueue.async { [encoder] in
            do {
                let data = try encoder.encode(value)
                try data.write(to: path, options: .atomic)
            } catch {
                print("[LocalCache] Failed to write \(key.rawValue): \(error)")
            }
        }
    }

    private func read<T: Decodable>(_ type: T.Type, from key: CacheKey) -> T? {
        let path = filePath(for: key)
        guard fileManager.fileExists(atPath: path.path) else { return nil }
        do {
            let data = try Data(contentsOf: path)
            return try decoder.decode(type, from: data)
        } catch {
            print("[LocalCache] Failed to read \(key.rawValue): \(error)")
            return nil
        }
    }

    // MARK: - Players

    func cachePlayers(_ players: [Player]) {
        writeAsync(players.map(CacheablePlayer.init), to: .players)
    }

    func loadCachedPlayers() -> [Player] {
        (read([CacheablePlayer].self, from: .players) ?? []).map { $0.player }
    }

    // MARK: - Matches

    func cacheMatches(_ matches: [MatchRecord]) {
        writeAsync(matches.map(CacheableMatch.init), to: .matches)
    }

    func loadCachedMatches() -> [MatchRecord] {
        (read([CacheableMatch].self, from: .matches) ?? []).map { $0.match }
    }

    // MARK: - Game records

    /// All cached game records (loaded from disk once, then kept in memory).
    var allGameRecords: [GameRecord] {
        lock.lock()
        defer { lock.unlock() }
        if let memory = gameRecordsMemory { return memory }
        let loaded = (read([CacheableGameRecord].self, from: .gameRecords) ?? []).map { $0.record }
        gameRecordsMemory = loaded
        return loaded
    }

    func gameRecords(forMatchId matchId: String) -> [GameRecord] {
        allGameRecords.filter { $0.matchId == matchId }.sorted { $0.gameIndex < $1.gameIndex }
    }

    /// Replace the whole cache in one write (used after a full preload).
    func replaceAllGameRecords(_ records: [GameRecord]) {
        lock.lock()
        gameRecordsMemory = records
        lock.unlock()
        writeAsync(records.map(CacheableGameRecord.init), to: .gameRecords)
    }

    /// Replace the records of one match.
    func setGameRecords(_ records: [GameRecord], forMatchId matchId: String) {
        var all = allGameRecords
        all.removeAll { $0.matchId == matchId }
        all.append(contentsOf: records)
        replaceAllGameRecords(all)
    }

    func deleteGameRecords(forMatchId matchId: String) {
        var all = allGameRecords
        all.removeAll { $0.matchId == matchId }
        replaceAllGameRecords(all)
    }

    // MARK: - Sync bookkeeping

    var lastSyncTimestamp: Date? {
        get { UserDefaults.standard.object(forKey: CacheKey.lastSyncTimestamp.rawValue) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: CacheKey.lastSyncTimestamp.rawValue) }
    }

    /// Once true, local data is trusted immediately on later launches.
    var hasCompletedFullSync: Bool {
        get { UserDefaults.standard.bool(forKey: CacheKey.hasCompletedFullSync.rawValue) }
        set { UserDefaults.standard.set(newValue, forKey: CacheKey.hasCompletedFullSync.rawValue) }
    }

    var hasCachedData: Bool {
        fileManager.fileExists(atPath: filePath(for: .players).path) ||
        fileManager.fileExists(atPath: filePath(for: .matches).path)
    }

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

    func clearAllCache() {
        lock.lock()
        gameRecordsMemory = []
        lock.unlock()
        ioQueue.sync { [self] in
            do {
                if fileManager.fileExists(atPath: cacheDirectory.path) {
                    try fileManager.removeItem(at: cacheDirectory)
                }
                createCacheDirectoryIfNeeded()
            } catch {
                print("[LocalCache] Failed to clear cache: \(error)")
            }
        }
        UserDefaults.standard.removeObject(forKey: CacheKey.lastSyncTimestamp.rawValue)
        UserDefaults.standard.removeObject(forKey: CacheKey.hasCompletedFullSync.rawValue)
    }
}

// MARK: - Cacheable mirrors

struct CacheablePlayer: Codable {
    let id: String?
    let name: String
    let createdAt: Date
    let playerColor: String?

    init(_ player: Player) {
        id = player.id
        name = player.name
        createdAt = player.createdAt
        playerColor = player.playerColor?.rawValue
    }

    var player: Player {
        Player(id: id, name: name, playerColor: playerColor.flatMap { PlayerColor(rawValue: $0) }, createdAt: createdAt)
    }
}

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
    let autoEnded: Bool?
    let lastActivityAt: Date?

    init(_ m: MatchRecord) {
        id = m.id
        startedAt = m.startedAt
        endedAt = m.endedAt
        playerAId = m.playerAId
        playerBId = m.playerBId
        playerCId = m.playerCId
        playerAName = m.playerAName
        playerBName = m.playerBName
        playerCName = m.playerCName
        finalScoreA = m.finalScoreA
        finalScoreB = m.finalScoreB
        finalScoreC = m.finalScoreC
        totalGames = m.totalGames
        maxSnapshotA = m.maxSnapshotA
        maxSnapshotB = m.maxSnapshotB
        maxSnapshotC = m.maxSnapshotC
        minSnapshotA = m.minSnapshotA
        minSnapshotB = m.minSnapshotB
        minSnapshotC = m.minSnapshotC
        initialStarter = m.initialStarter
        autoEnded = m.autoEnded
        lastActivityAt = m.lastActivityAt
    }

    var match: MatchRecord {
        MatchRecord(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            playerIds: [playerAId, playerBId, playerCId],
            playerNames: [playerAName, playerBName, playerCName],
            finalScores: [finalScoreA, finalScoreB, finalScoreC],
            totalGames: totalGames,
            maxSnapshots: [maxSnapshotA, maxSnapshotB, maxSnapshotC],
            minSnapshots: [minSnapshotA, minSnapshotB, minSnapshotC],
            initialStarter: initialStarter,
            autoEnded: autoEnded,
            lastActivityAt: lastActivityAt
        )
    }
}

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

    init(_ r: GameRecord) {
        id = r.id
        matchId = r.matchId
        gameIndex = r.gameIndex
        playedAt = r.playedAt
        playerAId = r.playerAId
        playerBId = r.playerBId
        playerCId = r.playerCId
        playerAName = r.playerAName
        playerBName = r.playerBName
        playerCName = r.playerCName
        bombs = r.bombs
        apoint = r.apoint
        bpoint = r.bpoint
        cpoint = r.cpoint
        adouble = r.adouble
        bdouble = r.bdouble
        cdouble = r.cdouble
        spring = r.spring
        landlordResult = r.landlordResult
        landlord = r.landlord
        scoreA = r.scoreA
        scoreB = r.scoreB
        scoreC = r.scoreC
        firstBidder = r.firstBidder
    }

    var record: GameRecord {
        GameRecord(
            id: id,
            matchId: matchId,
            gameIndex: gameIndex,
            playedAt: playedAt,
            playerIds: [playerAId, playerBId, playerCId],
            playerNames: [playerAName, playerBName, playerCName],
            bombs: bombs,
            bids: [apoint, bpoint, cpoint],
            doubles: [adouble, bdouble, cdouble],
            spring: spring,
            landlordResult: landlordResult,
            landlord: landlord,
            scores: [scoreA, scoreB, scoreC],
            firstBidder: firstBidder
        )
    }
}
