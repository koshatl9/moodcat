//
//  DailyGoal.swift
//  felix228
//
//  Created by Codex on 12.05.2026.
//

import Foundation
import SwiftData

@Model
final class DailyGoal {
    var syncID: String?
    var createdAt: Date
    var title: String
    var lastCompletedAt: Date?
    var completionHistoryData: String?

    init(
        syncID: String? = UUID().uuidString,
        createdAt: Date = .now,
        title: String,
        lastCompletedAt: Date? = nil,
        completionHistory: [Date] = []
    ) {
        self.syncID = syncID
        self.createdAt = createdAt
        self.title = title
        let normalizedHistory = Self.normalizedCompletionHistory(
            from: completionHistory,
            fallbackLastCompletedAt: lastCompletedAt
        )
        self.lastCompletedAt = normalizedHistory.max()
        self.completionHistoryData = Self.encodeCompletionHistory(normalizedHistory)
    }

    var isCompletedToday: Bool {
        isCompleted(on: .now)
    }

    var completionHistory: [Date] {
        get {
            Self.decodeCompletionHistory(
                from: completionHistoryData,
                fallbackLastCompletedAt: lastCompletedAt
            )
        }
        set {
            let uniqueHistory = Self.uniqueSortedDates(newValue)
            lastCompletedAt = uniqueHistory.max()
            completionHistoryData = Self.encodeCompletionHistory(uniqueHistory)
        }
    }

    func isCompleted(on date: Date, calendar: Calendar = .current) -> Bool {
        completionHistory.contains { completedDate in
            calendar.isDate(completedDate, inSameDayAs: date)
        }
    }

    func setCompleted(_ completed: Bool, on date: Date = .now, calendar: Calendar = .current) {
        let normalizedDate = Self.normalizedDay(date, calendar: calendar)
        var updatedHistory = completionHistory

        if completed {
            if !updatedHistory.contains(where: { calendar.isDate($0, inSameDayAs: normalizedDate) }) {
                updatedHistory.append(normalizedDate)
            }
        } else {
            updatedHistory.removeAll { calendar.isDate($0, inSameDayAs: normalizedDate) }
        }

        let normalizedHistory = updatedHistory.sorted()
        lastCompletedAt = normalizedHistory.max()
        completionHistoryData = Self.encodeCompletionHistory(normalizedHistory)
    }

    private static func encodeCompletionHistory(_ dates: [Date]) -> String? {
        guard !dates.isEmpty else {
            return nil
        }

        guard
            let data = try? JSONEncoder().encode(dates),
            let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return string
    }

    private static func decodeCompletionHistory(
        from string: String?,
        fallbackLastCompletedAt: Date?
    ) -> [Date] {
        if
            let string,
            let data = string.data(using: .utf8),
            let dates = try? JSONDecoder().decode([Date].self, from: data)
        {
            return uniqueSortedDates(dates)
        }

        return normalizedCompletionHistory(
            from: [],
            fallbackLastCompletedAt: fallbackLastCompletedAt
        )
    }

    private static func normalizedCompletionHistory(
        from dates: [Date],
        fallbackLastCompletedAt: Date?
    ) -> [Date] {
        var uniqueDays: [Date] = []
        var seenTimestamps = Set<TimeInterval>()

        for date in dates + [fallbackLastCompletedAt].compactMap({ $0 }) {
            let normalizedDate = normalizedDay(date)
            let timestamp = normalizedDate.timeIntervalSinceReferenceDate

            if seenTimestamps.insert(timestamp).inserted {
                uniqueDays.append(normalizedDate)
            }
        }

        return uniqueDays.sorted()
    }

    private static func normalizedDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    private static func uniqueSortedDates(_ dates: [Date]) -> [Date] {
        var seenTimestamps = Set<TimeInterval>()

        return dates
            .sorted()
            .filter { date in
                let timestamp = date.timeIntervalSinceReferenceDate
                return seenTimestamps.insert(timestamp).inserted
            }
    }
}
