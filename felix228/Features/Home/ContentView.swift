//
//  ContentView.swift
//  felix228
//
//  Created by Dasha Stepanova on 12.05.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var cloudAccount: CloudAccountManager
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var moodCustomization: MoodCustomizationManager
    @EnvironmentObject private var premiumAccess: PremiumAccessManager
    @EnvironmentObject private var felixIslandManager: FelixIslandManager
    @EnvironmentObject private var achievementManager: AchievementManager
    @EnvironmentObject private var themeManager: ThemeManager
    @Query(sort: [SortDescriptor(\EmotionEntry.createdAt, order: .reverse)])
    private var entries: [EmotionEntry]
    @Query(sort: [SortDescriptor(\DailyGoal.createdAt, order: .forward)])
    private var goals: [DailyGoal]
    @Query(sort: [SortDescriptor(\ActivityOption.createdAt, order: .forward)])
    private var activities: [ActivityOption]

    @State private var isPresentingComposer = false
    @State private var isPresentingActivityEditor = false
    @State private var composerMood: Mood?
    @State private var goalDraft = ""
    @State private var saveErrorMessage: String?
    @State private var selectedTab: JournalTab = .records
    @State private var displayedMonth: Date = .now
    @State private var areGoalsExpanded = true
    @State private var selectedCalendarDay: Date?
    @State private var selectedCalendarOverviewMode: CalendarOverviewMode = .moods
    @State private var selectedCalendarActivityLookupKey: String?
    @State private var selectedCalendarGoalKey: String?

    private var palette: ThemePalette {
        themeManager.palette(for: colorScheme)
    }

    private var monthCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = localization.locale
        calendar.firstWeekday = 2
        return calendar
    }

    private var displayedMonthEntries: [EmotionEntry] {
        entries
            .filter { monthCalendar.isDate($0.createdAt, equalTo: displayedMonth, toGranularity: .month) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var sortedGoals: [DailyGoal] {
        goals.sorted { lhs, rhs in
            if lhs.isCompletedToday != rhs.isCompletedToday {
                return !lhs.isCompletedToday && rhs.isCompletedToday
            }

            return lhs.createdAt < rhs.createdAt
        }
    }

    private var completedGoalsTodayCount: Int {
        goals.filter { $0.isCompletedToday }.count
    }

    private var displayedMonthTitle: String {
        localization.monthTitle(from: displayedMonth)
    }

    private var felixIslandSnapshot: FelixIslandSnapshot {
        guard let latestEntry = entries.first else {
            return .empty
        }

        let trimmedNote = latestEntry.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = trimmedNote.isEmpty
            ? localization.pick(
                "Последнее настроение: \(moodCustomization.lowercaseTitle(for: latestEntry.mood)).",
                "Latest mood: \(moodCustomization.lowercaseTitle(for: latestEntry.mood))."
            )
            : trimmedNote

        return FelixIslandSnapshot(
            headline: localization.pick(
                "Сегодня: \(moodCustomization.lowercaseTitle(for: latestEntry.mood))",
                "Today: \(moodCustomization.lowercaseTitle(for: latestEntry.mood))"
            ),
            detail: detail,
            moodTitle: moodCustomization.title(for: latestEntry.mood),
            noteCount: entries.count
        )
    }

    private var felixIslandSyncKey: String {
        let latestSyncID = entries.first?.syncID ?? "none"
        let latestMoodID = entries.first?.moodID ?? "none"
        let latestTimestamp = Int(entries.first?.createdAt.timeIntervalSince1970 ?? 0)
        return "\(premiumAccess.hasPremiumAccess)-\(entries.count)-\(latestSyncID)-\(latestMoodID)-\(latestTimestamp)"
    }

    private var achievementsSyncKey: String {
        let earliestEntryTimestamp = Int(entries.map { $0.createdAt.timeIntervalSince1970 }.min() ?? 0)
        let earliestGoalTimestamp = Int(goals.map { $0.createdAt.timeIntervalSince1970 }.min() ?? 0)
        let firstCompletedGoalTimestamp = Int(goals.compactMap { $0.lastCompletedAt?.timeIntervalSince1970 }.min() ?? 0)
        let completedGoalsCount = goals.filter { $0.lastCompletedAt != nil }.count
        return [
            String(entries.count),
            String(goals.count),
            String(completedGoalsCount),
            String(earliestEntryTimestamp),
            String(earliestGoalTimestamp),
            String(firstCompletedGoalTimestamp),
            premiumAccess.hasPremiumAccess ? "premium" : "regular"
        ].joined(separator: "-")
    }

    init() {}

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    AppBackgroundView(palette: palette)
                    activeScene(topInset: proxy.safeAreaInsets.top)
                }
            }
            .safeAreaInset(edge: .bottom) {
                JournalFloatingTabBar(
                    selectedTab: $selectedTab,
                    palette: palette,
                    createAction: {
                        presentComposer()
                    }
                )
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isPresentingComposer) {
                EntryComposerView(initialMood: composerMood) { savedDate in
                    focusInterface(on: savedDate)
                }
            }
            .sheet(isPresented: $isPresentingActivityEditor) {
                ActivityEditorView()
            }
            .alert(localization.pick("Не удалось сохранить", "Couldn’t save"), isPresented: isShowingSaveError) {
                Button(localization.pick("Ок", "OK"), role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? localization.pick("Попробуй ещё раз.", "Please try again."))
            }
            .task {
                await synchronizeFelixIsland()
                synchronizeAchievements()
            }
            .onChange(of: felixIslandSyncKey) { _, _ in
                Task {
                    await synchronizeFelixIsland()
                }
            }
            .onChange(of: achievementsSyncKey) { _, _ in
                synchronizeAchievements()
            }
        }
    }

    @ViewBuilder
    private func activeScene(topInset: CGFloat) -> some View {
        switch selectedTab {
        case .records:
            RecordsSceneView(
                topInset: topInset,
                palette: palette,
                monthTitle: displayedMonthTitle,
                entries: displayedMonthEntries,
                goals: sortedGoals,
                completedGoalsTodayCount: completedGoalsTodayCount,
                goalDraft: $goalDraft,
                areGoalsExpanded: $areGoalsExpanded,
                onPreviousMonth: { shiftDisplayedMonth(by: -1) },
                onNextMonth: { shiftDisplayedMonth(by: 1) },
                onOpenMore: { selectedTab = .more },
                onAddGoal: addGoal,
                onToggleGoal: toggleGoal,
                onDeleteGoal: deleteGoal,
                onDeleteEntry: delete
            )
        case .statistics:
            StatisticsSceneView(
                topInset: topInset,
                palette: palette,
                monthTitle: displayedMonthTitle,
                displayedMonth: displayedMonth,
                entries: displayedMonthEntries,
                completedGoalsTodayCount: completedGoalsTodayCount,
                totalGoalsCount: goals.count,
                overallStreak: EmotionAnalytics.currentEntryStreak(in: entries),
                onPreviousMonth: { shiftDisplayedMonth(by: -1) },
                onNextMonth: { shiftDisplayedMonth(by: 1) },
                onOpenMore: { selectedTab = .more }
            )
        case .calendar:
            CalendarSceneView(
                topInset: topInset,
                palette: palette,
                monthTitle: displayedMonthTitle,
                displayedMonth: displayedMonth,
                entries: displayedMonthEntries,
                goals: goals,
                activities: activities,
                selectedOverviewMode: $selectedCalendarOverviewMode,
                selectedActivityLookupKey: $selectedCalendarActivityLookupKey,
                selectedGoalKey: $selectedCalendarGoalKey,
                selectedDay: $selectedCalendarDay,
                onPreviousMonth: { shiftDisplayedMonth(by: -1) },
                onNextMonth: { shiftDisplayedMonth(by: 1) },
                onOpenMore: { selectedTab = .more },
                onDeleteEntry: delete
            )
        case .more:
            MoreSceneView(
                topInset: topInset,
                palette: palette,
                totalEntries: entries.count,
                totalGoals: goals.count,
                completedGoalsTodayCount: completedGoalsTodayCount,
                activityCount: activities.count,
                onCreateEntry: { presentComposer() },
                onManageActivities: { isPresentingActivityEditor = true },
                onShowGoals: {
                    selectedTab = .records
                    areGoalsExpanded = true
                },
                onShowStatistics: { selectedTab = .statistics },
                onShowCalendar: { selectedTab = .calendar }
            )
        }
    }

    private var isShowingSaveError: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { shouldShow in
                if !shouldShow {
                    saveErrorMessage = nil
                }
            }
        )
    }

    private func presentComposer(with mood: Mood? = nil) {
        composerMood = mood
        isPresentingComposer = true
    }

    private func focusInterface(on date: Date) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            displayedMonth = date
            selectedCalendarDay = date
            selectedTab = .records
        }
    }

    private func shiftDisplayedMonth(by value: Int) {
        guard let updatedDate = monthCalendar.date(byAdding: .month, value: value, to: displayedMonth) else {
            return
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            displayedMonth = updatedDate
            selectedCalendarDay = nil
        }
    }

    private func synchronizeFelixIsland() async {
        await felixIslandManager.sync(
            snapshot: felixIslandSnapshot,
            hasPremiumAccess: premiumAccess.hasPremiumAccess
        )
    }

    private func synchronizeAchievements() {
        let unlockedNewAchievement = achievementManager.synchronize(
            entries: entries,
            goals: goals,
            hasPremiumAccess: premiumAccess.hasPremiumAccess
        )

        if unlockedNewAchievement {
            cloudAccount.scheduleAutoBackup(
                using: modelContext,
                achievementManager: achievementManager
            )
        }
    }

    private func addGoal() {
        let trimmedTitle = goalDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let goal = DailyGoal(title: trimmedTitle)
        modelContext.insert(goal)

        do {
            try modelContext.save()
            goalDraft = ""
            cloudAccount.scheduleAutoBackup(using: modelContext, achievementManager: achievementManager)
        } catch {
            modelContext.delete(goal)
            saveErrorMessage = localization.pick(
                "Цель не удалось сохранить в локальную базу данных. \(error.localizedDescription)",
                "The goal couldn’t be saved to local storage. \(error.localizedDescription)"
            )
        }
    }

    private func toggleGoal(_ goal: DailyGoal) {
        withAnimation {
            goal.setCompleted(!goal.isCompletedToday)
            persistChanges(prefix: localization.pick("Не удалось обновить цель.", "Couldn’t update the goal."))
        }
    }

    private func deleteGoal(_ goal: DailyGoal) {
        withAnimation {
            modelContext.delete(goal)
            persistChanges(prefix: localization.pick("Не удалось удалить цель.", "Couldn’t delete the goal."))
        }
    }

    private func delete(entry: EmotionEntry) {
        withAnimation {
            modelContext.delete(entry)
            persistChanges(prefix: localization.pick(
                "Изменения не удалось записать в локальную базу данных.",
                "Changes couldn’t be saved to local storage."
            ))
        }
    }

    private func persistChanges(prefix: String) {
        do {
            try modelContext.save()
            cloudAccount.scheduleAutoBackup(using: modelContext, achievementManager: achievementManager)
        } catch {
            saveErrorMessage = "\(prefix) \(error.localizedDescription)"
        }
    }
}

private struct GoalsSectionCard: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var draftTitle: String

    let goals: [DailyGoal]
    let completedTodayCount: Int
    let onAdd: () -> Void
    let onToggle: (DailyGoal) -> Void
    let onDelete: (DailyGoal) -> Void

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    private var draftIsEmpty: Bool {
        draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Цели")
                        .font(.title3.weight(.bold))

                    Spacer(minLength: 8)

                    Text("\(completedTodayCount)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(goals.isEmpty ? .secondary : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(palette.stroke, lineWidth: 1)
                        )
                }

                Text(goals.isEmpty ? "Добавь цель и отмечай галочкой, получилось ли выполнить её сегодня." : "Выполнено сегодня: \(completedTodayCount) из \(goals.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    goalTextField
                    addGoalButton
                }

                VStack(spacing: 12) {
                    goalTextField
                    addGoalButton
                        .frame(maxWidth: .infinity)
                }
            }

            if goals.isEmpty {
                Text("Цели будут сохраняться между запусками приложения, а галочка будет показывать, закрыта ли цель сегодня.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(palette.stroke, lineWidth: 1)
                    )
            } else {
                VStack(spacing: 10) {
                    ForEach(goals) { goal in
                        GoalRowCard(
                            goal: goal,
                            onToggle: {
                                onToggle(goal)
                            },
                            onDelete: {
                                onDelete(goal)
                            }
                        )
                    }
                }
            }
        }
        .padding(22)
        .background(palette.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
        .shadow(color: palette.cardShadow, radius: 18, y: 12)
    }

    private var goalTextField: some View {
        TextField("Например: пройти 10 000 шагов", text: $draftTitle)
            .textFieldStyle(.plain)
            .submitLabel(.done)
            .onSubmit(onAdd)
            .padding(16)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(palette.stroke, lineWidth: 1)
            )
    }

    private var addGoalButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.headline.weight(.bold))
                .foregroundStyle(palette.floatingButtonForeground)
                .frame(minWidth: 54, minHeight: 54)
                .background(draftIsEmpty ? palette.stroke : palette.floatingButton)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(draftIsEmpty)
    }
}

private struct GoalRowCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let goal: DailyGoal
    let onToggle: () -> Void
    let onDelete: () -> Void

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: goal.isCompletedToday ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(goal.isCompletedToday ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                Text(goal.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .strikethrough(goal.isCompletedToday, color: .secondary)

                Text(goal.isCompletedToday ? "Выполнено сегодня" : "Пока не отмечено на сегодня")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(goal.isCompletedToday ? .green : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(goal.isCompletedToday ? Color.green.opacity(0.12) : palette.stroke)
                    .clipShape(Capsule())
            }

            Spacer()

            Menu {
                Button(role: .destructive, action: onDelete) {
                    Label("Удалить", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(palette.stroke)
                    .clipShape(Circle())
            }
        }
        .padding(18)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
    }
}

private struct JournalHeaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var moodCustomization: MoodCustomizationManager

    let totalCount: Int
    let todayCount: Int
    let completedGoalsTodayCount: Int
    let streak: Int
    let dominantMood: Mood?
    let topSafeAreaInset: CGFloat

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(spacing: 8) {
                Text(Self.dayFormatter.string(from: .now).capitalized)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(palette.accentForeground.opacity(0.72))
                    .frame(maxWidth: .infinity)

                Text("Как прошёл день?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.accentForeground)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .frame(maxWidth: .infinity)

                Text(
                    dominantMood == nil
                        ? "Отмечай настроение и занятия за пару тапов, а приложение само соберёт твой красивый дневник."
                        : "У тебя уже складывается картина дня. Можно быстро добавить ещё одну запись или просто посмотреть на свой ритм."
                )
                .font(.subheadline)
                .foregroundStyle(palette.accentForeground.opacity(0.78))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 8)
            .padding(.horizontal, 12)

            HStack(alignment: .center, spacing: 14) {
                Group {
                    if let dominantMood {
                        MoodVisualView(
                            mood: dominantMood,
                            size: 58
                        )
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(palette.accentForeground)
                    }
                }
                .frame(width: 68, height: 68)
                .background(Color.white.opacity(0.24))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(dominantMood == nil ? "Сегодня ещё нет главной эмоции" : "Настроение дня")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.accentForeground.opacity(0.72))

                    Text(dominantMood.map(moodCustomization.title(for:)) ?? "Всё готово для первой записи")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.accentForeground)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)

                    Text(
                        dominantMood == nil
                            ? "Начни с плюсика внизу и собери день из эмоции, занятий и заметки."
                            : "Чаще всего сегодня ощущается \(dominantMood.map(moodCustomization.lowercaseTitle(for:)) ?? "")."
                    )
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(palette.accentForeground.opacity(0.78))
                }
            }
            .padding(18)
            .background(Color.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )

            HStack(spacing: 10) {
                DashboardMetricPill(
                    title: "Сегодня",
                    value: "\(todayCount)",
                    subtitle: "записей"
                )

                DashboardMetricPill(
                    title: "Серия",
                    value: "\(streak)",
                    subtitle: "дней"
                )

                DashboardMetricPill(
                    title: "Цели",
                    value: "\(completedGoalsTodayCount)",
                    subtitle: "закрыто"
                )
            }

            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.caption.weight(.bold))
                Text("\(totalCount) записей уже в дневнике")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(palette.accentForeground.opacity(0.82))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.18))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.top, topSafeAreaInset + 18)
        .padding(.horizontal, 20)
        .padding(.bottom, 26)
        .background(headerBackground)
        .clipShape(
            UnevenRoundedRectangle(
                cornerRadii: .init(bottomLeading: 32, bottomTrailing: 32),
                style: .continuous
            )
        )
        .overlay(
            UnevenRoundedRectangle(
                cornerRadii: .init(bottomLeading: 32, bottomTrailing: 32),
                style: .continuous
            )
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: palette.shadow, radius: 24, y: 16)
    }

    private var headerBackground: some View {
        LinearGradient(
            colors: [
                palette.floatingButtonSecondary.opacity(0.94),
                palette.floatingButton.opacity(0.9),
                palette.digestEnd.opacity(0.88)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct DashboardMetricPill: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.76))

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 92)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct WeekStripCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let summaries: [WeekDaySummary]

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Неделя")
                    .font(.headline)

                Text("Быстрый срез по дням, как в трекере настроения.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                let spacing: CGFloat = 6
                let itemWidth = max(38, floor((proxy.size.width - spacing * 6) / 7))
                let circleSize = min(46, itemWidth)

                HStack(spacing: spacing) {
                    ForEach(summaries) { summary in
                        VStack(spacing: 8) {
                            Text(summary.weekdayLabel)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)

                            ZStack {
                                Circle()
                                    .fill(summary.isToday ? palette.weekActiveBackground : palette.surface)
                                    .frame(width: circleSize, height: circleSize)

                                if let dominantMood = summary.dominantMood {
                                    MoodVisualView(
                                        mood: dominantMood,
                                        size: circleSize * 0.56
                                    )
                                } else {
                                    Circle()
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                        .foregroundStyle(.secondary.opacity(0.4))
                                        .frame(width: circleSize * 0.4, height: circleSize * 0.4)
                                }
                            }
                            .overlay(
                                Circle()
                                    .stroke(palette.stroke, lineWidth: summary.isToday ? 0 : 1)
                            )

                            VStack(spacing: 2) {
                                Text(summary.entryCount == 0 ? "—" : "\(summary.entryCount)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(summary.dayNumberLabel)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary.opacity(0.85))
                            }
                        }
                        .frame(width: itemWidth)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 100)
        }
        .padding(18)
        .background(palette.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
        .shadow(color: palette.cardShadow, radius: 18, y: 12)
    }
}

private struct EmptyJournalCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let action: () -> Void

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "face.smiling")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(palette.accentForeground)
                .frame(width: 58, height: 58)
                .background(palette.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(spacing: 6) {
                Text("Пока нет заметок")
                    .font(.title3.weight(.semibold))

                Text("Начни с короткой отметки и собери день в удобный трекер.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                EmptyStateFlowStep(title: "Эмоция")
                EmptyStateFlowStep(title: "Занятия")
                EmptyStateFlowStep(title: "Заметка")
            }

            Button(action: action) {
                Text("Начать первую запись")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(palette.floatingButtonForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [
                                palette.floatingButton,
                                palette.floatingButtonSecondary
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(palette.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
        .shadow(color: palette.cardShadow, radius: 18, y: 12)
    }
}

private struct EmptyStateFlowStep: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.38))
            .clipShape(Capsule())
    }
}

private struct TodayDigestCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var moodCustomization: MoodCustomizationManager

    let todayCount: Int
    let averageIntensity: Double?
    let dominantMood: Mood?

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    private var summarySubtitle: String {
        if dominantMood == nil {
            return "Первый взгляд на настроение дня: записи, сила эмоций и общий ритм."
        }

        return "Понятная мини-аналитика по сегодняшним отметкам, как в лёгком mood tracker."
    }

    private var focusValue: String {
        dominantMood.map(moodCustomization.title(for:)) ?? "Ищем"
    }

    private var insightTitle: String {
        dominantMood == nil ? "День только начинается" : "Главная эмоция дня"
    }

    private var insightDescription: String {
        guard let dominantMood else {
            return "Добавь ещё пару отметок, и картина дня станет яснее."
        }

        return "Сегодня чаще всего чувствуется \(moodCustomization.lowercaseTitle(for: dominantMood))."
    }

    private var entriesLabel: String {
        todayCount == 1 ? "1 запись" : "\(todayCount) записей"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Сводка дня")
                    .font(.title3.weight(.bold))

                Text(summarySubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    DigestMetric(
                        title: "Записей",
                        value: "\(todayCount)",
                        tint: palette.floatingButton,
                        isEmphasized: true
                    )

                    DigestMetric(
                        title: "Сила",
                        value: averageIntensity.map { "\(Int($0.rounded()))/10" } ?? "Нет",
                        tint: .orange,
                        isEmphasized: false
                    )
                }

                DigestMetric(
                    title: "Фокус",
                    value: focusValue,
                    tint: palette.accent,
                    isEmphasized: false
                )
            }

            HStack(spacing: 14) {
                DigestMoodArtwork(mood: dominantMood, palette: palette)

                VStack(alignment: .leading, spacing: 3) {
                    Text(insightTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(insightDescription)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Text(entriesLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accentForeground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(palette.accentSoft)
                    .clipShape(Capsule())
            }
            .padding(14)
            .background(Color.white.opacity(0.44))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    palette.digestStart,
                    palette.digestEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
        .shadow(color: palette.cardShadow, radius: 18, y: 12)
    }
}

private struct DigestMoodArtwork: View {
    let mood: Mood?
    let palette: ThemePalette

    var body: some View {
        Group {
            if let mood {
                MoodVisualView(
                    mood: mood,
                    size: 40
                )
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(palette.accentForeground)
            }
        }
        .frame(width: 52, height: 52)
        .background(Color.white.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct DigestMetric: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let value: String
    let tint: Color
    let isEmphasized: Bool

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: isEmphasized ? .leading : .center, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(isEmphasized ? palette.floatingButtonForeground.opacity(0.8) : .secondary)

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(isEmphasized ? palette.floatingButtonForeground : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .multilineTextAlignment(isEmphasized ? .leading : .center)
        .frame(maxWidth: .infinity, alignment: isEmphasized ? .leading : .center)
        .padding(14)
        .background(isEmphasized ? tint.opacity(0.92) : tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct DayTimelineSection: View {
    let group: DayEntryGroup
    let onDelete: (EmotionEntry) -> Void

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.setLocalizedDateFormatFromTemplate("d MMMM, EEEE")
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Self.dayFormatter.string(from: group.date).capitalized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(group.entries) { entry in
                    EntryRowCard(
                        entry: entry,
                        onDelete: {
                            onDelete(entry)
                        }
                    )
                }
            }
        }
    }
}

private struct EntryRowCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var moodCustomization: MoodCustomizationManager

    let entry: EmotionEntry
    let onDelete: () -> Void

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 8) {
                MoodVisualView(
                    mood: entry.mood,
                    size: 38
                )
                    .frame(width: 48, height: 48)
                    .background(entry.mood.tint.opacity(0.12))
                    .clipShape(Circle())

                Rectangle()
                    .fill(palette.stroke)
                    .frame(width: 1, height: 44)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(moodCustomization.title(for: entry.mood))
                            .font(.headline)

                        Text(entry.createdAt, format: .dateTime.day().month(.abbreviated).hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Menu {
                        Button(role: .destructive, action: onDelete) {
                            Label("Удалить", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .background(palette.stroke)
                            .clipShape(Circle())
                    }
                }

                HStack(spacing: 8) {
                    Text("Интенсивность")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(Int(entry.intensity))/10")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(entry.mood.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(entry.mood.tint.opacity(0.12))
                        .clipShape(Capsule())
                }

                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(5)
                } else if !entry.trigger.isEmpty {
                    Text(entry.trigger)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                } else {
                    Text("Без заметки")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !entry.activitySnapshots.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(entry.activitySnapshots) { activity in
                                ActivitySnapshotPill(snapshot: activity)
                            }
                        }
                    }
                }

                if !entry.trigger.isEmpty && !entry.note.isEmpty {
                    Text(entry.trigger)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(18)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
    }
}

private struct ActivitySnapshotPill: View {
    @Environment(\.colorScheme) private var colorScheme

    let snapshot: EntryActivitySnapshot

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 6) {
            ActivityVisualView(
                snapshot: snapshot,
                size: 12
            )

            Text(snapshot.title)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(palette.elevatedSurface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(palette.stroke, lineWidth: 1)
        )
    }
}

private struct WeekDaySummary: Identifiable {
    let date: Date
    let entryCount: Int
    let dominantMood: Mood?

    var id: Date { date }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var weekdayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"
        return formatter.string(from: date).capitalized
    }

    var dayNumberLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

private struct DayEntryGroup: Identifiable {
    let date: Date
    let entries: [EmotionEntry]

    var id: Date { date }
}

#Preview("Пусто") {
    ContentView()
        .modelContainer(for: [EmotionEntry.self, DailyGoal.self, ActivityOption.self], inMemory: true)
        .environmentObject(CloudAccountManager())
}

#Preview("С записями") {
    ContentView()
        .modelContainer(previewModelContainer)
        .environmentObject(CloudAccountManager())
}

private let previewModelContainer: ModelContainer = {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: EmotionEntry.self,
        DailyGoal.self,
        ActivityOption.self,
        configurations: configuration
    )

    container.mainContext.insert(
        ActivityOption(
            title: "Игры",
            symbolName: "gamecontroller.fill"
        )
    )
    container.mainContext.insert(
        ActivityOption(
            title: "Уборка",
            symbolName: "broom.fill"
        )
    )
    container.mainContext.insert(
        EmotionEntry(
            createdAt: .now.addingTimeInterval(-3_600),
            mood: .superb,
            intensity: 8,
            trigger: "Встреча с друзьями",
            note: "Сегодня наконец выдохнула после тяжелой недели. Было очень тепло и спокойно.",
            activitySnapshots: [
                EntryActivitySnapshot(title: "Игры", symbolName: "gamecontroller.fill"),
                EntryActivitySnapshot(title: "Общение", symbolName: "person.2.fill")
            ]
        )
    )
    container.mainContext.insert(
        EmotionEntry(
            createdAt: .now.addingTimeInterval(-14_000),
            mood: .soSo,
            intensity: 6,
            trigger: "Дедлайн на работе",
            note: "Сначала накрыла тревога, но после списка задач стало понятнее, что делать.",
            activitySnapshots: [
                EntryActivitySnapshot(title: "Работа", symbolName: "briefcase.fill"),
                EntryActivitySnapshot(title: "Уборка", symbolName: "broom.fill")
            ]
        )
    )
    container.mainContext.insert(
        DailyGoal(
            title: "Пройти прогулку после учебы"
        )
    )
    container.mainContext.insert(
        DailyGoal(
            title: "Записать три хороших события дня",
            lastCompletedAt: .now
        )
    )

    return container
}()
