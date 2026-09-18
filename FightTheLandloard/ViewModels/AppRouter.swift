//
//  AppRouter.swift
//  FightTheLandlord
//
//  Cross-tab navigation requests (e.g. "open this match in History").
//

import Foundation
import Observation

enum AppTab: Int, Hashable {
    case match = 0
    case history = 1
    case stats = 2
}

struct MatchNavigationRequest: Equatable {
    let matchId: String
    let gameIndex: Int?
    let token: UUID
}

@Observable
@MainActor
final class AppRouter {
    var selectedTab: AppTab = .match
    /// Consumed by the History tab; set a new token each time so repeated
    /// requests for the same match still trigger navigation.
    var pendingMatch: MatchNavigationRequest?

    func showMatch(id: String, gameIndex: Int? = nil) {
        pendingMatch = MatchNavigationRequest(matchId: id, gameIndex: gameIndex, token: UUID())
        selectedTab = .history
    }

    func consumeMatchRequest() -> MatchNavigationRequest? {
        defer { pendingMatch = nil }
        return pendingMatch
    }
}
