//
//  StatisticsSceneView
//  felix228
//
//  Created by Codex on 13.05.2026.
//

import SwiftUI
import UIKit
struct StatisticsSceneView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var moodCustomization: MoodCustomizationManager
    @EnvironmentObject private var achievementManager: AchievementManager

    let topInset: CGFloat
    let palette: ThemePalette
    let monthTitle: String
    let displayedMonth: Date
    let entries: [EmotionEntry]
    let completedGoalsTodayCount: Int
    let totalGoalsCount: Int
    let overallStreak: Int
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onOpenMore: () -> Void

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = localization.locale
        calendar.firstWeekday = 2
        return calendar
    }

    private var moodCounts: [MoodStatItem] {
        let grouped = Dictionary(grouping: entries, by: \.mood)
        return statisticsMoodOrder.map { mood in
            MoodStatItem(mood: mood, count: grouped[mood, default: []].count)
        }
    }

    private var totalCount: Int {
        entries.count
    }

    private var averageIntensity: Int? {
        EmotionAnalytics.averageIntensity(in: entries).map { Int($0.rounded()) }
    }

    private var topActivities: [ActivityStatItem] {
        let grouped = Dictionary(grouping: entries.flatMap(\.activitySnapshots), by: \.id)
        return grouped
            .compactMap { _, snapshots in
                guard let snapshot = snapshots.first else { return nil }
                return ActivityStatItem(snapshot: snapshot, count: snapshots.count)
            }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.snapshot.title < $1.snapshot.title
            }
            .prefix(6)
            .map { $0 }
    }

    private var activeDaysCount: Int {
        let calendar = Calendar.current
        return Set(entries.map { calendar.startOfDay(for: $0.createdAt) }).count
    }

    private var dominantMood: Mood? {
        EmotionAnalytics.dominantMood(in: entries)
    }

    private var recentAchievementBadges: [FelixAchievementBadge] {
        let unlocked = achievementManager.recentUnlockedBadges
        let locked = achievementManager.badges.filter { !$0.isUnlocked }
        let prioritized = unlocked + locked
        return Array(prioritized.prefix(3))
    }

    private var moodTrendPoints: [StatisticsMoodTrendPoint] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }

        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }

        return dayRange.compactMap { day in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else {
                return nil
            }

            let dayEntries = EmotionAnalytics.entries(onSameDayAs: date, in: entries, calendar: calendar)
            guard !dayEntries.isEmpty else { return nil }

            let totalScore = dayEntries.reduce(0.0) { partialResult, entry in
                partialResult + moodScore(for: entry.mood)
            }

            return StatisticsMoodTrendPoint(
                dayNumber: day,
                score: totalScore / Double(dayEntries.count),
                entryCount: dayEntries.count
            )
        }
    }

    private var displayedMonthDayCount: Int {
        calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30
    }

    private var streakPreviewDays: [StatisticsStreakDay] {
        guard overallStreak > 0 else { return [] }

        let visibleCount = min(max(overallStreak, 3), 5)
        let today = calendar.startOfDay(for: .now)

        return (0..<visibleCount).compactMap { index in
            let offset = visibleCount - 1 - index
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }

            return StatisticsStreakDay(
                date: date,
                label: calendar.isDateInToday(date)
                    ? localization.pick("Сегодня", "Today")
                    : localization.shortWeekdayTitle(from: date),
                isToday: calendar.isDateInToday(date)
            )
        }
    }

    private var summaryTitle: String {
        if let dominantMood {
            return moodCustomization.title(for: dominantMood)
        }

        return localization.pick("Статистика месяца", "Monthly stats")
    }

    private var summarySubtitle: String {
        guard totalCount > 0 else {
            return localization.pick(
                "Месяц пока пустой, но здесь быстро появится ритм твоих дней.",
                "The month is still empty, but the rhythm of your days will appear here soon."
            )
        }

        return localization.pick(
            "\(totalCount) записей • \(activeDaysCount) активных дней",
            "\(totalCount) entries • \(activeDaysCount) active days"
        )
    }

    private var summaryTrailing: String {
        averageIntensity.map { "\($0)/10" } ?? "—"
    }

    private var moodGaugeSubtitle: String {
        if totalCount == 0 {
            return localization.pick("В этом месяце пока нет отметок.", "There are no entries this month yet.")
        }

        return localization.pick(
            "Полная картина месяца по всем выбранным эмоциям.",
            "The full picture of the month across all selected moods."
        )
    }

    private var moodTrendSubtitle: String {
        if moodTrendPoints.isEmpty {
            return localization.pick(
                "Как только в этом месяце появятся эмоции, здесь выстроится линия по дням.",
                "As soon as moods appear this month, a day-by-day line will build here."
            )
        }

        return localization.pick(
            "Среднее настроение каждого дня без визуального шума и съехавших блоков.",
            "The average mood for each day without visual noise or broken layout."
        )
    }

    private var highlightedActivityTitle: String? {
        topActivities.first.map { "\($0.snapshot.title) • \($0.count)x" }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                MonthHeaderBar(
                    topInset: topInset,
                    monthTitle: monthTitle,
                    palette: palette,
                    onPreviousMonth: onPreviousMonth,
                    onNextMonth: onNextMonth,
                    onTrailingAction: onOpenMore
                )

                JournalSummaryStrip(
                    palette: palette,
                    mood: dominantMood,
                    title: summaryTitle,
                    subtitle: summarySubtitle,
                    accent: dominantMood?.tint ?? palette.accent,
                    trailing: summaryTrailing
                )

                HStack(spacing: 12) {
                    MetricCapsuleCard(
                        palette: palette,
                        title: localization.pick("Дней", "Days"),
                        value: "\(activeDaysCount)",
                        tint: palette.accent
                    )

                    MetricCapsuleCard(
                        palette: palette,
                        title: localization.pick("Серия", "Streak"),
                        value: "\(overallStreak)",
                        tint: dominantMood?.tint ?? palette.floatingButtonSecondary
                    )

                    MetricCapsuleCard(
                        palette: palette,
                        title: localization.pick("Цели", "Goals"),
                        value: totalGoalsCount == 0 ? "0" : "\(completedGoalsTodayCount)/\(totalGoalsCount)",
                        tint: palette.floatingButtonSecondary
                    )
                }

                StatisticsAchievementsPreviewCard(
                    palette: palette,
                    badges: recentAchievementBadges,
                    unlockedCount: achievementManager.unlockedCount,
                    totalCount: achievementManager.totalCount,
                    onShowAll: onOpenMore
                )

                StatisticsStreakCard(
                    palette: palette,
                    streak: overallStreak,
                    days: streakPreviewDays
                )

                MoodTrendCard(
                    palette: palette,
                    title: localization.pick("График настроения", "Mood chart"),
                    subtitle: moodTrendSubtitle,
                    points: moodTrendPoints,
                    dayCount: displayedMonthDayCount,
                    footerHighlight: highlightedActivityTitle
                )

                MoodGaugeCard(
                    title: localization.pick("Счётчик настроения", "Mood counter"),
                    subtitle: moodGaugeSubtitle,
                    items: moodCounts,
                    palette: palette
                )

                StatisticsSectionCard(
                    palette: palette,
                    title: localization.pick("Популярные занятия", "Popular activities"),
                    subtitle: topActivities.isEmpty
                        ? localization.pick(
                            "Добавь занятия в записи, и здесь появятся шаблоны месяца.",
                            "Add activities to entries and this month’s patterns will appear here."
                        )
                        : localization.pick(
                            "Что чаще всего сопровождало твои дни в этом месяце.",
                            "What most often accompanied your days this month."
                        )
                ) {
                    if topActivities.isEmpty {
                        EmptyBadgeRow(
                            palette: palette,
                            text: localization.pick("Пока без занятий", "No activities yet")
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            if let featuredActivity = topActivities.first {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(palette.accent.opacity(0.14))
                                            .frame(width: 58, height: 58)

                                        ActivityVisualView(
                                            snapshot: featuredActivity.snapshot,
                                            size: 24,
                                            tint: palette.accent
                                        )
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(featuredActivity.snapshot.title)
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(.primary)

                                        Text(localization.pick(
                                            "\(featuredActivity.count) раз за месяц",
                                            "\(featuredActivity.count) times this month"
                                        ))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding(16)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(topActivities) { item in
                                        ActivityStatChip(
                                            palette: palette,
                                            snapshot: item.snapshot,
                                            count: item.count
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 150)
        }
    }

    private func moodScore(for mood: Mood) -> Double {
        switch mood {
        case .superb:
            return 5
        case .normal:
            return 4
        case .soSo:
            return 3
        case .tired:
            return 2
        case .bad:
            return 1
        }
    }

    private var statisticsMoodOrder: [Mood] {
        [.superb, .normal, .soSo, .tired, .bad]
    }

}
