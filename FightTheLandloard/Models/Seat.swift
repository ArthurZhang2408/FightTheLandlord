//
//  Seat.swift
//  FightTheLandlord
//
//  A seat is one of the three fixed positions at the table (A, B, C).
//  Everything that is "per player in a match" is indexed by seat.
//

import Foundation

enum Seat: Int, Codable, CaseIterable, Hashable, Identifiable {
    case a = 0
    case b = 1
    case c = 2

    var id: Int { rawValue }

    /// Short label used as a fallback when no player is assigned.
    var label: String {
        switch self {
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        }
    }

    /// Fallback display name (e.g. "玩家A").
    var placeholderName: String { "玩家\(label)" }

    /// The seat that bids after this one (A → B → C → A).
    var next: Seat {
        Seat(rawValue: (rawValue + 1) % 3) ?? .a
    }

    /// The two other seats at the table, in table order.
    var others: [Seat] {
        Seat.allCases.filter { $0 != self }
    }

    /// Legacy Firestore encoding uses 1/2/3 for the landlord seat.
    var legacyLandlordValue: Int { rawValue + 1 }

    init(legacyLandlordValue value: Int) {
        self = Seat(rawValue: max(0, min(2, value - 1))) ?? .a
    }
}

// MARK: - Seat-indexed helpers

extension Array {
    /// Safe seat subscript for arrays with exactly three entries.
    subscript(seat: Seat) -> Element {
        get { self[seat.rawValue] }
        set { self[seat.rawValue] = newValue }
    }
}

extension Array where Element == Int {
    /// Convenience for score arrays: sums all three seats.
    var seatSum: Int { reduce(0, +) }
}
