//
//  Mood.swift
//  felix228
//
//  Created by Codex on 12.05.2026.
//

import SwiftUI

enum Mood: String, CaseIterable, Identifiable {
    case tired = "tired"
    case normal = "normal"
    case soSo = "so_so"
    case bad = "bad"
    case superb = "super"

    static let allCases: [Mood] = [
        .tired,
        .normal,
        .soSo,
        .bad,
        .superb
    ]

    var id: String { rawValue }

    init(storageValue: String) {
        switch storageValue {
        case Mood.tired.rawValue:
            self = .tired
        case Mood.normal.rawValue, "calm":
            self = .normal
        case Mood.soSo.rawValue, "anxious":
            self = .soSo
        case Mood.bad.rawValue, "sad", "angry":
            self = .bad
        case Mood.superb.rawValue, "joyful", "grateful":
            self = .superb
        default:
            self = .normal
        }
    }

    var title: String {
        localizedTitle(for: .russian)
    }

    func localizedTitle(for language: AppLanguage) -> String {
        switch self {
        case .tired:
            return language.localized("Усталость", "Втома", "Tired")
        case .normal:
            return language.localized("Нормально", "Нормально", "Okay")
        case .soSo:
            return language.localized("Так себе", "Так собі", "So-so")
        case .bad:
            return language.localized("Плохо", "Погано", "Bad")
        case .superb:
            return language.localized("Супер", "Супер", "Super")
        }
    }

    var prompt: String {
        localizedPrompt(for: .russian)
    }

    func localizedPrompt(for language: AppLanguage) -> String {
        switch self {
        case .tired:
            return language.localized(
                "Можно честно отметить, что сил на сегодня почти не осталось.",
                "Можна чесно відзначити, що сил на сьогодні майже не залишилося.",
                "You can honestly note that you have almost no energy left today."
            )
        case .normal:
            return language.localized(
                "Спокойный обычный день тоже важно замечать.",
                "Спокійний звичайний день теж варто помічати.",
                "A calm ordinary day is also worth noticing."
            )
        case .soSo:
            return language.localized(
                "Можно коротко записать, что сделало день неровным.",
                "Можна коротко записати, що зробило день нестабільним.",
                "You can briefly write down what made the day feel uneven."
            )
        case .bad:
            return language.localized(
                "Если день тяжёлый, запись поможет бережно это зафиксировать.",
                "Якщо день важкий, запис допоможе дбайливо це зафіксувати.",
                "If the day feels hard, a note can help you record it gently."
            )
        case .superb:
            return language.localized(
                "Пусть этот классный момент останется в дневнике.",
                "Нехай цей класний момент залишиться у щоденнику.",
                "Let this great moment stay in your journal."
            )
        }
    }

    var emoji: String {
        switch self {
        case .tired:
            "😴"
        case .normal:
            "🙂"
        case .soSo:
            "😐"
        case .bad:
            "😞"
        case .superb:
            "🤩"
        }
    }

    var artworkAssetName: String? {
        switch self {
        case .tired:
            "TiredMoodKitten"
        case .normal:
            "NormalMoodKitten"
        case .soSo:
            "SoSoMoodKitten"
        case .bad:
            "BadMoodKitten"
        case .superb:
            "SuperMoodKitten"
        }
    }

    var symbolName: String {
        switch self {
        case .tired:
            "moon.zzz.fill"
        case .normal:
            "face.smiling"
        case .soSo:
            "ellipsis.bubble.fill"
        case .bad:
            "cloud.rain.fill"
        case .superb:
            "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .tired:
            Color(red: 0.90, green: 0.29, blue: 0.35)
        case .normal:
            Color(red: 0.93, green: 0.64, blue: 0.21)
        case .soSo:
            Color(red: 0.98, green: 0.47, blue: 0.23)
        case .bad:
            Color(red: 0.34, green: 0.57, blue: 0.77)
        case .superb:
            Color(red: 0.24, green: 0.74, blue: 0.42)
        }
    }
}

struct MoodVisualView: View {
    @EnvironmentObject private var moodCustomization: MoodCustomizationManager
    @EnvironmentObject private var premiumAccess: PremiumAccessManager

    let mood: Mood
    let size: CGFloat
    var themeOverride: MoodEmojiTheme? = nil

    var body: some View {
        Group {
            if let artworkAssetName = moodCustomization.artworkAssetName(
                for: mood,
                theme: themeOverride,
                hasPremiumAccess: premiumAccess.hasPremiumAccess,
                allowsLockedThemePreview: themeOverride != nil
            ) {
                Image(artworkAssetName)
                    .resizable()
                    .scaledToFit()
            } else {
                Text(mood.emoji)
                    .font(.system(size: size))
            }
        }
        .frame(width: size, height: size)
    }
}
