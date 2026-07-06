//
//  JournalSharedComponents
//  felix228
//
//  Created by Codex on 13.05.2026.
//

import SwiftUI
import UIKit
struct MonthHeaderBar: View {
    let topInset: CGFloat
    let monthTitle: String
    let palette: ThemePalette
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onTrailingAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CircleIconButton(
                systemName: "chevron.left",
                tint: palette.floatingButtonForeground,
                background: palette.floatingButton,
                action: onPreviousMonth
            )

            Spacer(minLength: 0)

            Text(monthTitle)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            CircleIconButton(
                systemName: "chevron.right",
                tint: palette.floatingButtonForeground,
                background: palette.floatingButton,
                action: onNextMonth
            )

            CircleIconButton(
                systemName: "ellipsis",
                tint: .white.opacity(0.9),
                background: palette.surface.opacity(0.94),
                action: onTrailingAction
            )
        }
        .padding(.top, topInset + 12)
    }
}

struct JournalSummaryStrip: View {
    let palette: ThemePalette
    let mood: Mood?
    let title: String
    let subtitle: String
    let accent: Color
    let trailing: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 54, height: 54)

                Circle()
                    .stroke(accent.opacity(0.45), lineWidth: 1.5)
                    .frame(width: 54, height: 54)

                if let mood {
                    MoodVisualView(
                        mood: mood,
                        size: 34
                    )
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(trailing)
                .font(.headline.weight(.medium))
                .foregroundStyle(accent)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(palette.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
    }
}

struct CalendarOverviewSummaryStrip: View {
    let palette: ThemePalette
    let accent: Color
    let leading: CalendarOverviewLeadingVisual
    let title: String
    let subtitle: String
    let trailing: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 54, height: 54)

                Circle()
                    .stroke(accent.opacity(0.45), lineWidth: 1.5)
                    .frame(width: 54, height: 54)

                leadingView
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(trailing)
                .font(.headline.weight(.medium))
                .foregroundStyle(accent)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(palette.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var leadingView: some View {
        switch leading {
        case .mood(let mood):
            MoodVisualView(
                mood: mood,
                size: 34
            )
        case .activity(let snapshot):
            ActivityVisualView(
                snapshot: snapshot,
                size: 26,
                tint: accent
            )
        case .goal(let isHighlighted):
            Image(systemName: isHighlighted ? "checkmark.circle.fill" : "target")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(accent)
        case .system(let systemName):
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(accent)
        }
    }
}

struct CalendarOverviewControlsCard: View {
    @EnvironmentObject private var localization: LocalizationManager

    let palette: ThemePalette
    @Binding var selectedMode: CalendarOverviewMode
    let selectedActivity: CalendarActivityChoice?
    let activityChoices: [CalendarActivityChoice]
    let onSelectActivity: (CalendarActivityChoice) -> Void
    let selectedGoal: DailyGoal?
    let goals: [DailyGoal]
    let onSelectGoal: (DailyGoal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ForEach(CalendarOverviewMode.allCases) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: mode.systemImage)
                                .font(.caption.weight(.bold))
                            Text(localization.title(for: mode))
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(selectedMode == mode ? palette.accentForeground : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule()
                                .fill(selectedMode == mode ? palette.accent : Color.white.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            switch selectedMode {
            case .moods:
                EmptyView()

            case .activities:
                if activityChoices.isEmpty {
                    EmptyBadgeRow(
                        palette: palette,
                        text: localization.pick(
                            "Добавь хотя бы одно занятие, и календарь начнёт показывать его по дням.",
                            "Add at least one activity and the calendar will start showing it by day."
                        )
                    )
                } else {
                    Menu {
                        ForEach(activityChoices) { choice in
                            Button {
                                onSelectActivity(choice)
                            } label: {
                                Label {
                                    Text(choice.title)
                                } icon: {
                                    ActivityVisualView(
                                        snapshot: choice.snapshot,
                                        size: 14,
                                        tint: palette.accent
                                    )
                                }
                            }
                        }
                    } label: {
                        CalendarFilterPill(
                            palette: palette,
                            title: selectedActivity?.title ?? localization.pick("Выбери занятие", "Choose an activity"),
                            systemImage: nil,
                            activity: selectedActivity?.snapshot
                        )
                    }
                    .buttonStyle(.plain)
                }

            case .goals:
                if goals.isEmpty {
                    EmptyBadgeRow(
                        palette: palette,
                        text: localization.pick(
                            "Добавь хотя бы одну цель, и календарь покажет её выполнение.",
                            "Add at least one goal and the calendar will show its completion."
                        )
                    )
                } else {
                    Menu {
                        ForEach(goals) { goal in
                            Button {
                                onSelectGoal(goal)
                            } label: {
                                Label(goal.title, systemImage: goal.isCompletedToday ? "checkmark.circle.fill" : "target")
                            }
                        }
                    } label: {
                        CalendarFilterPill(
                            palette: palette,
                            title: selectedGoal?.title ?? localization.pick("Выбери цель", "Choose a goal"),
                            systemImage: selectedGoal?.isCompletedToday == true ? "checkmark.circle.fill" : "target",
                            activity: nil
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(palette.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
    }
}

struct CalendarFilterPill: View {
    let palette: ThemePalette
    let title: String
    let systemImage: String?
    let activity: EntryActivitySnapshot?

    var body: some View {
        HStack(spacing: 10) {
            if let activity {
                ActivityVisualView(
                    snapshot: activity,
                    size: 16,
                    tint: palette.accent
                )
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.accent)
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct CalendarOverviewMetricsCard: View {
    let palette: ThemePalette
    let title: String
    let subtitle: String
    let items: [CalendarMetricItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ForEach(items) { item in
                    MetricCapsuleCard(
                        palette: palette,
                        title: item.title,
                        value: item.value,
                        tint: item.tint
                    )
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(palette.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
    }
}

struct CalendarGoalStatusCard: View {
    @EnvironmentObject private var localization: LocalizationManager

    let palette: ThemePalette
    let goalTitle: String
    let isCompleted: Bool
    let entriesCount: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill((isCompleted ? palette.accent : Color.white.opacity(0.06)))
                    .frame(width: 52, height: 52)

                Image(systemName: isCompleted ? "checkmark" : "target")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(isCompleted ? palette.accentForeground : .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(goalTitle)
                    .font(.headline.weight(.semibold))

                Text(
                    isCompleted
                        ? localization.pick("Цель выполнена в этот день.", "This goal was completed on this day.")
                        : localization.pick("В этот день цель не была отмечена выполненной.", "This goal was not marked complete on this day.")
                )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if entriesCount > 0 {
                    Text(localization.pick(
                        "\(entriesCount) записей за выбранный день",
                        "\(entriesCount) entries on the selected day"
                    ))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isCompleted ? palette.accent : .secondary)
                }
            }

            Spacer()
        }
        .padding(18)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct DarkGoalsManagerCard: View {
    @EnvironmentObject private var localization: LocalizationManager

    let palette: ThemePalette
    @Binding var draftTitle: String
    let goals: [DailyGoal]
    let completedTodayCount: Int
    let onAdd: () -> Void
    let onToggle: (DailyGoal) -> Void
    let onDelete: (DailyGoal) -> Void

    private var draftIsEmpty: Bool {
        draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(
                    goals.isEmpty
                        ? localization.pick("Добавь цель на день", "Add a goal for the day")
                        : localization.pick(
                            "Выполнено сегодня: \(completedTodayCount) из \(goals.count)",
                            "Completed today: \(completedTodayCount) of \(goals.count)"
                        )
                )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if !goals.isEmpty {
                    Text("\(completedTodayCount)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(palette.accent)
                }
            }

            HStack(spacing: 12) {
                TextField(localization.pick("Например: выпить воду или выйти на прогулку", "For example: drink water or go for a walk"), text: $draftTitle)
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
                    .onSubmit(onAdd)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.black.opacity(0.18))
                    )

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(palette.floatingButtonForeground)
                        .frame(width: 52, height: 52)
                        .background(draftIsEmpty ? Color.white.opacity(0.08) : palette.floatingButton)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(draftIsEmpty)
            }

            if goals.isEmpty {
                EmptyBadgeRow(
                    palette: palette,
                    text: localization.pick(
                        "Когда появятся цели, здесь будет виден прогресс дня.",
                        "Once you add goals, the day’s progress will appear here."
                    )
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(goals.prefix(4)) { goal in
                        HStack(spacing: 12) {
                            Button {
                                onToggle(goal)
                            } label: {
                                Image(systemName: goal.isCompletedToday ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(goal.isCompletedToday ? palette.accent : .secondary)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(goal.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .strikethrough(goal.isCompletedToday, color: .secondary)

                                Text(
                                    goal.isCompletedToday
                                        ? localization.pick("Закрыто сегодня", "Done today")
                                        : localization.pick("Ещё в процессе", "Still in progress")
                                )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                onDelete(goal)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.white.opacity(0.82))
                                    .frame(width: 34, height: 34)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.black.opacity(0.14))
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(palette.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
    }
}

struct RecordsEmptyStateCard: View {
    @EnvironmentObject private var localization: LocalizationManager

    let palette: ThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localization.pick("Пока нет записей за этот месяц", "No entries for this month yet"))
                .font(.title3.weight(.semibold))

            Text(localization.pick(
                "Создай первую отметку через зелёную кнопку справа внизу. После этого здесь появится твоя лента дней.",
                "Create your first entry with the green button at the bottom right. Your timeline will appear here after that."
            ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(palette.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
    }
}

struct JournalEntryCard: View {
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var moodCustomization: MoodCustomizationManager

    let entry: EmotionEntry
    let palette: ThemePalette
    var compact: Bool = false
    let onDelete: () -> Void

    private var titleText: String {
        moodCustomization.lowercaseTitle(for: entry.mood)
    }

    private var dateText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(entry.createdAt) {
            return localization.pick(
                "Сегодня, \(localization.dayMonthTitle(from: entry.createdAt))",
                "Today, \(localization.dayMonthTitle(from: entry.createdAt))"
            )
        }

        if calendar.isDateInYesterday(entry.createdAt) {
            return localization.pick(
                "Вчера, \(localization.dayMonthTitle(from: entry.createdAt))",
                "Yesterday, \(localization.dayMonthTitle(from: entry.createdAt))"
            )
        }

        return entry.createdAt.formatted(
            .dateTime
                .weekday(.wide)
                .day()
                .month(.wide)
                .locale(localization.locale)
        ).capitalized
    }

    private var detailText: String {
        if !entry.note.isEmpty { return entry.note }
        if !entry.trigger.isEmpty { return entry.trigger }
        return localization.pick("Без заметки", "No note")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 14 : 18) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(entry.mood.tint.opacity(0.85), lineWidth: 2.5)
                        .frame(width: compact ? 58 : 68, height: compact ? 58 : 68)

                    MoodVisualView(
                        mood: entry.mood,
                        size: compact ? 38 : 46
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(dateText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(alignment: .lastTextBaseline, spacing: 10) {
                        Text(titleText)
                            .font(.system(size: compact ? 28 : 34, weight: .bold, design: .rounded))
                            .foregroundStyle(entry.mood.tint)

                        Text(entry.createdAt.formatted(.dateTime.hour().minute().locale(localization.locale)))
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label(localization.pick("Удалить", "Delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
            }

            if !entry.activitySnapshots.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(entry.activitySnapshots) { activity in
                            HStack(spacing: 6) {
                                ActivityVisualView(
                                    snapshot: activity,
                                    size: 12
                                )
                                Text(activity.title)
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            Text(detailText)
                .font(.body)
                .foregroundStyle(detailText == localization.pick("Без заметки", "No note") ? .secondary : .primary)
                .lineLimit(compact ? 3 : 5)

            HStack(spacing: 10) {
                Label("\(Int(entry.intensity))/10", systemImage: "bolt.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(entry.mood.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(entry.mood.tint.opacity(0.14))
                    .clipShape(Capsule())

                if !entry.trigger.isEmpty && !entry.note.isEmpty {
                    Text(entry.trigger)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(compact ? 18 : 22)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(palette.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
    }
}

struct StatisticsHeroCard: View {
    let palette: ThemePalette
    let title: String
    let totalCount: Int
    let averageIntensity: Int?
    let activeDaysCount: Int
    let monthDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text(totalCount == 0 ? "Месяц пока пустой, но здесь быстро появится ритм твоих дней." : "\(totalCount) отметок уже собрали картину месяца.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                MetricCapsuleCard(
                    palette: palette,
                    title: "Дней",
                    value: "\(activeDaysCount)",
                    tint: palette.accent
                )
                MetricCapsuleCard(
                    palette: palette,
                    title: "Сила",
                    value: averageIntensity.map { "\($0)/10" } ?? "—",
                    tint: palette.floatingButtonSecondary
                )
                MetricCapsuleCard(
                    palette: palette,
                    title: "Месяц",
                    value: monthDate.formatted(.dateTime.month(.wide)),
                    tint: palette.accent
                )
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(palette.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
    }
}

struct MoodGaugeCard: View {
    @EnvironmentObject private var localization: LocalizationManager

    let title: String
    let subtitle: String
    let items: [MoodStatItem]
    let palette: ThemePalette

    private let legendColumns = [
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12)
    ]

    private var total: Int {
        items.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if total > 0 {
                VStack(spacing: 16) {
                    MoodSemiCircleGauge(items: items)
                        .frame(height: 178)
                        .padding(.horizontal, 2)

                    MoodGaugeScaleStrip(items: items)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                LazyVGrid(columns: legendColumns, alignment: .leading, spacing: 12) {
                    ForEach(items) { item in
                        MoodCounterLegendTile(item: item)
                    }
                }
            } else {
                MoodGaugeEmptySummary(localization: localization)

                MoodGaugeScaleStrip(items: items)

                EmptyBadgeRow(
                    palette: palette,
                    text: localization.pick(
                        "Когда появятся записи, здесь будут считаться все пять настроений.",
                        "As soon as entries appear, all five moods will be counted here."
                    )
                )
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(palette.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
    }
}

struct MoodGaugeEmptySummary: View {
    let localization: LocalizationManager

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 78, height: 78)

                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1.5)
                    .frame(width: 78, height: 78)

                Text("0")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Text(localization.pick("записей", "entries"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

struct CalendarGridCard: View {
    @EnvironmentObject private var localization: LocalizationManager

    let palette: ThemePalette
    let monthTitle: String
    let summaryText: String
    let days: [CalendarDayCellModel]
    @Binding var selectedDay: Date?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)

    private var weekdayTitles: [String] {
        switch localization.selectedLanguage {
        case .russian:
            ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
        case .ukrainian:
            ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Нд"]
        case .english:
            ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(monthTitle)
                    .font(.headline.weight(.semibold))
                Spacer()
                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(weekdayTitles, id: \.self) { title in
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                ForEach(days) { day in
                    if let date = day.date {
                        Button {
                            selectedDay = date
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(dayBackground(day))
                                        .frame(width: 42, height: 42)

                                    if day.isActive {
                                        dayIndicator(day)
                                    } else {
                                        Circle()
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1.5)
                                            .frame(width: 42, height: 42)
                                    }
                                }
                                .overlay(
                                    Circle()
                                        .stroke(isSelected(date: date) ? palette.accent : Color.clear, lineWidth: 2)
                                )

                                Text(date.formatted(.dateTime.day()))
                                    .font(.caption.weight(day.isToday ? .bold : .medium))
                                    .foregroundStyle(day.isToday ? palette.accent : .primary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    } else {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(Color.white.opacity(0.04))
                                .frame(width: 42, height: 42)
                            Text(" ")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(palette.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
    }

    private func isSelected(date: Date) -> Bool {
        guard let selectedDay else { return false }
        return Calendar.current.isDate(selectedDay, inSameDayAs: date)
    }

    private func dayBackground(_ day: CalendarDayCellModel) -> Color {
        switch day.indicator {
        case .mood(let mood):
            return mood.tint.opacity(0.22)
        case .activity:
            return palette.accent.opacity(0.18)
        case .goal(let isCompleted):
            return isCompleted ? palette.floatingButtonSecondary.opacity(0.2) : defaultBackground(for: day)
        case .empty:
            return defaultBackground(for: day)
        }
    }

    @ViewBuilder
    private func dayIndicator(_ day: CalendarDayCellModel) -> some View {
        switch day.indicator {
        case .mood(let mood):
            MoodVisualView(
                mood: mood,
                size: 24
            )
        case .activity(let snapshot):
            ActivityVisualView(
                snapshot: snapshot,
                size: 18,
                tint: palette.accent
            )
        case .goal(let isCompleted):
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(palette.floatingButtonSecondary)
            } else {
                EmptyView()
            }
        case .empty:
            EmptyView()
        }
    }

    private func defaultBackground(for day: CalendarDayCellModel) -> Color {
        day.isToday ? palette.accent.opacity(0.14) : Color.white.opacity(0.04)
    }
}

struct StatisticsSectionCard<Content: View>: View {
    let palette: ThemePalette
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    init(
        palette: ThemePalette,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.palette = palette
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                }
            }

            content
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(palette.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
    }
}

struct MoreSectionCard: View {
    let palette: ThemePalette
    let title: String
    let rows: [MoreRowModel]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(palette.primaryText)

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    MoreRowView(
                        row: row,
                        palette: palette
                    )

                    if row.id != rows.last?.id {
                        Divider()
                            .overlay(palette.stroke.opacity(0.7))
                            .padding(.leading, 68)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(palette.elevatedSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(palette.stroke, lineWidth: 1)
            )
        }
    }
}

struct MoreRowView: View {
    let row: MoreRowModel
    let palette: ThemePalette

    var body: some View {
        Group {
            if let action = row.action {
                Button(action: action) {
                    rowBody
                }
                .buttonStyle(.plain)
            } else {
                rowBody
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private var rowBody: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(row.tint)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: row.icon)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(palette.floatingButtonForeground)
                )

            Text(row.title)
                .font(.title3.weight(.medium))
                .foregroundStyle(palette.primaryText)

            Spacer()

            if let trailingText = row.trailingText {
                Text(trailingText)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.secondaryText.opacity(0.8))
        }
    }
}

struct MoodSemiCircleGauge: View {
    @EnvironmentObject private var localization: LocalizationManager

    let items: [MoodStatItem]

    private var total: Double {
        Double(items.reduce(0) { $0 + $1.count })
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let horizontalInset: CGFloat = 28
            let topInset: CGFloat = 14
            let bottomInset: CGFloat = 24
            let strokeWidth = min(max(size.width * 0.06, 18), 22)
            let availableWidthRadius = (size.width - (horizontalInset * 2) - strokeWidth) / 2
            let availableHeightRadius = size.height - topInset - bottomInset - strokeWidth
            let radius = max(min(availableWidthRadius, availableHeightRadius), 0)
            let center = CGPoint(
                x: size.width / 2,
                y: topInset + radius + strokeWidth / 2
            )
            let labelY = max(topInset + 30, center.y - radius * 0.22)

            ZStack {
                GaugeArcShape(
                    startFraction: 0,
                    endFraction: 1,
                    radius: radius,
                    center: center
                )
                .stroke(
                    Color.white.opacity(0.06),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let start = startFraction(before: index)
                    let end = start + fraction(for: item)

                    GaugeArcShape(
                        startFraction: start,
                        endFraction: end,
                        radius: radius,
                        center: center
                    )
                        .stroke(
                            item.count == 0 ? Color.white.opacity(0.10) : item.mood.tint,
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                        )
                }

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let markerFraction = startFraction(before: index) + (fraction(for: item) / 2)
                    let markerPoint = point(
                        at: markerFraction,
                        radius: radius + strokeWidth * 0.56,
                        center: center
                    )

                    Circle()
                        .fill(item.count == 0 ? Color.white.opacity(0.18) : item.mood.tint)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.24), lineWidth: 1)
                        )
                        .position(markerPoint)
                }

                VStack(spacing: 6) {
                    Text(total == 0 ? "0" : "\(Int(total))")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text(localization.pick("записей", "entries"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .position(x: size.width / 2, y: labelY)
            }
        }
    }

    private func fraction(for item: MoodStatItem) -> Double {
        guard total > 0 else { return 1.0 / Double(max(items.count, 1)) }
        return Double(item.count) / total
    }

    private func startFraction(before index: Int) -> Double {
        guard index > 0 else { return 0 }
        return items[..<index].reduce(0) { partial, item in
            partial + fraction(for: item)
        }
    }

    private func point(at fraction: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let angle = Double.pi - (Double.pi * fraction)
        return CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius,
            y: center.y - CGFloat(sin(angle)) * radius
        )
    }
}

struct MoodGaugeScaleStrip: View {
    @EnvironmentObject private var moodCustomization: MoodCustomizationManager

    let items: [MoodStatItem]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(item.count == 0 ? item.mood.tint.opacity(0.14) : item.mood.tint.opacity(0.2))
                            .frame(width: 28, height: 28)

                        Circle()
                            .fill(item.count == 0 ? Color.white.opacity(0.18) : item.mood.tint)
                            .frame(width: 10, height: 10)
                    }

                    Text(moodCustomization.title(for: item.mood))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(item.count == 0 ? .secondary : item.mood.tint)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                if index < items.count - 1 {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 2)
                        .padding(.horizontal, 4)
                        .padding(.top, 13)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct GaugeArcShape: Shape {
    let startFraction: Double
    let endFraction: Double
    var radius: CGFloat? = nil
    var center: CGPoint? = nil

    func path(in rect: CGRect) -> Path {
        let resolvedRadius = radius ?? min(rect.width / 2, rect.height) - 18
        let resolvedCenter = center ?? CGPoint(x: rect.midX, y: rect.maxY - 8)
        let startAngle = Angle.degrees(180 - (180 * startFraction))
        let endAngle = Angle.degrees(180 - (180 * endFraction))

        var path = Path()
        path.addArc(
            center: resolvedCenter,
            radius: resolvedRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )
        return path
    }
}

struct MoodCounterLegendTile: View {
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var moodCustomization: MoodCustomizationManager

    let item: MoodStatItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.mood.tint.opacity(0.12))
                    .frame(width: 44, height: 44)

                ZStack {
                    MoodVisualView(
                        mood: item.mood,
                        size: 24
                    )
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(moodCustomization.title(for: item.mood))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(
                    localization.pick(
                        item.count == 1 ? "запись" : "записей",
                        item.count == 1 ? "entry" : "entries"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text("\(item.count)")
                .font(.headline.weight(.bold))
                .foregroundStyle(item.count == 0 ? .secondary : item.mood.tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct MoodLegendChip: View {
    @EnvironmentObject private var moodCustomization: MoodCustomizationManager

    let item: MoodStatItem

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(item.mood.tint)
                .frame(width: 10, height: 10)

            Text(moodCustomization.title(for: item.mood))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            Text("\(item.count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(item.count == 0 ? .secondary : item.mood.tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }
}

struct MetricCapsuleCard: View {
    let palette: ThemePalette
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.26), lineWidth: 1)
        )
    }
}

struct EmptyBadgeRow: View {
    let palette: ThemePalette
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct CircleIconButton: View {
    let systemName: String
    let tint: Color
    let background: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(background)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct ActivityStatChip: View {
    let palette: ThemePalette
    let snapshot: EntryActivitySnapshot
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            ActivityVisualView(
                snapshot: snapshot,
                size: 12
            )
            Text(snapshot.title)
                .font(.caption.weight(.semibold))
            Text("\(count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }
}

struct StatisticsAchievementsPreviewCard: View {
    @EnvironmentObject private var localization: LocalizationManager

    let palette: ThemePalette
    let badges: [FelixAchievementBadge]
    let unlockedCount: Int
    let totalCount: Int
    let onShowAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localization.pick("Достижения", "Achievements"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))

                    Text(localization.pick(
                        "Первые награды месяца и твой общий прогресс.",
                        "The first rewards of the month and your overall progress."
                    ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(localization.pick("Показать всё", "Show all"), action: onShowAll)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: 18) {
                ForEach(badges) { badge in
                    StatisticsAchievementMedal(
                        badge: badge,
                        palette: palette
                    )
                }
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            HStack {
                Text(localization.pick("\(unlockedCount) из \(totalCount)", "\(unlockedCount) of \(totalCount)"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)

                Text(
                    unlockedCount == 0
                        ? localization.pick("наград ещё впереди", "rewards still ahead")
                        : localization.pick("достижений уже открыто", "achievements already unlocked")
                )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(palette.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
    }
}

private struct StatisticsAchievementMedal: View {
    let badge: FelixAchievementBadge
    let palette: ThemePalette

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 78, height: 78)

                Circle()
                    .trim(from: 0.08, to: 0.92)
                    .stroke(
                        badge.isUnlocked ? badge.tint : Color.white.opacity(0.18),
                        style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(96))
                    .frame(width: 78, height: 78)

                if let artworkAssetName = badge.artworkAssetName {
                    Image(artworkAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                        .opacity(badge.isUnlocked ? 1 : 0.36)
                } else {
                    Image(systemName: badge.icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(badge.isUnlocked ? badge.tint : .secondary)
                }
            }

            Text(badge.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            StatisticsAchievementStarsRow(activeCount: badge.isUnlocked ? badge.starCount : 0)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private struct StatisticsAchievementStarsRow: View {
    let activeCount: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < activeCount ? "star.fill" : "star")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(index < activeCount ? Color(red: 0.45, green: 0.93, blue: 0.56) : .secondary.opacity(0.65))
            }
        }
    }
}

struct StatisticsStreakCard: View {
    @EnvironmentObject private var localization: LocalizationManager

    let palette: ThemePalette
    let streak: Int
    let days: [StatisticsStreakDay]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localization.pick("Дней подряд", "Days in a row"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))

                    Text(
                        streak == 0
                            ? localization.pick(
                                "Серия ещё не началась, но первый день уже рядом.",
                                "Your streak hasn’t started yet, but the first day is close."
                            )
                            : localization.pick(
                                "Текущая серия записей без пропусков.",
                                "Your current streak of entries without missing a day."
                            )
                    )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(streak)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.05))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            }

            HStack(spacing: 10) {
                if days.isEmpty {
                    ForEach(0..<5, id: \.self) { _ in
                        VStack(spacing: 8) {
                            Circle()
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 46, height: 46)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )

                            Text("—")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    ForEach(days) { day in
                        StatisticsStreakDayBubble(
                            palette: palette,
                            day: day
                        )
                    }
                }
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            Label(
                streak == 0
                    ? localization.pick(
                        "Начни с первой записи, и здесь появится серия.",
                        "Start with your first entry and a streak will appear here."
                    )
                    : localization.pick(
                        "Сейчас у тебя серия на \(streak) \(streak == 1 ? "день" : "дней").",
                        "You currently have a streak of \(streak) \(streak == 1 ? "day" : "days")."
                    ),
                systemImage: streak == 0 ? "sparkles" : "trophy.fill"
            )
            .font(.subheadline.weight(.medium))
            .foregroundStyle(streak == 0 ? .secondary : palette.accent)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(palette.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
    }
}

private struct StatisticsStreakDayBubble: View {
    let palette: ThemePalette
    let day: StatisticsStreakDay

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(palette.accent)
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(palette.accentForeground)
                )

            Text(day.label)
                .font(.caption.weight(day.isToday ? .bold : .semibold))
                .foregroundStyle(day.isToday ? palette.accent : .secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MoodTrendCard: View {
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var moodCustomization: MoodCustomizationManager

    let palette: ThemePalette
    let title: String
    let subtitle: String
    let points: [StatisticsMoodTrendPoint]
    let dayCount: Int
    let footerHighlight: String?

    private let axisMoods: [Mood] = [.superb, .normal, .soSo, .tired, .bad]

    private var xAxisValues: [Int] {
        guard dayCount > 0 else { return [] }
        let step = max(dayCount / 6, 1)
        var values = Array(stride(from: 1, through: dayCount, by: step))
        if values.last != dayCount {
            values.append(dayCount)
        }
        return values
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if points.isEmpty {
                EmptyBadgeRow(
                    palette: palette,
                    text: localization.pick(
                        "Как только в месяце появятся записи, здесь выстроится линия настроения по дням.",
                        "As soon as this month gets entries, a mood line by day will appear here."
                    )
                )
            } else {
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        ForEach(axisMoods, id: \.id) { mood in
                            MoodVisualView(
                                mood: mood,
                                size: 24
                            )
                            .frame(height: 44)
                        }
                    }
                    .padding(.top, 8)

                    MoodTrendChart(points: points, dayCount: dayCount)
                        .frame(height: 228)
                }

                HStack {
                    ForEach(xAxisValues, id: \.self) { value in
                        Text("\(value)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                if let footerHighlight, !footerHighlight.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "star.circle.fill")
                            .font(.headline)
                            .foregroundStyle(palette.accent)

                        Text(localization.pick(
                            "Чаще всего рядом: \(footerHighlight)",
                            "Most often together with: \(footerHighlight)"
                        ))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(palette.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
    }
}

private struct MoodTrendChart: View {
    let points: [StatisticsMoodTrendPoint]
    let dayCount: Int

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let chartHeight = height - 8
            let resolvedPoints = points.map { point in
                CGPoint(
                    x: xPosition(for: point.dayNumber, width: width),
                    y: yPosition(for: point.score, height: chartHeight)
                )
            }

            ZStack {
                ForEach(0..<5, id: \.self) { index in
                    let y = yPosition(for: Double(5 - index), height: chartHeight)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }

                if let firstPoint = resolvedPoints.first {
                    Path { path in
                        path.move(to: CGPoint(x: firstPoint.x, y: chartHeight))
                        path.addLine(to: firstPoint)

                        for point in resolvedPoints.dropFirst() {
                            path.addLine(to: point)
                        }

                        if let lastPoint = resolvedPoints.last {
                            path.addLine(to: CGPoint(x: lastPoint.x, y: chartHeight))
                        }

                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [
                                Mood.superb.tint.opacity(0.18),
                                Mood.normal.tint.opacity(0.14),
                                Mood.bad.tint.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                if resolvedPoints.count >= 2 {
                    Path { path in
                        path.move(to: resolvedPoints[0])
                        for point in resolvedPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [
                                Mood.superb.tint,
                                Mood.normal.tint,
                                Mood.soSo.tint,
                                Mood.tired.tint
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                }

                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    let resolvedPoint = resolvedPoints[index]
                    Circle()
                        .fill(color(for: point.score))
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.16), lineWidth: 2)
                        )
                        .position(resolvedPoint)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func xPosition(for dayNumber: Int, width: CGFloat) -> CGFloat {
        guard dayCount > 1 else { return width / 2 }
        return (CGFloat(dayNumber - 1) / CGFloat(dayCount - 1)) * width
    }

    private func yPosition(for score: Double, height: CGFloat) -> CGFloat {
        let normalized = max(0, min((score - 1) / 4, 1))
        return height - (CGFloat(normalized) * height)
    }

    private func color(for score: Double) -> Color {
        switch score {
        case ..<1.8:
            return Mood.bad.tint
        case ..<2.6:
            return Mood.tired.tint
        case ..<3.4:
            return Mood.soSo.tint
        case ..<4.3:
            return Mood.normal.tint
        default:
            return Mood.superb.tint
        }
    }
}

struct WrappingChipsLayout<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat, lineSpacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.content = content()
    }

    var body: some View {
        FlowChipLayout(horizontalSpacing: spacing, verticalSpacing: lineSpacing) {
            content
        }
    }
}

struct FlowChipLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        guard width > 0 else {
            let maxWidth = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
            let totalHeight = subviews.reduce(CGFloat.zero) { partial, view in
                partial + view.sizeThatFits(.unspecified).height
            }
            return CGSize(width: maxWidth, height: totalHeight)
        }

        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > width, currentRowWidth > 0 {
                totalHeight += currentRowHeight + verticalSpacing
                currentRowWidth = size.width + horizontalSpacing
                currentRowHeight = size.height
            } else {
                currentRowWidth += size.width + (currentRowWidth == 0 ? 0 : horizontalSpacing)
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }

        totalHeight += currentRowHeight
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > bounds.maxX, origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += currentRowHeight + verticalSpacing
                currentRowHeight = 0
            }

            subview.place(
                at: origin,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            origin.x += size.width + horizontalSpacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}
