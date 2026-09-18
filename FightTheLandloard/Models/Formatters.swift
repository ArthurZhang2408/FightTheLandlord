//
//  Formatters.swift
//  FightTheLandlord
//
//  Shared number and date formatting so every screen prints values the same way.
//

import Foundation

enum ScoreFormat {
    /// "+300", "-150", "0"
    static func signed(_ value: Int) -> String {
        if value > 0 { return "+\(value)" }
        return "\(value)"
    }

    /// "62.5%"
    static func percent(_ value: Double, digits: Int = 1) -> String {
        String(format: "%.\(digits)f%%", value)
    }

    /// "12.3"
    static func decimal(_ value: Double, digits: Int = 1) -> String {
        String(format: "%.\(digits)f", value)
    }

    /// "1.2万" style compaction for large totals.
    static func compact(_ value: Int) -> String {
        let magnitude = abs(value)
        guard magnitude >= 10_000 else { return signed(value) }
        let scaled = Double(value) / 10_000
        let text = String(format: "%.1f万", scaled)
        return value > 0 ? "+\(text)" : text
    }
}

enum DateFormat {
    static let dateTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日 HH:mm"
        return f
    }()

    static let shortDateTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()

    static let date: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日"
        return f
    }()

    static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f
    }()

    static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()

    static let month: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f
    }()

    static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "EEEE"
        return f
    }()

    static let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    /// "1小时20分" / "35分钟"
    static func duration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let rest = minutes % 60
        if hours > 0 {
            return rest > 0 ? "\(hours)小时\(rest)分" : "\(hours)小时"
        }
        return "\(max(minutes, 1))分钟"
    }

    /// "刚刚", "5分钟前", "2小时前", "昨天 20:15", "3月2日 20:15"
    static func relative(_ date: Date, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(Int(seconds / 60))分钟前" }
        if seconds < 6 * 3600 { return "\(Int(seconds / 3600))小时前" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天 " + time.string(from: date) }
        if calendar.isDateInYesterday(date) { return "昨天 " + time.string(from: date) }
        return shortDateTime.string(from: date)
    }
}
