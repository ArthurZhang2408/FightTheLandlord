//
//  AppSettings.swift
//  FightTheLandlord
//
//  User preferences, persisted in UserDefaults.
//

import Foundation
import Observation

@Observable
final class AppSettings {
    static let shared = AppSettings()

    private enum Key {
        static let greenWin = "settings.greenWin"
        static let scorePerGame = "settings.scorePerGame"
        static let autoFinishHours = "settings.autoFinishHours"
        static let shareDarkTheme = "settings.shareDarkTheme"
        static let haptics = "settings.haptics"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Green means winning (true) or red means winning (false, Chinese convention).
    var greenWin: Bool { didSet { defaults.set(greenWin, forKey: Key.greenWin) } }
    /// Show per-game deltas (true) or running totals (false) in game lists.
    var scorePerGame: Bool { didSet { defaults.set(scorePerGame, forKey: Key.scorePerGame) } }
    /// Hours of inactivity after which the current match is closed automatically. 0 = never.
    var autoFinishHours: Double { didSet { defaults.set(autoFinishHours, forKey: Key.autoFinishHours) } }
    /// Render share posters in the dark theme.
    var shareDarkTheme: Bool { didSet { defaults.set(shareDarkTheme, forKey: Key.shareDarkTheme) } }
    var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: Key.haptics) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        greenWin = (defaults.object(forKey: Key.greenWin) as? Bool) ?? true
        scorePerGame = (defaults.object(forKey: Key.scorePerGame) as? Bool) ?? true
        autoFinishHours = (defaults.object(forKey: Key.autoFinishHours) as? Double) ?? 2
        shareDarkTheme = (defaults.object(forKey: Key.shareDarkTheme) as? Bool) ?? false
        hapticsEnabled = (defaults.object(forKey: Key.haptics) as? Bool) ?? true
    }

    var autoFinishInterval: TimeInterval { autoFinishHours * 3600 }

    static let autoFinishOptions: [(label: String, hours: Double)] = [
        ("1小时", 1), ("2小时", 2), ("4小时", 4), ("8小时", 8), ("从不", 0)
    ]
}
