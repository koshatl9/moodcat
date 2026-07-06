//
//  EmotionAnalytics.swift
//  felix228
//
//  Created by Codex on 12.05.2026.
//

import Foundation

enum EmotionAnalytics {
    static func entries(
        onSameDayAs referenceDate: Date,
        in entries: [EmotionEntry],
        calendar: Calendar = .current
    ) -> [EmotionEntry] {
        entries.filter { calendar.isDate($0.createdAt, inSameDayAs: referenceDate) }
    }

    static func averageIntensity(in entries: [EmotionEntry]) -> Double? {
        guard !entries.isEmpty else { return nil }

        let total = entries.reduce(0) { partialResult, entry in
            partialResult + entry.intensity
        }

        return total / Double(entries.count)
    }

    static func averageIntensityToday(
        in entries: [EmotionEntry],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> Double? {
        averageIntensity(in: self.entries(onSameDayAs: now, in: entries, calendar: calendar))
    }

    static func dominantMood(in entries: [EmotionEntry]) -> Mood? {
        guard !entries.isEmpty else { return nil }

        let groupedEntries = Dictionary(grouping: entries, by: \.moodID)

        return groupedEntries
            .map { moodID, entries in
                (
                    mood: Mood(storageValue: moodID),
                    count: entries.count,
                    latestEntry: entries.map(\.createdAt).max() ?? .distantPast
                )
            }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }

                return lhs.latestEntry > rhs.latestEntry
            }
            .first?
            .mood
    }

    static func currentEntryStreak(
        in entries: [EmotionEntry],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> Int {
        let entryDays = Set(entries.map { calendar.startOfDay(for: $0.createdAt) })
        var currentDay = calendar.startOfDay(for: now)
        var streak = 0

        while entryDays.contains(currentDay) {
            streak += 1

            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else {
                break
            }

            currentDay = previousDay
        }

        return streak
    }
}
