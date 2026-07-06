//
//  ActivityEditorView.swift
//  felix228
//
//  Created by Codex on 12.05.2026.
//

import SwiftUI
import SwiftData

struct ActivityEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var cloudAccount: CloudAccountManager
    @EnvironmentObject private var achievementManager: AchievementManager
    @Query(sort: [SortDescriptor(\ActivityOption.createdAt, order: .forward)])
    private var activities: [ActivityOption]

    @State private var isPresentingCustomActivityComposer = false
    @State private var saveErrorMessage: String?

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    private var sortedActivities: [ActivityOption] {
        activities
    }

    private var existingLookupKeys: Set<String> {
        Set(activities.map(\.lookupKey))
    }

    private var remainingTemplates: [ActivityTemplate] {
        ActivityTemplate.defaults.filter { !existingLookupKeys.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView(palette: palette)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        ActivityEditorIntroCard()

                        CustomActivityLauncherCard {
                            isPresentingCustomActivityComposer = true
                        }

                        if !remainingTemplates.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Готовые шаблоны")
                                    .font(.headline.weight(.semibold))

                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: 12),
                                        GridItem(.flexible(), spacing: 12)
                                    ],
                                    spacing: 12
                                ) {
                                    ForEach(remainingTemplates) { template in
                                        ActivityTemplateCard(template: template) {
                                            addTemplate(template)
                                        }
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Ваши занятия")
                                .font(.headline.weight(.semibold))

                            if !sortedActivities.isEmpty {
                                Text("Меняй порядок стрелками. В таком же порядке занятия появятся на шаге «Чем ты занималась сегодня?»")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if sortedActivities.isEmpty {
                                Text("Пока нет занятий. Добавь своё или выбери готовый шаблон ниже.")
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
                                    ForEach(Array(sortedActivities.enumerated()), id: \.element.lookupKey) { index, activity in
                                        SavedActivityRowCard(
                                            activity: activity,
                                            canMoveUp: index > 0,
                                            canMoveDown: index < sortedActivities.count - 1,
                                            moveUpAction: {
                                                moveActivity(activity, direction: .up)
                                            },
                                            moveDownAction: {
                                                moveActivity(activity, direction: .down)
                                            }
                                        ) {
                                            deleteActivity(activity)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Редактор занятий")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .alert("Не удалось сохранить", isPresented: isShowingSaveError) {
                Button("Ок", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Попробуй еще раз.")
            }
            .sheet(isPresented: $isPresentingCustomActivityComposer) {
                CustomActivityComposerView { title, symbolName in
                    try addCustomActivity(title: title, symbolName: symbolName)
                }
            }
        }
    }

    private func addCustomActivity(title: String, symbolName: String) throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw ActivityEditorComposerError.emptyTitle
        }

        let lookupKey = ActivityOption.makeLookupKey(trimmedTitle)
        guard !existingLookupKeys.contains(lookupKey) else {
            throw ActivityEditorComposerError.duplicate
        }

        let activity = ActivityOption(
            title: trimmedTitle,
            symbolName: symbolName
        )

        withAnimation {
            modelContext.insert(activity)
        }

        do {
            try modelContext.save()
            cloudAccount.scheduleAutoBackup(using: modelContext, achievementManager: achievementManager)
        } catch {
            modelContext.delete(activity)
            throw ActivityEditorComposerError.storage(error)
        }
    }

    private func addTemplate(_ template: ActivityTemplate) {
        let activity = ActivityOption(
            title: template.title,
            symbolName: template.symbolName
        )

        withAnimation {
            modelContext.insert(activity)
        }

        do {
            try modelContext.save()
            cloudAccount.scheduleAutoBackup(using: modelContext, achievementManager: achievementManager)
        } catch {
            modelContext.delete(activity)
            saveErrorMessage = "Шаблон занятия не удалось сохранить. \(error.localizedDescription)"
        }
    }

    private func moveActivity(_ activity: ActivityOption, direction: ActivityMoveDirection) {
        let currentActivities = sortedActivities

        guard let currentIndex = currentActivities.firstIndex(where: { $0.lookupKey == activity.lookupKey }) else {
            return
        }

        let targetIndex = direction == .up ? currentIndex - 1 : currentIndex + 1
        guard currentActivities.indices.contains(targetIndex) else { return }

        var reorderedActivities = currentActivities
        reorderedActivities.swapAt(currentIndex, targetIndex)
        persistActivityOrder(reorderedActivities)
    }

    private func persistActivityOrder(_ orderedActivities: [ActivityOption]) {
        let originalDates = Dictionary(
            uniqueKeysWithValues: orderedActivities.map { (ObjectIdentifier($0), $0.createdAt) }
        )

        for (index, activity) in orderedActivities.enumerated() {
            activity.createdAt = Date(timeIntervalSinceReferenceDate: Double(index) * 60)
        }

        do {
            try modelContext.save()
            cloudAccount.scheduleAutoBackup(using: modelContext, achievementManager: achievementManager)
        } catch {
            for activity in orderedActivities {
                if let originalDate = originalDates[ObjectIdentifier(activity)] {
                    activity.createdAt = originalDate
                }
            }

            saveErrorMessage = "Новый порядок занятий не удалось сохранить. \(error.localizedDescription)"
        }
    }

    private func deleteActivity(_ activity: ActivityOption) {
        withAnimation {
            modelContext.delete(activity)
        }

        do {
            try modelContext.save()
            cloudAccount.scheduleAutoBackup(using: modelContext, achievementManager: achievementManager)
        } catch {
            saveErrorMessage = "Занятие не удалось удалить из локальной базы данных. \(error.localizedDescription)"
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

private enum ActivityMoveDirection {
    case up
    case down
}

private enum ActivityEditorComposerError: LocalizedError {
    case emptyTitle
    case duplicate
    case storage(Error)

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Сначала напиши название занятия."
        case .duplicate:
            return "Такое занятие уже есть в списке."
        case .storage(let error):
            return "Занятие не удалось сохранить в локальную базу данных. \(error.localizedDescription)"
        }
    }
}

private struct ActivityEditorIntroCard: View {
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Собери свой список занятий")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Сначала нажми на добавление, потом выбери иконку, название и заверши всё кнопкой «Готово». Так список занятий будет аккуратно собираться под твой день.")
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

private struct CustomActivityLauncherCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let action: () -> Void

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: "plus")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.floatingButtonForeground)
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        palette.floatingButton,
                                        palette.floatingButtonSecondary
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Добавить своё занятие")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Откроется отдельный экран, где можно пролистать иконки, выбрать название и нажать «Готово».")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .background(palette.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(palette.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .shadow(color: palette.cardShadow, radius: 18, y: 12)
    }
}

private struct CustomActivityComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let saveAction: (String, String) throws -> Void

    @State private var draftTitle = ""
    @State private var selectedSymbolName = ActivityTemplate.defaultCustomSymbol
    @State private var errorMessage: String?
    @FocusState private var isTitleFocused: Bool

    private let iconColumns = [
        GridItem(.adaptive(minimum: 64, maximum: 84), spacing: 12)
    ]

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    private var trimmedTitle: String {
        draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView(palette: palette)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 16) {
                                ActivityVisualView(
                                    symbolName: selectedSymbolName,
                                    size: 30,
                                    tint: palette.floatingButtonForeground
                                )
                                .frame(width: 74, height: 74)
                                .background(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    palette.floatingButton,
                                                    palette.floatingButtonSecondary
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Новое занятие")
                                        .font(.title2.weight(.bold))

                                    Text("Сначала выбери иконку, потом введи название, и занятие сразу появится в дневнике.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
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

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Иконка занятия")
                                .font(.headline.weight(.semibold))

                            LazyVGrid(columns: iconColumns, spacing: 12) {
                                ForEach(ActivityTemplate.customIconChoices) { choice in
                                    ActivityIconChoiceButton(
                                        choice: choice,
                                        isSelected: selectedSymbolName == choice.symbolName
                                    ) {
                                        selectedSymbolName = choice.symbolName
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Название")
                                .font(.headline.weight(.semibold))

                            TextField("Например: рисование, покупки, мысли", text: $draftTitle)
                                .textFieldStyle(.plain)
                                .submitLabel(.done)
                                .focused($isTitleFocused)
                                .onSubmit(save)
                                .padding(16)
                                .background(palette.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(palette.stroke, lineWidth: 1)
                                )

                            Text("После `Готово` занятие сразу появится в списке и будет доступно на шаге `Чем ты занималась сегодня?`.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 140)
                }
            }
            .navigationTitle("Новое занятие")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                        .overlay(palette.stroke)

                    Button(action: save) {
                        Text("Готово")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(trimmedTitle.isEmpty ? .secondary : palette.floatingButtonForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(trimmedTitle.isEmpty ? palette.stroke : palette.floatingButton)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(trimmedTitle.isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial)
            }
            .task {
                isTitleFocused = true
            }
            .alert("Не удалось сохранить занятие", isPresented: isShowingError) {
                Button("Ок", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Попробуй ещё раз.")
            }
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { shouldShow in
                if !shouldShow {
                    errorMessage = nil
                }
            }
        )
    }

    private func save() {
        do {
            try saveAction(draftTitle, selectedSymbolName)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ActivityIconChoiceButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let choice: ActivityIconChoice
    let isSelected: Bool
    let action: () -> Void

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        Button(action: action) {
            ActivityVisualView(
                symbolName: choice.symbolName,
                size: 24,
                tint: isSelected ? palette.floatingButtonForeground : .primary
            )
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        palette.floatingButton,
                                        palette.floatingButtonSecondary
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(palette.surface)
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? palette.stroke : palette.stroke.opacity(0.65), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.title)
    }
}

private struct ActivityTemplateCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let template: ActivityTemplate
    let addAction: () -> Void

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        Button(action: addAction) {
            VStack(alignment: .leading, spacing: 14) {
                ActivityVisualView(
                    template: template,
                    size: 20
                )
                    .frame(width: 42, height: 42)
                    .background(palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(template.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text("Добавить")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 144, alignment: .leading)
            .padding(16)
            .background(palette.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .shadow(color: palette.cardShadow, radius: 12, y: 8)
    }
}

private struct SavedActivityRowCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let activity: ActivityOption
    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUpAction: () -> Void
    let moveDownAction: () -> Void
    let deleteAction: () -> Void

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 14) {
            ActivityVisualView(
                activity: activity,
                size: 20
            )
                .frame(width: 48, height: 48)
                .background(palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(activity.title)
                .font(.headline)

            Spacer()

            HStack(spacing: 8) {
                Button(action: moveUpAction) {
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(canMoveUp ? Color.primary : Color.secondary.opacity(0.55))
                        .frame(width: 34, height: 34)
                        .background(palette.elevatedSurface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canMoveUp)

                Button(action: moveDownAction) {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(canMoveDown ? Color.primary : Color.secondary.opacity(0.55))
                        .frame(width: 34, height: 34)
                        .background(palette.elevatedSurface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canMoveDown)
            }

            Menu {
                Button(role: .destructive, action: deleteAction) {
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
