//
//  MoodEditorView.swift
//  felix228
//
//  Created by Codex on 14.05.2026.
//

import SwiftUI

struct MoodEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var moodCustomization: MoodCustomizationManager
    @EnvironmentObject private var premiumAccess: PremiumAccessManager

    @State private var draftTheme: MoodEmojiTheme = .classic
    @State private var draftTitles: [Mood: String] = [:]
    @State private var hasLoadedDraft = false
    @State private var isPresentingSubscription = false

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    private let themeColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView(palette: palette)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        StatisticsSectionCard(
                            palette: palette,
                            title: localization.pick("Тема смайлов", "Sticker theme"),
                            subtitle: localization.pick(
                                "Можно оставить текущую тему или переключиться на Kitty Slime или Kitty Moji.",
                                "You can keep the current theme or switch to Kitty Slime or Kitty Moji."
                            )
                        ) {
                            LazyVGrid(columns: themeColumns, spacing: 12) {
                                ForEach(MoodEmojiTheme.allCases) { theme in
                                    MoodThemeChoiceCard(
                                        theme: theme,
                                        selectedTheme: draftTheme,
                                        hasPremiumAccess: premiumAccess.hasPremiumAccess,
                                        palette: palette,
                                        previewTitles: previewTitles,
                                        action: {
                                            if theme.requiresPremium && !premiumAccess.hasPremiumAccess {
                                                isPresentingSubscription = true
                                            } else {
                                                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                                    draftTheme = theme
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                        }

                        StatisticsSectionCard(
                            palette: palette,
                            title: localization.pick("Названия настроений", "Mood names"),
                            subtitle: localization.pick(
                                "Здесь можно переименовать каждое настроение так, как удобно именно тебе.",
                                "Here you can rename each mood in the way that feels right for you."
                            )
                        ) {
                            VStack(spacing: 12) {
                                ForEach(Mood.allCases) { mood in
                                    MoodRenameRow(
                                        mood: mood,
                                        theme: draftTheme,
                                        title: binding(for: mood),
                                        defaultTitle: moodCustomization.defaultTitle(for: mood)
                                    )
                                }

                                Button {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                        resetDraftTitles()
                                    }
                                } label: {
                                    Text(localization.pick("Вернуть стандартные названия", "Restore default names"))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(palette.accent)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(palette.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(palette.stroke, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(localization.pick("Редактор настроения", "Mood editor"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localization.pick("Закрыть", "Close")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(localization.pick("Готово", "Done")) {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadDraftIfNeeded()
        }
        .sheet(isPresented: $isPresentingSubscription) {
            PremiumSubscriptionView()
        }
    }

    private var previewTitles: [Mood: String] {
        var titles: [Mood: String] = [:]
        for mood in Mood.allCases {
            let trimmedTitle = draftTitles[mood, default: moodCustomization.titleOverride(for: mood)]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            titles[mood] = trimmedTitle.isEmpty ? moodCustomization.defaultTitle(for: mood) : trimmedTitle
        }
        return titles
    }

    private func binding(for mood: Mood) -> Binding<String> {
        Binding(
            get: { draftTitles[mood, default: moodCustomization.titleOverride(for: mood)] },
            set: { draftTitles[mood] = $0 }
        )
    }

    private func loadDraftIfNeeded() {
        guard !hasLoadedDraft else { return }

        draftTheme = moodCustomization.effectiveTheme(hasPremiumAccess: premiumAccess.hasPremiumAccess)
        draftTitles = Mood.allCases.reduce(into: [:]) { result, mood in
            result[mood] = moodCustomization.titleOverride(for: mood)
        }
        hasLoadedDraft = true
    }

    private func resetDraftTitles() {
        for mood in Mood.allCases {
            draftTitles[mood] = moodCustomization.defaultTitle(for: mood)
        }
    }

    private func saveAndDismiss() {
        if draftTheme.requiresPremium && !premiumAccess.hasPremiumAccess {
            draftTheme = .classic
        }
        moodCustomization.apply(theme: draftTheme, titlesByMood: draftTitles)
        dismiss()
    }
}

private struct MoodThemeChoiceCard: View {
    @EnvironmentObject private var localization: LocalizationManager

    let theme: MoodEmojiTheme
    let selectedTheme: MoodEmojiTheme
    let hasPremiumAccess: Bool
    let palette: ThemePalette
    let previewTitles: [Mood: String]
    let action: () -> Void

    private var isSelected: Bool {
        theme == selectedTheme
    }

    private var isLocked: Bool {
        theme.requiresPremium && !hasPremiumAccess
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    MoodVisualView(mood: .normal, size: 42, themeOverride: theme)
                        .frame(width: 58, height: 58)
                        .background(isSelected ? Color.white.opacity(0.2) : palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Spacer()

                    Image(systemName: isLocked ? "lock.fill" : (isSelected ? "checkmark.circle.fill" : "circle"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? palette.floatingButtonForeground : .secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.localizedTitle(for: localization.selectedLanguage))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(isSelected ? palette.floatingButtonForeground : .primary)

                    Text(theme.localizedSubtitle(for: localization.selectedLanguage))
                        .font(.caption)
                        .foregroundStyle(isSelected ? palette.floatingButtonForeground.opacity(0.82) : .secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    Text(previewTitles[.normal] ?? Mood.normal.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? palette.floatingButtonForeground.opacity(0.9) : palette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(isSelected ? Color.white.opacity(0.16) : palette.accentSoft)
                        .clipShape(Capsule())

                    if isLocked {
                        Text("Premium")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(isSelected ? palette.floatingButtonForeground : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color.white.opacity(0.14) : palette.surface)
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 198, alignment: .topLeading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(activeFill) : AnyShapeStyle(palette.elevatedSurface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(isSelected ? Color.clear : palette.stroke, lineWidth: 1)
            )
            .shadow(color: palette.cardShadow, radius: 16, y: 10)
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

private struct MoodRenameRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let mood: Mood
    let theme: MoodEmojiTheme
    @Binding var title: String
    let defaultTitle: String

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                MoodVisualView(mood: mood, size: 46, themeOverride: theme)
                    .frame(width: 58, height: 58)
                    .background(palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(defaultTitle)
                        .font(.headline.weight(.semibold))

                    Text("По умолчанию в приложении")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            TextField("Название настроения", text: $title)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(true)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.stroke, lineWidth: 1)
                )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
    }
}
