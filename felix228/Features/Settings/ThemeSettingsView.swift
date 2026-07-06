//
//  ThemeSettingsView.swift
//  felix228
//
//  Created by Codex on 19.05.2026.
//

import SwiftUI

struct ThemeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var premiumAccess: PremiumAccessManager
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isPresentingSubscription = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    private var palette: ThemePalette {
        themeManager.palette(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView(palette: palette)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        StatisticsSectionCard(
                            palette: palette,
                            title: localization.pick("Тема оформления", "Appearance theme"),
                            subtitle: localization.pick(
                                "Выбери стиль приложения. Изменения сохраняются сразу и применяются ко всем экранам.",
                                "Choose how the app looks. Changes are saved instantly and applied across the whole app."
                            )
                        ) {
                            EmptyView()
                        }

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(AppTheme.allCases) { theme in
                                ThemeOptionCard(
                                    theme: theme,
                                    isSelected: themeManager.currentTheme == theme,
                                    isLocked: theme.requiresPremium && !premiumAccess.hasPremiumAccess,
                                    language: localization.selectedLanguage,
                                    action: {
                                        if theme.requiresPremium && !premiumAccess.hasPremiumAccess {
                                            isPresentingSubscription = true
                                        } else {
                                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                                themeManager.setTheme(theme, hasPremiumAccess: premiumAccess.hasPremiumAccess)
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(localization.pick("Тема", "Theme"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localization.pick("Закрыть", "Close")) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingSubscription) {
            PremiumSubscriptionView()
        }
    }
}

private struct ThemeOptionCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let theme: AppTheme
    let isSelected: Bool
    let isLocked: Bool
    let language: AppLanguage
    let action: () -> Void

    private var previewPalette: ThemePalette {
        ThemePalette(theme: theme, systemColorScheme: colorScheme)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(theme.localizedTitle(for: language))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(previewPalette.primaryText)

                        Text(theme.localizedSubtitle(for: language))
                            .font(.caption)
                            .foregroundStyle(previewPalette.secondaryText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: isLocked ? "lock.fill" : (isSelected ? "checkmark.circle.fill" : "circle"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? previewPalette.accent : previewPalette.secondaryText.opacity(0.6))
                }

                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(previewPalette.background)
                        .frame(height: 42)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(previewPalette.stroke, lineWidth: 1)
                        )

                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(previewPalette.cardBackground)
                        .frame(height: 42)
                        .overlay(
                            Circle()
                                .fill(previewPalette.accent)
                                .frame(width: 12, height: 12)
                        )
                }

                HStack(spacing: 8) {
                    Capsule()
                        .fill(previewPalette.buttonBackground)
                        .frame(width: 52, height: 12)

                    Capsule()
                        .fill(previewPalette.accentSoft)
                        .frame(width: 32, height: 12)

                    Spacer(minLength: 0)

                    if isLocked {
                        Text("Premium")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(previewPalette.primaryText.opacity(0.84))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(previewPalette.cardBackground.opacity(0.95))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 162, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(previewPalette.elevatedSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? previewPalette.accent.opacity(0.55) : previewPalette.stroke, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: previewPalette.cardShadow, radius: isSelected ? 18 : 10, y: isSelected ? 10 : 6)
        }
        .buttonStyle(.plain)
    }
}
