//
//  RecordsSceneView
//  felix228
//
//  Created by Codex on 13.05.2026.
//

import SwiftUI
import UIKit
struct RecordsSceneView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var moodCustomization: MoodCustomizationManager

    let topInset: CGFloat
    let palette: ThemePalette
    let monthTitle: String
    let entries: [EmotionEntry]
    let goals: [DailyGoal]
    let completedGoalsTodayCount: Int
    @Binding var goalDraft: String
    @Binding var areGoalsExpanded: Bool
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onOpenMore: () -> Void
    let onAddGoal: () -> Void
    let onToggleGoal: (DailyGoal) -> Void
    let onDeleteGoal: (DailyGoal) -> Void
    let onDeleteEntry: (EmotionEntry) -> Void

    private var monthSummaryMood: Mood? {
        EmotionAnalytics.dominantMood(in: entries)
    }

    private var monthAverageIntensity: Int? {
        EmotionAnalytics.averageIntensity(in: entries).map { Int($0.rounded()) }
    }

    private var monthActiveDaysCount: Int {
        let calendar = Calendar.current
        return Set(entries.map { calendar.startOfDay(for: $0.createdAt) }).count
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
                    mood: monthSummaryMood,
                    title: monthSummaryMood.map(moodCustomization.title(for:)) ?? localization.pick("Пока пусто", "Nothing yet"),
                    subtitle: entries.isEmpty
                        ? localization.pick("Добавь первую запись за этот месяц.", "Add your first entry for this month.")
                        : localization.pick(
                            "\(entries.count) записей • \(monthActiveDaysCount) активных дней",
                            "\(entries.count) entries • \(monthActiveDaysCount) active days"
                        ),
                    accent: monthSummaryMood?.tint ?? palette.accent,
                    trailing: monthAverageIntensity.map {
                        localization.pick("Сила \($0)/10", "Intensity \($0)/10")
                    } ?? localization.pick("Без оценок", "No rating")
                )

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(localization.pick("Цели", "Goals"), systemImage: "target")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Spacer()

                        Button(areGoalsExpanded ? localization.pick("Скрыть", "Hide") : localization.pick("Показать", "Show")) {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                                areGoalsExpanded.toggle()
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(palette.accent)
                    }

                    if areGoalsExpanded {
                        DarkGoalsManagerCard(
                            palette: palette,
                            draftTitle: $goalDraft,
                            goals: goals,
                            completedTodayCount: completedGoalsTodayCount,
                            onAdd: onAddGoal,
                            onToggle: onToggleGoal,
                            onDelete: onDeleteGoal
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text(localization.pick("Записи", "Entries"))
                        .font(.headline.weight(.semibold))

                    if entries.isEmpty {
                        RecordsEmptyStateCard(palette: palette)
                    } else {
                        ForEach(entries) { entry in
                            JournalEntryCard(
                                entry: entry,
                                palette: palette,
                                onDelete: { onDeleteEntry(entry) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 150)
        }
    }
}
