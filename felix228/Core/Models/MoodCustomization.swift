//
//  MoodCustomization.swift
//  felix228
//
//  Created by Codex on 14.05.2026.
//

import Combine
import Foundation
import SwiftUI

enum MoodEmojiTheme: String, CaseIterable, Identifiable {
    case classic
    case kittySlime
    case kittyMoji

    var id: String { rawValue }

    init(storageValue: String) {
        self = MoodEmojiTheme(rawValue: storageValue) ?? .classic
    }

    var title: String {
        localizedTitle(for: .russian)
    }

    func localizedTitle(for language: AppLanguage) -> String {
        switch self {
        case .classic:
            return language.localized("Обычная", "Звичайна", "Classic")
        case .kittySlime:
            return "Kitty Slime"
        case .kittyMoji:
            return "Kitty Moji"
        }
    }

    var requiresPremium: Bool {
        switch self {
        case .classic:
            false
        case .kittySlime, .kittyMoji:
            true
        }
    }

    var subtitle: String {
        localizedSubtitle(for: .russian)
    }

    func localizedSubtitle(for language: AppLanguage) -> String {
        switch self {
        case .classic:
            return language.localized(
                "Текущие котики, которые уже есть в приложении.",
                "Поточні котики, які вже є у застосунку.",
                "The current kitten stickers already available in the app."
            )
        case .kittySlime:
            return language.localized(
                "Новая серия стикеров в стиле kitty slime.",
                "Нова серія стікерів у стилі kitty slime.",
                "A new sticker pack in the kitty slime style."
            )
        case .kittyMoji:
            return language.localized(
                "Новый набор маленьких kitty moji с яркими эмоциями.",
                "Новий набір маленьких kitty moji з яскравими емоціями.",
                "A bright little kitty moji pack with vivid emotions."
            )
        }
    }
}

@MainActor
final class MoodCustomizationManager: ObservableObject {
    @Published private(set) var selectedTheme: MoodEmojiTheme
    @Published private(set) var customTitles: [String: String]

    private let defaults: UserDefaults

    private static let selectedThemeKey = "selectedMoodEmojiTheme"
    private static let customTitlesKey = "customMoodTitles"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selectedTheme = MoodEmojiTheme(
            storageValue: defaults.string(forKey: Self.selectedThemeKey) ?? MoodEmojiTheme.classic.rawValue
        )

        if let data = defaults.data(forKey: Self.customTitlesKey),
           let storedTitles = try? JSONDecoder().decode([String: String].self, from: data) {
            customTitles = storedTitles
        } else {
            customTitles = [:]
        }
    }

    func title(for mood: Mood) -> String {
        customTitles[mood.rawValue] ?? mood.localizedTitle(for: currentLanguage)
    }

    func lowercaseTitle(for mood: Mood) -> String {
        title(for: mood).lowercased()
    }

    func prompt(for mood: Mood) -> String {
        mood.localizedPrompt(for: currentLanguage)
    }

    func titleOverride(for mood: Mood) -> String {
        title(for: mood)
    }

    func defaultTitle(for mood: Mood) -> String {
        mood.localizedTitle(for: currentLanguage)
    }

    func effectiveTheme(hasPremiumAccess: Bool) -> MoodEmojiTheme {
        guard selectedTheme.requiresPremium, !hasPremiumAccess else {
            return selectedTheme
        }

        return .classic
    }

    func artworkAssetName(
        for mood: Mood,
        theme: MoodEmojiTheme? = nil,
        hasPremiumAccess: Bool = true,
        allowsLockedThemePreview: Bool = false
    ) -> String? {
        let requestedTheme = theme ?? selectedTheme
        let resolvedTheme = (requestedTheme.requiresPremium && !hasPremiumAccess && !allowsLockedThemePreview)
            ? MoodEmojiTheme.classic
            : requestedTheme

        switch resolvedTheme {
        case .classic:
            return mood.artworkAssetName
        case .kittySlime:
            switch mood {
            case .tired:
                return "KittySlimeTiredMood"
            case .normal:
                return "KittySlimeNormalMood"
            case .soSo:
                return "KittySlimeSoSoMood"
            case .bad:
                return "KittySlimeBadMood"
            case .superb:
                return "KittySlimeSuperMood"
            }
        case .kittyMoji:
            switch mood {
            case .tired:
                return "KittyMojiTiredMood"
            case .normal:
                return "KittyMojiNormalMood"
            case .soSo:
                return "KittyMojiSoSoMood"
            case .bad:
                return "KittyMojiBadMood"
            case .superb:
                return "KittyMojiSuperMood"
            }
        }
    }

    func apply(theme: MoodEmojiTheme, titlesByMood: [Mood: String]) {
        selectedTheme = theme
        defaults.set(theme.rawValue, forKey: Self.selectedThemeKey)

        let normalizedTitles = normalizedTitlesDictionary(from: titlesByMood)
        customTitles = normalizedTitles
        persistTitles(normalizedTitles)
    }

    func resetTitles() {
        customTitles = [:]
        defaults.removeObject(forKey: Self.customTitlesKey)
    }

    private func normalizedTitlesDictionary(from titlesByMood: [Mood: String]) -> [String: String] {
        var normalizedTitles: [String: String] = [:]

        for mood in Mood.allCases {
            let trimmedTitle = titlesByMood[mood, default: mood.title]
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedTitle.isEmpty else { continue }
            guard trimmedTitle != mood.localizedTitle(for: currentLanguage) else { continue }

            normalizedTitles[mood.rawValue] = trimmedTitle
        }

        return normalizedTitles
    }

    private func persistTitles(_ titles: [String: String]) {
        if titles.isEmpty {
            defaults.removeObject(forKey: Self.customTitlesKey)
            return
        }

        guard let data = try? JSONEncoder().encode(titles) else { return }
        defaults.set(data, forKey: Self.customTitlesKey)
    }

    private var currentLanguage: AppLanguage {
        AppLanguage.current(defaults: defaults)
    }
}
