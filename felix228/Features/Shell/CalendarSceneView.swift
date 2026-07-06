//
//  CalendarSceneView
//  felix228
//
//  Created by Codex on 13.05.2026.
//

import SwiftUI
import UIKit
struct CalendarSceneView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var moodCustomization: MoodCustomizationManager

    let topInset: CGFloat
    let palette: ThemePalette
    let monthTitle: String
    let displayedMonth: Date
    let entries: [EmotionEntry]
    let goals: [DailyGoal]
    let activities: [ActivityOption]
    @Binding var selectedOverviewMode: CalendarOverviewMode
    @Binding var selectedActivityLookupKey: String?
    @Binding var selectedGoalKey: String?
    @Binding var selectedDay: Date?
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onOpenMore: () -> Void
    let onDeleteEntry: (EmotionEntry) -> Void

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = localization.locale
        calendar.firstWeekday = 2
        return calendar
    }

    private var moodCounts: [MoodStatItem] {
        let grouped = Dictionary(grouping: entries, by: \.mood)
        return Mood.allCases.map { mood in
            MoodStatItem(mood: mood, count: grouped[mood, default: []].count)
        }
    }

    private var activityChoices: [CalendarActivityChoice] {
        var choicesByKey: [String: CalendarActivityChoice] = [:]

        for activity in activities {
            choicesByKey[activity.lookupKey] = CalendarActivityChoice(
                lookupKey: activity.lookupKey,
                title: activity.title,
                symbolName: activity.symbolName
            )
        }

        for snapshot in entries.flatMap(\.activitySnapshots) {
            let lookupKey = ActivityOption.makeLookupKey(snapshot.title)
            guard choicesByKey[lookupKey] == nil else { continue }
            choicesByKey[lookupKey] = CalendarActivityChoice(
                lookupKey: lookupKey,
                title: snapshot.title,
                symbolName: snapshot.symbolName
            )
        }

        return choicesByKey.values.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private var selectedActivityChoice: CalendarActivityChoice? {
        if
            let selectedActivityLookupKey,
            let match = activityChoices.first(where: { $0.lookupKey == selectedActivityLookupKey })
        {
            return match
        }

        return activityChoices.first
    }

    private var sortedGoals: [DailyGoal] {
        goals.sorted { $0.createdAt < $1.createdAt }
    }

    private var selectedGoal: DailyGoal? {
        if
            let selectedGoalKey,
            let match = sortedGoals.first(where: { Self.goalSelectionKey(for: $0) == selectedGoalKey })
        {
            return match
        }

        return sortedGoals.first
    }

    private var monthDays: [CalendarDayCellModel] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }

        let monthStart = monthInterval.start
        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7
        let dayRange = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<2
        var days: [CalendarDayCellModel] = []

        for _ in 0..<leadingDays {
            days.append(CalendarDayCellModel(date: nil, indicator: .empty, entryCount: 0, isToday: false, isActive: false))
        }

        for day in dayRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            let dayEntries = EmotionAnalytics.entries(onSameDayAs: date, in: entries, calendar: calendar)
            days.append(calendarDayCellModel(for: date, dayEntries: dayEntries))
        }

        while days.count % 7 != 0 {
            days.append(CalendarDayCellModel(date: nil, indicator: .empty, entryCount: 0, isToday: false, isActive: false))
        }

        return days
    }

    private var selectedDayValue: Date? {
        if let selectedDay, calendar.isDate(selectedDay, equalTo: displayedMonth, toGranularity: .month) {
            return selectedDay
        }

        if calendar.isDate(.now, equalTo: displayedMonth, toGranularity: .month) {
            return .now
        }

        return monthDays.compactMap(\.date).first
    }

    private var selectedDayEntries: [EmotionEntry] {
        guard let selectedDayValue else { return [] }
        return EmotionAnalytics.entries(onSameDayAs: selectedDayValue, in: entries, calendar: calendar)
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var selectedDayActivityEntries: [EmotionEntry] {
        guard
            let selectedDayValue,
            let selectedActivityChoice
        else {
            return []
        }

        return EmotionAnalytics.entries(onSameDayAs: selectedDayValue, in: entries, calendar: calendar)
            .filter { entryContainsActivity($0, lookupKey: selectedActivityChoice.lookupKey) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var selectedDayTitle: String {
        guard let selectedDayValue else {
            return localization.pick("Выбери день", "Choose a day")
        }

        if calendar.isDateInToday(selectedDayValue) {
            return localization.pick("Сегодня", "Today")
        }

        if calendar.isDateInYesterday(selectedDayValue) {
            return localization.pick("Вчера", "Yesterday")
        }

        return localization.dayMonthTitle(from: selectedDayValue).capitalized
    }

    private var monthDominantMood: Mood? {
        EmotionAnalytics.dominantMood(in: entries)
    }

    private var activityMonthEntryCount: Int {
        guard let selectedActivityChoice else { return 0 }
        return entries.filter { entryContainsActivity($0, lookupKey: selectedActivityChoice.lookupKey) }.count
    }

    private var activityMonthDayCount: Int {
        guard let selectedActivityChoice else { return 0 }
        return Set(
            entries
                .filter { entryContainsActivity($0, lookupKey: selectedActivityChoice.lookupKey) }
                .map { calendar.startOfDay(for: $0.createdAt) }
        ).count
    }

    private var goalMonthCompletedDaysCount: Int {
        guard let selectedGoal else { return 0 }
        return selectedGoal.completionHistory.filter {
            calendar.isDate($0, equalTo: displayedMonth, toGranularity: .month)
        }.count
    }

    private var selectedDayGoalCompleted: Bool {
        guard
            let selectedDayValue,
            let selectedGoal
        else {
            return false
        }

        return selectedGoal.isCompleted(on: selectedDayValue, calendar: calendar)
    }

    private var calendarSummaryText: String {
        switch selectedOverviewMode {
        case .moods:
            return localization.pick(
                "\(monthDays.filter { $0.date != nil && $0.entryCount > 0 }.count) дней с записями",
                "\(monthDays.filter { $0.date != nil && $0.entryCount > 0 }.count) days with entries"
            )
        case .activities:
            return localization.pick(
                "\(activityMonthDayCount) дней с занятием",
                "\(activityMonthDayCount) days with this activity"
            )
        case .goals:
            return localization.pick(
                "\(goalMonthCompletedDaysCount) дней с выполнением",
                "\(goalMonthCompletedDaysCount) days completed"
            )
        }
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

                CalendarOverviewSummaryStrip(
                    palette: palette,
                    accent: summaryAccent,
                    leading: summaryLeadingVisual,
                    title: summaryTitle,
                    subtitle: summarySubtitle,
                    trailing: summaryTrailing
                )

                CalendarOverviewControlsCard(
                    palette: palette,
                    selectedMode: $selectedOverviewMode,
                    selectedActivity: selectedActivityChoice,
                    activityChoices: activityChoices,
                    onSelectActivity: { selectedActivityLookupKey = $0.lookupKey },
                    selectedGoal: selectedGoal,
                    goals: sortedGoals,
                    onSelectGoal: { selectedGoalKey = Self.goalSelectionKey(for: $0) }
                )

                CalendarGridCard(
                    palette: palette,
                    monthTitle: monthTitle,
                    summaryText: calendarSummaryText,
                    days: monthDays,
                    selectedDay: $selectedDay
                )

                if selectedOverviewMode == .moods {
                    MoodGaugeCard(
                        title: localization.pick("Счётчик настроения", "Mood counter"),
                        subtitle: localization.pick(
                            "Нажми на день, чтобы увидеть записи ниже.",
                            "Tap a day to see the entries below."
                        ),
                        items: moodCounts,
                        palette: palette
                    )
                } else {
                    CalendarOverviewMetricsCard(
                        palette: palette,
                        title: selectedOverviewMode == .activities
                            ? localization.pick("Статистика занятия", "Activity stats")
                            : localization.pick("Статистика цели", "Goal stats"),
                        subtitle: selectedOverviewMode == .activities
                            ? localization.pick(
                                "Календарь покажет, в какие дни это занятие попадало в заметки.",
                                "The calendar will show on which days this activity appeared in entries."
                            )
                            : localization.pick(
                                "Календарь покажет, в какие дни цель была отмечена выполненной.",
                                "The calendar will show on which days the goal was marked complete."
                            ),
                        items: metricsItems
                    )
                }

                StatisticsSectionCard(
                    palette: palette,
                    title: selectedDayTitle,
                    subtitle: selectedDaySubtitle
                ) {
                    selectedDayContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 150)
        }
    }

    @ViewBuilder
    private var selectedDayContent: some View {
        switch selectedOverviewMode {
        case .moods:
            if selectedDayEntries.isEmpty {
                EmptyBadgeRow(
                    palette: palette,
                    text: localization.pick("Записей нет", "No entries")
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(selectedDayEntries.prefix(3)) { entry in
                        JournalEntryCard(
                            entry: entry,
                            palette: palette,
                            compact: true,
                            onDelete: { onDeleteEntry(entry) }
                        )
                    }
                }
            }

        case .activities:
            if let selectedActivityChoice {
                if selectedDayActivityEntries.isEmpty {
                    EmptyBadgeRow(
                        palette: palette,
                        text: localization.pick(
                            "Занятие «\(selectedActivityChoice.title)» в этот день не отмечалось.",
                            "The activity “\(selectedActivityChoice.title)” wasn’t marked on this day."
                        )
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(selectedDayActivityEntries.prefix(3)) { entry in
                            JournalEntryCard(
                                entry: entry,
                                palette: palette,
                                compact: true,
                                onDelete: { onDeleteEntry(entry) }
                            )
                        }
                    }
                }
            } else {
                EmptyBadgeRow(
                    palette: palette,
                    text: localization.pick(
                        "Сначала добавь или выбери занятие выше.",
                        "First add or choose an activity above."
                    )
                )
            }

        case .goals:
            if let selectedGoal {
                CalendarGoalStatusCard(
                    palette: palette,
                    goalTitle: selectedGoal.title,
                    isCompleted: selectedDayGoalCompleted,
                    entriesCount: selectedDayEntries.count
                )
            } else {
                EmptyBadgeRow(
                    palette: palette,
                    text: localization.pick(
                        "Сначала добавь хотя бы одну цель.",
                        "First add at least one goal."
                    )
                )
            }
        }
    }

    private var selectedDaySubtitle: String? {
        switch selectedOverviewMode {
        case .moods:
            return selectedDayEntries.isEmpty
                ? localization.pick("На этот день пока нет записей.", "There are no entries for this day yet.")
                : nil
        case .activities:
            return selectedActivityChoice.map {
                localization.pick("Показываем только «\($0.title)».", "Showing only “\($0.title)”.")
            }
        case .goals:
            return selectedGoal.map {
                localization.pick("Проверяем выполнение цели «\($0.title)».", "Checking completion of the goal “\($0.title)”.")
            }
        }
    }

    private var metricsItems: [CalendarMetricItem] {
        switch selectedOverviewMode {
        case .moods:
            return []
        case .activities:
            return [
                CalendarMetricItem(title: localization.pick("Записей", "Entries"), value: "\(activityMonthEntryCount)", tint: palette.accent),
                CalendarMetricItem(title: localization.pick("Дней", "Days"), value: "\(activityMonthDayCount)", tint: palette.floatingButtonSecondary),
                CalendarMetricItem(
                    title: localization.pick("Выбрано", "Selected"),
                    value: selectedActivityChoice?.title ?? "—",
                    tint: palette.accent
                )
            ]
        case .goals:
            return [
                CalendarMetricItem(title: localization.pick("Дней", "Days"), value: "\(goalMonthCompletedDaysCount)", tint: palette.accent),
                CalendarMetricItem(
                    title: localization.pick("Сегодня", "Today"),
                    value: selectedGoal?.isCompletedToday == true
                        ? localization.pick("Да", "Yes")
                        : localization.pick("Нет", "No"),
                    tint: palette.floatingButtonSecondary
                ),
                CalendarMetricItem(
                    title: localization.pick("Цель", "Goal"),
                    value: selectedGoal?.title ?? "—",
                    tint: palette.accent
                )
            ]
        }
    }

    private var summaryLeadingVisual: CalendarOverviewLeadingVisual {
        switch selectedOverviewMode {
        case .moods:
            if let monthDominantMood {
                return .mood(monthDominantMood)
            }
            return .system("sparkles")
        case .activities:
            if let selectedActivityChoice {
                return .activity(selectedActivityChoice.snapshot)
            }
            return .system("sparkles.square.filled.on.square")
        case .goals:
            return .goal(isHighlighted: goalMonthCompletedDaysCount > 0)
        }
    }

    private var summaryAccent: Color {
        switch selectedOverviewMode {
        case .moods:
            return monthDominantMood?.tint ?? palette.accent
        case .activities:
            return palette.accent
        case .goals:
            return goalMonthCompletedDaysCount > 0 ? palette.accent : palette.floatingButtonSecondary
        }
    }

    private var summaryTitle: String {
        switch selectedOverviewMode {
        case .moods:
            return monthDominantMood.map(moodCustomization.title(for:)) ?? localization.pick("Без эмоции", "No mood")
        case .activities:
            return selectedActivityChoice?.title ?? localization.pick("Выбери занятие", "Choose an activity")
        case .goals:
            return selectedGoal?.title ?? localization.pick("Выбери цель", "Choose a goal")
        }
    }

    private var summarySubtitle: String {
        switch selectedOverviewMode {
        case .moods:
            return entries.isEmpty
                ? localization.pick("В этом месяце пока пусто.", "This month is still empty.")
                : localization.pick("Отметок за месяц: \(entries.count)", "Entries this month: \(entries.count)")
        case .activities:
            guard selectedActivityChoice != nil else {
                return localization.pick(
                    "Сверху можно выбрать нужное занятие и увидеть его по дням.",
                    "Choose the activity above to see it by day."
                )
            }
            return activityMonthDayCount == 0
                ? localization.pick(
                    "В этом месяце это занятие пока не попадало в заметки.",
                    "This activity hasn’t appeared in entries this month yet."
                )
                : localization.pick(
                    "\(activityMonthEntryCount) записей • \(activityMonthDayCount) активных дней",
                    "\(activityMonthEntryCount) entries • \(activityMonthDayCount) active days"
                )
        case .goals:
            guard selectedGoal != nil else {
                return localization.pick(
                    "Сверху можно выбрать цель и проверить её по календарю.",
                    "Choose a goal above and check it on the calendar."
                )
            }
            return goalMonthCompletedDaysCount == 0
                ? localization.pick(
                    "В этом месяце цель ещё не отмечалась выполненной.",
                    "This goal hasn’t been marked complete this month yet."
                )
                : localization.pick(
                    "Отмечено \(goalMonthCompletedDaysCount) раз за месяц",
                    "Marked \(goalMonthCompletedDaysCount) times this month"
                )
        }
    }

    private var summaryTrailing: String {
        switch selectedOverviewMode {
        case .moods:
            return entries.isEmpty
                ? localization.pick("Добавь запись", "Add entry")
                : "\(entries.count)x"
        case .activities:
            return activityMonthDayCount == 0
                ? localization.pick("Нет", "No")
                : "\(activityMonthDayCount)x"
        case .goals:
            return goalMonthCompletedDaysCount == 0 ? "0" : "\(goalMonthCompletedDaysCount)x"
        }
    }

    private func calendarDayCellModel(for date: Date, dayEntries: [EmotionEntry]) -> CalendarDayCellModel {
        switch selectedOverviewMode {
        case .moods:
            let dominantMood = EmotionAnalytics.dominantMood(in: dayEntries)
            return CalendarDayCellModel(
                date: date,
                indicator: dominantMood.map(CalendarDayIndicator.mood) ?? .empty,
                entryCount: dayEntries.count,
                isToday: calendar.isDateInToday(date),
                isActive: dominantMood != nil
            )

        case .activities:
            guard let selectedActivityChoice else {
                return CalendarDayCellModel(
                    date: date,
                    indicator: .empty,
                    entryCount: 0,
                    isToday: calendar.isDateInToday(date),
                    isActive: false
                )
            }

            let matchingEntries = dayEntries.filter {
                entryContainsActivity($0, lookupKey: selectedActivityChoice.lookupKey)
            }

            return CalendarDayCellModel(
                date: date,
                indicator: matchingEntries.isEmpty ? .empty : .activity(selectedActivityChoice.snapshot),
                entryCount: matchingEntries.count,
                isToday: calendar.isDateInToday(date),
                isActive: !matchingEntries.isEmpty
            )

        case .goals:
            let isCompleted = selectedGoal?.isCompleted(on: date, calendar: calendar) ?? false
            return CalendarDayCellModel(
                date: date,
                indicator: .goal(isCompleted: isCompleted),
                entryCount: isCompleted ? 1 : 0,
                isToday: calendar.isDateInToday(date),
                isActive: isCompleted
            )
        }
    }

    private func entryContainsActivity(_ entry: EmotionEntry, lookupKey: String) -> Bool {
        entry.activitySnapshots.contains { snapshot in
            ActivityOption.makeLookupKey(snapshot.title) == lookupKey
        }
    }

    private static func goalSelectionKey(for goal: DailyGoal) -> String {
        if let syncID = goal.syncID, !syncID.isEmpty {
            return syncID
        }

        return "\(goal.createdAt.timeIntervalSince1970)-\(goal.title)"
    }

}


struct CalendarActivityChoice: Identifiable, Hashable {
    let lookupKey: String
    let title: String
    let symbolName: String

    var id: String { lookupKey }

    var snapshot: EntryActivitySnapshot {
        EntryActivitySnapshot(title: title, symbolName: symbolName)
    }
}

enum CalendarOverviewLeadingVisual {
    case mood(Mood)
    case activity(EntryActivitySnapshot)
    case goal(isHighlighted: Bool)
    case system(String)
}

enum CalendarDayIndicator {
    case mood(Mood)
    case activity(EntryActivitySnapshot)
    case goal(isCompleted: Bool)
    case empty
}

struct CalendarMetricItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let tint: Color
}

struct CalendarDayCellModel: Identifiable {
    let id = UUID()
    let date: Date?
    let indicator: CalendarDayIndicator
    let entryCount: Int
    let isToday: Bool
    let isActive: Bool
}
