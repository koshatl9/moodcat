//
//  felix228Tests.swift
//  felix228Tests
//
//  Created by Dasha Stepanova on 12.05.2026.
//

import Foundation
import Testing
@testable import felix228

struct felix228Tests {
    @Test func themeRestoresFromStoredValue() {
        #expect(AppTheme(storageValue: "dark") == .dark)
        #expect(AppTheme(storageValue: "unknown") == .light)
        #expect(AppTheme.light.next == .dark)
    }

    @Test func reminderMessageFallsBackToDefaultWhenBlank() {
        #expect(JournalReminderManager.normalizedMessage("") == JournalReminderManager.defaultMessage)
        #expect(JournalReminderManager.normalizedMessage("   \n ") == JournalReminderManager.defaultMessage)
        #expect(JournalReminderManager.normalizedMessage("  Вечером заполни дневник  ") == "Вечером заполни дневник")
    }

    @Test func legacyMoodValuesMapToNewMoodSet() {
        #expect(Mood(storageValue: "joyful") == .superb)
        #expect(Mood(storageValue: "grateful") == .superb)
        #expect(Mood(storageValue: "calm") == .normal)
        #expect(Mood(storageValue: "anxious") == .soSo)
        #expect(Mood(storageValue: "sad") == .bad)
        #expect(Mood(storageValue: "angry") == .bad)
        #expect(Mood(storageValue: "unknown") == .normal)
    }

    @MainActor
    @Test func moodCustomizationPersistsThemeAndCustomTitles() {
        let suiteName = "felix228Tests.moodCustomization"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let manager = MoodCustomizationManager(defaults: defaults)
        manager.apply(
            theme: .kittySlime,
            titlesByMood: [
                .normal: "Хорошо",
                .superb: "Обожаю"
            ]
        )

        #expect(manager.selectedTheme == .kittySlime)
        #expect(manager.title(for: .normal) == "Хорошо")
        #expect(manager.title(for: .superb) == "Обожаю")
        #expect(manager.artworkAssetName(for: .bad) == "KittySlimeBadMood")

        manager.apply(
            theme: .kittyMoji,
            titlesByMood: [
                .normal: "Спокойно"
            ]
        )

        #expect(manager.selectedTheme == .kittyMoji)
        #expect(manager.artworkAssetName(for: .superb) == "KittyMojiSuperMood")
        #expect(manager.effectiveTheme(hasPremiumAccess: false) == .classic)
        #expect(manager.effectiveTheme(hasPremiumAccess: true) == .kittyMoji)

        let restoredManager = MoodCustomizationManager(defaults: defaults)
        #expect(restoredManager.selectedTheme == .kittyMoji)
        #expect(restoredManager.title(for: .normal) == "Спокойно")
        #expect(restoredManager.title(for: .tired) == Mood.tired.title)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    @Test func achievementsUnlockAndPersistBetweenLaunches() {
        let suiteName = "felix228Tests.achievements"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let manager = AchievementManager(defaults: defaults)
        let baseDate = Date(timeIntervalSince1970: 1_000_000)

        let entries = (0..<7).map { index in
            EmotionEntry(
                createdAt: baseDate.addingTimeInterval(Double(index) * 3_600),
                mood: .normal,
                intensity: 5
            )
        }

        let goals = [
            DailyGoal(
                createdAt: baseDate.addingTimeInterval(120),
                title: "Выпить воду",
                lastCompletedAt: baseDate.addingTimeInterval(9_000)
            )
        ]

        manager.synchronize(
            entries: entries,
            goals: goals,
            hasPremiumAccess: true,
            now: baseDate.addingTimeInterval(20_000)
        )

        #expect(manager.badge(for: .firstEntry).isUnlocked)
        #expect(manager.badge(for: .sevenEntries).isUnlocked)
        #expect(manager.badge(for: .firstGoal).isUnlocked)
        #expect(manager.badge(for: .firstCompletedGoal).isUnlocked)
        #expect(manager.badge(for: .premiumHappyCat).isUnlocked)
        #expect(manager.unlockedCount == 5)

        let restoredManager = AchievementManager(defaults: defaults)
        #expect(restoredManager.badge(for: .firstEntry).isUnlocked)
        #expect(restoredManager.badge(for: .premiumHappyCat).isUnlocked)
        #expect(restoredManager.unlockedCount == 5)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    @Test func achievementsCanBeExportedAndRestoredForCloudSync() {
        let sourceSuite = "felix228Tests.achievements.source"
        let targetSuite = "felix228Tests.achievements.target"
        let sourceDefaults = UserDefaults(suiteName: sourceSuite)!
        let targetDefaults = UserDefaults(suiteName: targetSuite)!
        sourceDefaults.removePersistentDomain(forName: sourceSuite)
        targetDefaults.removePersistentDomain(forName: targetSuite)

        let sourceManager = AchievementManager(defaults: sourceDefaults)
        let baseDate = Date(timeIntervalSince1970: 2_000_000)

        sourceManager.synchronize(
            entries: [
                EmotionEntry(createdAt: baseDate, mood: .normal, intensity: 5)
            ],
            goals: [
                DailyGoal(
                    createdAt: baseDate.addingTimeInterval(60),
                    title: "Прогуляться",
                    lastCompletedAt: baseDate.addingTimeInterval(600)
                )
            ],
            hasPremiumAccess: true,
            now: baseDate.addingTimeInterval(900)
        )

        let targetManager = AchievementManager(defaults: targetDefaults)
        targetManager.replaceUnlockedDates(fromTimestamps: sourceManager.exportedUnlockedDateTimestamps)

        #expect(targetManager.badge(for: .firstEntry).isUnlocked)
        #expect(targetManager.badge(for: .firstGoal).isUnlocked)
        #expect(targetManager.badge(for: .firstCompletedGoal).isUnlocked)
        #expect(targetManager.badge(for: .premiumHappyCat).isUnlocked)
        #expect(targetManager.unlockedCount == sourceManager.unlockedCount)

        sourceDefaults.removePersistentDomain(forName: sourceSuite)
        targetDefaults.removePersistentDomain(forName: targetSuite)
    }

    @Test func averageIntensityTodayIgnoresOlderEntries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let todayMorning = calendar.date(from: DateComponents(year: 2026, month: 5, day: 12, hour: 9))!
        let todayEvening = calendar.date(from: DateComponents(year: 2026, month: 5, day: 12, hour: 18))!
        let yesterday = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 20))!

        let entries = [
            EmotionEntry(createdAt: todayMorning, mood: .superb, intensity: 8),
            EmotionEntry(createdAt: todayEvening, mood: .normal, intensity: 6),
            EmotionEntry(createdAt: yesterday, mood: .bad, intensity: 2)
        ]

        let average = EmotionAnalytics.averageIntensityToday(
            in: entries,
            calendar: calendar,
            now: todayEvening
        )

        #expect(average == 7)
    }

    @Test func dominantMoodPrefersMostRecentEntryOnTie() {
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        let entries = [
            EmotionEntry(createdAt: baseDate, mood: .superb, intensity: 7),
            EmotionEntry(createdAt: baseDate.addingTimeInterval(600), mood: .normal, intensity: 7)
        ]

        #expect(EmotionAnalytics.dominantMood(in: entries) == .normal)
    }

    @Test func dailyGoalTracksCompletionForToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let today = calendar.date(from: DateComponents(year: 2026, month: 5, day: 12, hour: 9))!
        let yesterday = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 18))!
        let goal = DailyGoal(title: "Пройтись вечером")

        #expect(goal.isCompleted(on: today, calendar: calendar) == false)

        goal.setCompleted(true, on: yesterday, calendar: calendar)
        #expect(goal.isCompleted(on: today, calendar: calendar) == false)
        #expect(goal.isCompleted(on: yesterday, calendar: calendar) == true)

        goal.setCompleted(true, on: today, calendar: calendar)
        #expect(goal.isCompleted(on: today, calendar: calendar) == true)
        #expect(goal.completionHistory.count == 2)

        goal.setCompleted(false, on: today, calendar: calendar)
        #expect(goal.isCompleted(on: today, calendar: calendar) == false)
        #expect(goal.isCompleted(on: yesterday, calendar: calendar) == true)
        #expect(goal.completionHistory.count == 1)
    }

    @Test func emotionEntryStoresActivitySnapshots() {
        let entry = EmotionEntry(
            mood: .superb,
            intensity: 8,
            activitySnapshots: [
                EntryActivitySnapshot(title: "Игры", symbolName: "gamecontroller.fill"),
                EntryActivitySnapshot(title: "Уборка", symbolName: "broom.fill")
            ]
        )

        #expect(entry.activitySnapshots.count == 2)
        #expect(entry.activitySnapshots[0].title == "Игры")
        #expect(entry.activitySnapshots[0].symbolName == "gamecontroller.fill")
        #expect(entry.activitySnapshots[1].title == "Уборка")
        #expect(entry.activitySnapshots[1].symbolName == "broom.fill")
    }

    @Test func currentEntryStreakCountsOnlyConsecutiveDaysIncludingToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let today = calendar.date(from: DateComponents(year: 2026, month: 5, day: 12, hour: 9))!
        let yesterday = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 20))!
        let twoDaysAgo = calendar.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 14))!
        let fourDaysAgo = calendar.date(from: DateComponents(year: 2026, month: 5, day: 8, hour: 12))!

        let entries = [
            EmotionEntry(createdAt: today, mood: .superb, intensity: 8),
            EmotionEntry(createdAt: yesterday, mood: .normal, intensity: 6),
            EmotionEntry(createdAt: twoDaysAgo, mood: .soSo, intensity: 7),
            EmotionEntry(createdAt: fourDaysAgo, mood: .bad, intensity: 3)
        ]

        let streak = EmotionAnalytics.currentEntryStreak(
            in: entries,
            calendar: calendar,
            now: today
        )

        #expect(streak == 3)
    }
}
