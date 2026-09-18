//
//  DataStore.swift
//  FightTheLandlord
//
//  Main-actor facade over the sync layer. Views read from here; all mutations go
//  through here. Statistics are computed on demand from the in-memory records.
//

import Foundation
import Combine
import Observation

enum DataStoreError: LocalizedError {
    case duplicatePlayerName
    case invalidPlayer

    var errorDescription: String? {
        switch self {
        case .duplicatePlayerName: return "已存在同名玩家"
        case .invalidPlayer: return "玩家信息无效"
        }
    }
}

@Observable
@MainActor
final class DataStore {
    static let shared = DataStore()

    private(set) var players: [Player] = []
    private(set) var matches: [MatchRecord] = []
    private(set) var gameRecords: [GameRecord] = []
    private(set) var isOnline: Bool = true
    private(set) var syncStatus: SyncStatus = .idle
    private(set) var pendingOperationsCount: Int = 0
    private(set) var gameRecordsSyncState: GameRecordsSyncState = .loading
    private(set) var hasLoadedInitialData: Bool = false
    private(set) var lastSyncTime: Date?

    @ObservationIgnored private let sync = SyncManager.shared
    @ObservationIgnored private let network = NetworkMonitor.shared
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    private init() {
        bind()
        sync.initialize()
        // Publishers deliver asynchronously; mirror the cached state right away so the
        // first frame already has players and matches.
        players = sync.players
        matches = sync.matches
        gameRecords = sync.gameRecords
        syncStatus = sync.syncStatus
        pendingOperationsCount = sync.pendingOperationsCount
        gameRecordsSyncState = sync.gameRecordsSyncState
        hasLoadedInitialData = sync.hasLoadedInitialData
        lastSyncTime = sync.lastSyncTime
        isOnline = network.isConnected
    }

    private func bind() {
        func observe<T>(_ publisher: Published<T>.Publisher, _ apply: @escaping @MainActor (DataStore, T) -> Void) {
            publisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    MainActor.assumeIsolated {
                        guard let self = self else { return }
                        apply(self, value)
                    }
                }
                .store(in: &cancellables)
        }
        observe(sync.$players) { $0.players = $1 }
        observe(sync.$matches) { $0.matches = $1 }
        observe(sync.$gameRecords) { $0.gameRecords = $1 }
        observe(sync.$syncStatus) { $0.syncStatus = $1 }
        observe(sync.$pendingOperationsCount) { $0.pendingOperationsCount = $1 }
        observe(sync.$gameRecordsSyncState) { $0.gameRecordsSyncState = $1 }
        observe(sync.$hasLoadedInitialData) { $0.hasLoadedInitialData = $1 }
        observe(sync.$lastSyncTime) { $0.lastSyncTime = $1 }
        observe(network.$isConnected) { $0.isOnline = $1 }
    }

    // MARK: - Queries

    var connectionDescription: String {
        isOnline ? network.connectionTypeDescription : "未连接"
    }

    var isInitialLoading: Bool {
        !hasLoadedInitialData && players.isEmpty && matches.isEmpty
    }

    func player(id: String?) -> Player? {
        guard let id = id else { return nil }
        return players.first { $0.id == id }
    }

    func match(id: String?) -> MatchRecord? {
        guard let id = id else { return nil }
        return matches.first { $0.id == id }
    }

    func records(forMatch matchId: String?) -> [GameRecord] {
        guard let matchId = matchId else { return [] }
        return gameRecords.filter { $0.matchId == matchId }.sorted { $0.gameIndex < $1.gameIndex }
    }

    func records(forPlayer playerId: String) -> [GameRecord] {
        gameRecords.filter { $0.seat(of: playerId) != nil }
    }

    func matches(forPlayer playerId: String) -> [MatchRecord] {
        matches.filter { $0.seat(of: playerId) != nil }
    }

    /// Display names by player id (current names win over the ones stored in records).
    var playerNameLookup: [String: String] {
        var lookup: [String: String] = [:]
        for player in players {
            if let id = player.id { lookup[id] = player.name }
        }
        return lookup
    }

    func statistics(for player: Player) -> PlayerStatistics? {
        guard let id = player.id else { return nil }
        return PlayerStatsEngine.compute(
            playerId: id,
            playerName: player.name,
            gameRecords: records(forPlayer: id),
            matchRecords: matches(forPlayer: id),
            playerNames: playerNameLookup
        )
    }

    func matchStatistics(for match: MatchRecord) -> MatchStatistics {
        MatchStatsEngine.compute(match: match, records: records(forMatch: match.id))
    }

    func leaderboard() -> [LeaderboardEntry] {
        Leaderboard.compute(players: players, gameRecords: gameRecords, matchRecords: matches)
    }

    /// Makes sure a match's records are available (older devices may not have them cached).
    func ensureRecordsLoaded(forMatch matchId: String?) {
        guard let matchId = matchId else { return }
        sync.refreshGameRecordsIfMissing(forMatchId: matchId)
    }

    // MARK: - Players

    @discardableResult
    func addPlayer(name: String, color: PlayerColor) throws -> Player {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DataStoreError.invalidPlayer }
        guard !players.contains(where: { $0.name == trimmed }) else { throw DataStoreError.duplicatePlayerName }
        let player = Player(id: UUID().uuidString, name: trimmed, playerColor: color)
        sync.addPlayer(player)
        return player
    }

    func updatePlayer(_ player: Player) {
        sync.updatePlayer(player)
    }

    func deletePlayer(id: String) {
        sync.deletePlayer(id: id)
    }

    // MARK: - Matches

    /// Creates or updates a match in history together with its games.
    func saveMatch(_ record: MatchRecord, games: [Game]) {
        guard let matchId = record.id else { return }
        let records = games.enumerated().map { index, game in
            GameRecord(game: game, matchId: matchId, gameIndex: index,
                       playerIds: record.playerIds, playerNames: record.playerNames)
        }
        sync.upsertMatch(record, records: records)
    }

    func deleteMatch(id: String) {
        sync.deleteMatch(matchId: id)
    }

    // MARK: - Sync controls

    func forceSync() { sync.forceSync() }
    func resetAndSync() { sync.resetAndSync() }
}
