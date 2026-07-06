//
//  LanguageSettingsView.swift
//  felix228
//
//  Created by Codex on 19.05.2026.
//

import SwiftUI

struct LanguageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var localization: LocalizationManager

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView(palette: palette)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        StatisticsSectionCard(
                            palette: palette,
                            title: localization.pick("Язык приложения", "App language"),
                            subtitle: localization.pick(
                                "Выбери язык интерфейса. Изменения применятся сразу на основных экранах.",
                                "Choose the interface language. Changes will apply immediately on the main screens."
                            )
                        ) {
                            VStack(spacing: 14) {
                                Button {
                                    localization.followSystemLanguage()
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    localization.isUsingSystemLanguage
                                                        ? palette.accent.opacity(0.22)
                                                        : Color.white.opacity(0.06)
                                                )
                                                .frame(width: 52, height: 52)

                                            Image(systemName: "iphone")
                                                .font(.headline.weight(.bold))
                                                .foregroundStyle(
                                                    localization.isUsingSystemLanguage
                                                        ? palette.accent
                                                        : .secondary
                                                )
                                        }

                                            VStack(alignment: .leading, spacing: 4) {
                                            Text(localization.pick("Как на iPhone", "Як на iPhone", "Same as iPhone"))
                                                .font(.headline.weight(.semibold))
                                                .foregroundStyle(.primary)

                                            Text(
                                                localization.pick(
                                                    "Приложение будет следовать языку телефона: сейчас \(localization.selectedLanguage.title).",
                                                    "Застосунок буде слідувати мові телефона: зараз \(localization.selectedLanguage.title).",
                                                    "The app will follow your iPhone language: currently \(localization.selectedLanguage.title)."
                                                )
                                            )
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: localization.isUsingSystemLanguage ? "checkmark.circle.fill" : "circle")
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(
                                                localization.isUsingSystemLanguage
                                                    ? palette.accent
                                                    : .secondary
                                            )
                                    }
                                    .padding(18)
                                    .background(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .fill(Color.white.opacity(0.05))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .stroke(
                                                localization.isUsingSystemLanguage
                                                    ? palette.accent.opacity(0.45)
                                                    : palette.stroke,
                                                lineWidth: 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)

                                ForEach(AppLanguage.allCases) { language in
                                    Button {
                                        localization.setLanguage(language)
                                    } label: {
                                        HStack(spacing: 14) {
                                            ZStack {
                                                Circle()
                                                    .fill(
                                                        language == localization.selectedLanguage && !localization.isUsingSystemLanguage
                                                            ? palette.accent.opacity(0.22)
                                                            : Color.white.opacity(0.06)
                                                    )
                                                    .frame(width: 52, height: 52)

                                                Image(systemName: iconName(for: language))
                                                    .font(.headline.weight(.bold))
                                                    .foregroundStyle(
                                                        language == localization.selectedLanguage && !localization.isUsingSystemLanguage
                                                            ? palette.accent
                                                            : .secondary
                                                    )
                                            }

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(language.title)
                                                    .font(.headline.weight(.semibold))
                                                    .foregroundStyle(.primary)

                                                Text(subtitle(for: language))
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            Image(systemName: language == localization.selectedLanguage && !localization.isUsingSystemLanguage ? "checkmark.circle.fill" : "circle")
                                                .font(.title3.weight(.semibold))
                                                .foregroundStyle(
                                                    language == localization.selectedLanguage && !localization.isUsingSystemLanguage
                                                        ? palette.accent
                                                        : .secondary
                                                )
                                        }
                                        .padding(18)
                                        .background(
                                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                .fill(Color.white.opacity(0.05))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                .stroke(
                                                    language == localization.selectedLanguage && !localization.isUsingSystemLanguage
                                                        ? palette.accent.opacity(0.45)
                                                        : palette.stroke,
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle(localization.pick("Язык", "Language"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localization.pick("Готово", "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func iconName(for language: AppLanguage) -> String {
        switch language {
        case .russian:
            return "text.book.closed.fill"
        case .ukrainian:
            return "character.book.closed.fill"
        case .english:
            return "globe"
        }
    }

    private func subtitle(for language: AppLanguage) -> String {
        switch language {
        case .russian:
            return "Русский интерфейс"
        case .ukrainian:
            return "Український інтерфейс"
        case .english:
            return "English interface"
        }
    }
}
