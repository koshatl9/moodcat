//
//  EntryComposerView.swift
//  felix228
//
//  Created by Codex on 12.05.2026.
//

import SwiftUI
import SwiftData

private enum ComposerStep {
    case moodSelection
    case activitySelection
    case noteDetails
}

struct EntryComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var cloudAccount: CloudAccountManager
    @EnvironmentObject private var achievementManager: AchievementManager
    @Query(sort: [SortDescriptor(\ActivityOption.createdAt, order: .forward)])
    private var activities: [ActivityOption]
    @Query(sort: [SortDescriptor(\DailyGoal.createdAt, order: .forward)])
    private var goals: [DailyGoal]

    @State private var composerStep: ComposerStep
    @State private var selectedMood: Mood?
    @State private var selectedActivityKeys: Set<String> = []
    @State private var completedGoalIDs: Set<ObjectIdentifier> = []
    @State private var hasSeededGoalSelection = false
    @State private var isPresentingActivityEditor = false
    @State private var intensity: Double = 5
    @State private var note: String = ""
    @State private var saveErrorMessage: String?
    @FocusState private var isNoteFocused: Bool
    private let onSave: (Date) -> Void

    init(initialMood: Mood? = nil, onSave: @escaping (Date) -> Void = { _ in }) {
        self.onSave = onSave
        _selectedMood = State(initialValue: initialMood)
        _composerStep = State(initialValue: initialMood == nil ? .moodSelection : .activitySelection)
    }

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    private var activeMood: Mood {
        selectedMood ?? .normal
    }

    private var sortedActivities: [ActivityOption] {
        activities
    }

    private var selectedActivities: [ActivityOption] {
        sortedActivities.filter { selectedActivityKeys.contains($0.lookupKey) }
    }

    private var sortedGoals: [DailyGoal] {
        goals.sorted { lhs, rhs in
            if isGoalSelected(lhs) != isGoalSelected(rhs) {
                return !isGoalSelected(lhs) && isGoalSelected(rhs)
            }

            return lhs.createdAt < rhs.createdAt
        }
    }

    private let moodColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private let activityColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView(palette: palette)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        switch composerStep {
                        case .moodSelection:
                            MoodSelectionIntroCard()

                            LazyVGrid(columns: moodColumns, spacing: 14) {
                                ForEach(Mood.allCases) { mood in
                                    MoodEmojiCard(
                                        mood: mood,
                                        isSelected: selectedMood == mood
                                    ) {
                                        chooseMood(mood)
                                    }
                                }
                            }

                        case .activitySelection:
                            if let selectedMood {
                                SelectedMoodHeaderCard(
                                    mood: selectedMood,
                                    changeMoodAction: returnToMoodSelection
                                )

                                ActivitySelectionCard(
                                    activities: sortedActivities,
                                    selectedActivityKeys: selectedActivityKeys,
                                    openEditorAction: {
                                        isPresentingActivityEditor = true
                                    },
                                    toggleSelectionAction: toggleActivitySelection
                                )
                            }

                        case .noteDetails:
                            if let selectedMood {
                                SelectedMoodHeaderCard(
                                    mood: selectedMood,
                                    changeMoodAction: returnToMoodSelection
                                )

                                SelectedActivitiesSummaryCard(
                                    activities: selectedActivities,
                                    changeActivitiesAction: returnToActivitySelection
                                )

                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Что произошло сегодня?")
                                            .font(.headline.weight(.semibold))

                                        Spacer()

                                        MoodVisualView(mood: selectedMood, size: 30)
                                    }

                                    ZStack(alignment: .topLeading) {
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .fill(palette.surface)

                                        if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            Text("Напиши заметку про день: что случилось, что задело, что порадовало и что хочется запомнить.")
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 18)
                                        }

                                        TextEditor(text: $note)
                                            .font(.body)
                                            .focused($isNoteFocused)
                                            .scrollContentBackground(.hidden)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .frame(minHeight: 220)
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .stroke(palette.stroke, lineWidth: 1)
                                    )
                                }

                                GoalsCompletionCard(
                                    goals: sortedGoals,
                                    isSelected: isGoalSelected,
                                    toggleGoalAction: toggleGoalSelection
                                )

                                VStack(alignment: .leading, spacing: 14) {
                                    HStack {
                                        Text("Насколько сильно это ощущается?")
                                            .font(.headline.weight(.semibold))
                                        Spacer()
                                        Text("\(Int(intensity))/10")
                                            .font(.headline.monospacedDigit())
                                            .foregroundStyle(selectedMood.tint)
                                    }

                                    Slider(value: $intensity, in: 1...10, step: 1)
                                        .tint(selectedMood.tint)

                                    Text(intensityDescription)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(20)
                                .background(palette.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(palette.stroke, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, composerStep == .moodSelection ? 40 : 108)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Group {
                    switch composerStep {
                    case .moodSelection:
                        EmptyView()

                    case .activitySelection:
                        BottomActionButton(
                            title: "Дальше к заметке",
                            background: activeMood.tint,
                            isEnabled: true
                        ) {
                            goToNoteDetails()
                        }

                    case .noteDetails:
                        BottomActionButton(
                            title: "Сохранить заметку",
                            background: activeMood.tint,
                            isEnabled: true
                        ) {
                            saveEntry()
                        }
                    }
                }
            }
            .navigationTitle("Новая заметка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    switch composerStep {
                    case .moodSelection:
                        Button("Отмена") {
                            dismiss()
                        }

                    case .activitySelection:
                        Button(action: returnToMoodSelection) {
                            Label("Эмоции", systemImage: "chevron.left")
                                .labelStyle(.titleAndIcon)
                        }

                    case .noteDetails:
                        Button(action: returnToActivitySelection) {
                            Label("Занятия", systemImage: "chevron.left")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                }
            }
            .sheet(isPresented: $isPresentingActivityEditor) {
                ActivityEditorView()
            }
            .alert("Не удалось сохранить", isPresented: isShowingSaveError) {
                Button("Ок", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Попробуй еще раз.")
            }
            .onChange(of: composerStep) { _, newStep in
                if newStep == .noteDetails && note.isEmpty {
                    isNoteFocused = true
                } else {
                    isNoteFocused = false
                }
            }
        }
    }

    private var intensityDescription: String {
        switch Int(intensity) {
        case 1...3:
            "Легкое ощущение, которое только начинает проявляться."
        case 4...7:
            "Состояние заметное и уже влияет на настроение дня."
        default:
            "Очень сильная эмоция. Хорошо бы уделить ей немного внимания."
        }
    }

    private func chooseMood(_ mood: Mood) {
        selectedMood = mood

        withAnimation(.snappy(duration: 0.28)) {
            composerStep = .activitySelection
        }
    }

    private func toggleActivitySelection(_ activity: ActivityOption) {
        if selectedActivityKeys.contains(activity.lookupKey) {
            selectedActivityKeys.remove(activity.lookupKey)
        } else {
            selectedActivityKeys.insert(activity.lookupKey)
        }
    }

    private func goToNoteDetails() {
        seedGoalSelectionIfNeeded()

        withAnimation(.snappy(duration: 0.28)) {
            composerStep = .noteDetails
        }
    }

    private func returnToActivitySelection() {
        withAnimation(.snappy(duration: 0.28)) {
            composerStep = .activitySelection
        }
    }

    private func returnToMoodSelection() {
        withAnimation(.snappy(duration: 0.28)) {
            composerStep = .moodSelection
        }
    }

    private func goalID(for goal: DailyGoal) -> ObjectIdentifier {
        ObjectIdentifier(goal)
    }

    private func isGoalSelected(_ goal: DailyGoal) -> Bool {
        completedGoalIDs.contains(goalID(for: goal))
    }

    private func toggleGoalSelection(_ goal: DailyGoal) {
        let identifier = goalID(for: goal)

        if completedGoalIDs.contains(identifier) {
            completedGoalIDs.remove(identifier)
        } else {
            completedGoalIDs.insert(identifier)
        }

        hasSeededGoalSelection = true
    }

    private func seedGoalSelectionIfNeeded() {
        guard !hasSeededGoalSelection else { return }

        completedGoalIDs = Set(
            goals.compactMap { goal in
                goal.isCompletedToday ? goalID(for: goal) : nil
            }
        )
        hasSeededGoalSelection = true
    }

    private func saveEntry() {
        guard let selectedMood else { return }

        let entry = EmotionEntry(
            mood: selectedMood,
            intensity: intensity,
            trigger: "",
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            activitySnapshots: selectedActivities.map {
                EntryActivitySnapshot(
                    title: $0.title,
                    symbolName: $0.symbolName
                )
            }
        )

        let previousGoalStates = Dictionary(
            uniqueKeysWithValues: goals.map { goal in
                (goalID(for: goal), goal.isCompletedToday)
            }
        )

        for goal in goals {
            goal.setCompleted(isGoalSelected(goal))
        }

        modelContext.insert(entry)

        do {
            try modelContext.save()
            cloudAccount.scheduleAutoBackup(using: modelContext, achievementManager: achievementManager)
            onSave(entry.createdAt)
            dismiss()
        } catch {
            modelContext.delete(entry)

            for goal in goals {
                let wasCompleted = previousGoalStates[goalID(for: goal)] ?? false
                goal.setCompleted(wasCompleted)
            }

            saveErrorMessage = "Запись не удалось сохранить в локальную базу данных. \(error.localizedDescription)"
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
}

private struct BottomActionButton: View {
    let title: String
    let background: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .foregroundStyle(.white)
            .background(isEnabled ? background : background.opacity(0.38))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
            .disabled(!isEnabled)
    }
}

private struct MoodSelectionIntroCard: View {
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Как вы себя чувствуете?")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text("Сначала выбери эмоцию, потом отметь занятия за день, а затем спокойно запиши, что произошло.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
        .shadow(color: palette.cardShadow, radius: 18, y: 12)
    }
}

private struct SelectedMoodHeaderCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var moodCustomization: MoodCustomizationManager

    let mood: Mood
    let changeMoodAction: () -> Void

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Вы выбрали")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(moodCustomization.title(for: mood))
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text(moodCustomization.prompt(for: mood))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                MoodVisualView(mood: mood, size: 58)
            }

            Button(action: changeMoodAction) {
                Text("Выбрать другую эмоцию")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(mood.tint)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(mood.tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
        .shadow(color: palette.cardShadow, radius: 18, y: 12)
    }
}

private struct ActivitySelectionCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let activities: [ActivityOption]
    let selectedActivityKeys: Set<String>
    let openEditorAction: () -> Void
    let toggleSelectionAction: (ActivityOption) -> Void

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Чем вы занимались сегодня?")
                        .font(.title3.weight(.bold))

                    Text("Можно выбрать одно или несколько занятий за день.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: openEditorAction) {
                    Text("Редактор занятий")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.accentForeground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [
                                    palette.elevatedSurface,
                                    palette.accentSoft
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(palette.stroke, lineWidth: 1)
                        )
                }
            }

            if activities.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Пока нет занятий в списке.")
                        .font(.headline)

                    Text("Открой редактор занятий, чтобы добавить свои варианты или взять готовые шаблоны.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button("Открыть редактор занятий", action: openEditorAction)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.accentForeground)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(palette.stroke, lineWidth: 1)
                )
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(activities) { activity in
                        ActivityChoiceCard(
                            activity: activity,
                            isSelected: selectedActivityKeys.contains(activity.lookupKey)
                        ) {
                            toggleSelectionAction(activity)
                        }
                    }
                }
            }

            Text(
                selectedActivityKeys.isEmpty
                    ? "Занятия можно пропустить и сразу перейти к заметке."
                    : "Выбрано занятий: \(selectedActivityKeys.count)"
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
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
}

private struct SelectedActivitiesSummaryCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let activities: [ActivityOption]
    let changeActivitiesAction: () -> Void

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Занятия за день")
                    .font(.headline.weight(.semibold))

                Spacer()

                Button("Изменить", action: changeActivitiesAction)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.accentForeground)
            }

            if activities.isEmpty {
                Text("Ты можешь вернуться на шаг назад и выбрать, чем занималась сегодня.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(activities) { activity in
                            EntryComposerActivityPill(
                                title: activity.title,
                                symbolName: activity.symbolName
                            )
                        }
                    }
                    .padding(.trailing, 20)
                }
            }
        }
        .padding(20)
        .background(palette.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
        .shadow(color: palette.cardShadow, radius: 16, y: 10)
    }
}

private struct GoalsCompletionCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let goals: [DailyGoal]
    let isSelected: (DailyGoal) -> Bool
    let toggleGoalAction: (DailyGoal) -> Void

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Какие цели выполнены сегодня?")
                    .font(.headline.weight(.semibold))

                Text("Можно отметить всё, что получилось закрыть за день.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if goals.isEmpty {
                Text("Пока нет добавленных целей. Их можно создать на главном экране в разделе целей.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(palette.stroke, lineWidth: 1)
                    )
            } else {
                VStack(spacing: 10) {
                    ForEach(goals) { goal in
                        Button {
                            toggleGoalAction(goal)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isSelected(goal) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(isSelected(goal) ? activeTint : .secondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(goal.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)

                                    Text(isSelected(goal) ? "Будет отмечено как выполнено сегодня" : "Пока не отмечено")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(isSelected(goal) ? palette.accentSoft : palette.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(isSelected(goal) ? activeTint.opacity(0.45) : palette.stroke, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .background(palette.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
        .shadow(color: palette.cardShadow, radius: 16, y: 10)
    }

    private var activeTint: Color {
        palette.floatingButton
    }
}

private struct EntryComposerActivityPill: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let symbolName: String

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 6) {
            ActivityVisualView(
                symbolName: symbolName,
                size: 12
            )

            Text(title)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(palette.surface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(palette.stroke, lineWidth: 1)
        )
    }
}

private struct ActivityChoiceCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let activity: ActivityOption
    let isSelected: Bool
    let action: () -> Void

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    ActivityVisualView(
                        activity: activity,
                        size: 20,
                        tint: isSelected ? palette.accentForeground : .primary
                    )
                        .frame(width: 44, height: 44)
                        .background(isSelected ? Color.white.opacity(0.24) : palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? palette.accentForeground : .secondary)
                }

                Text(activity.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? palette.accentForeground : .primary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(activeFill) : AnyShapeStyle(palette.surface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? Color.clear : palette.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var activeFill: LinearGradient {
        LinearGradient(
            colors: [
                palette.floatingButton,
                palette.floatingButtonSecondary
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct MoodEmojiCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var moodCustomization: MoodCustomizationManager

    let mood: Mood
    let isSelected: Bool
    let action: () -> Void

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                MoodVisualView(
                    mood: mood,
                    size: 50
                )

                Text(moodCustomization.title(for: mood))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 124)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected ? mood.tint.opacity(0.16) : palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? mood.tint : palette.stroke, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
