//
//  AppTheme.swift
//  felix228
//
//  Created by Codex on 12.05.2026.
//

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case green
    case pink
    case orange
    case purple

    static let storageKey = "selectedAppTheme"
    private static let premiumAccessCacheKey = "felix228.premium.cachedAccess"

    var id: String { rawValue }

    init(storageValue: String) {
        self = AppTheme(rawValue: storageValue) ?? .system
    }

    static func current(defaults: UserDefaults = .standard) -> AppTheme {
        let requestedTheme = AppTheme(storageValue: defaults.string(forKey: storageKey) ?? AppTheme.system.rawValue)
        let hasPremiumAccess = defaults.bool(forKey: premiumAccessCacheKey)
        return requestedTheme.resolvedTheme(hasPremiumAccess: hasPremiumAccess)
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .dark:
            .dark
        case .light, .green, .pink, .orange, .purple:
            .light
        }
    }

    var requiresPremium: Bool {
        switch self {
        case .pink, .orange, .purple:
            true
        case .system, .light, .dark, .green:
            false
        }
    }

    func resolvedTheme(hasPremiumAccess: Bool) -> AppTheme {
        guard requiresPremium, !hasPremiumAccess else { return self }
        return .light
    }

    func localizedTitle(for language: AppLanguage) -> String {
        switch self {
        case .system:
            language.localized("Как на iPhone", "Як на iPhone", "System")
        case .light:
            language.localized("Светлая", "Світла", "Light")
        case .dark:
            language.localized("Тёмная", "Темна", "Dark")
        case .green:
            language.localized("Зелёная", "Зелена", "Green")
        case .pink:
            "Pink"
        case .orange:
            "Orange"
        case .purple:
            "Purple"
        }
    }

    func localizedSubtitle(for language: AppLanguage) -> String {
        switch self {
        case .system:
            language.localized("Повторяет внешний вид iPhone", "Повторює вигляд iPhone", "Matches your iPhone appearance")
        case .light:
            language.localized("Чистая светлая палитра", "Чиста світла палітра", "Clean light palette")
        case .dark:
            language.localized("Глубокий тёмный режим", "Глибокий темний режим", "Deep dark appearance")
        case .green:
            language.localized("Свежая зелёная палитра", "Свіжа зелена палітра", "Fresh green palette")
        case .pink:
            language.localized("Мягкие розовые оттенки", "М'які рожеві відтінки", "Soft rosy tones")
        case .orange:
            language.localized("Тёплая оранжевая палитра", "Тепла помаранчева палітра", "Warm orange palette")
        case .purple:
            language.localized("Лавандово-фиолетовый стиль", "Лавандово-фіолетовий стиль", "Lavender purple style")
        }
    }

    var previewAccent: Color {
        switch self {
        case .system:
            Color(red: 120 / 255, green: 120 / 255, blue: 128 / 255)
        case .light:
            Color(red: 113 / 255, green: 101 / 255, blue: 140 / 255)
        case .dark:
            Color(red: 167 / 255, green: 150 / 255, blue: 203 / 255)
        case .green:
            Color(red: 113 / 255, green: 176 / 255, blue: 120 / 255)
        case .pink:
            Color(red: 225 / 255, green: 126 / 255, blue: 181 / 255)
        case .orange:
            Color(red: 242 / 255, green: 146 / 255, blue: 74 / 255)
        case .purple:
            Color(red: 173 / 255, green: 120 / 255, blue: 212 / 255)
        }
    }

    var previewBackground: Color {
        switch self {
        case .system:
            Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255)
        case .light:
            Color(red: 250 / 255, green: 250 / 255, blue: 252 / 255)
        case .dark:
            Color(red: 23 / 255, green: 23 / 255, blue: 28 / 255)
        case .green:
            Color(red: 244 / 255, green: 251 / 255, blue: 244 / 255)
        case .pink:
            Color(red: 255 / 255, green: 243 / 255, blue: 248 / 255)
        case .orange:
            Color(red: 255 / 255, green: 246 / 255, blue: 238 / 255)
        case .purple:
            Color(red: 248 / 255, green: 243 / 255, blue: 255 / 255)
        }
    }
}

struct ThemePalette {
    private static var cachedTheme: AppTheme = AppTheme.current()

    let background: Color
    let backgroundSecondary: Color
    let cardBackground: Color
    let primaryText: Color
    let secondaryText: Color
    let accent: Color
    let buttonBackground: Color
    let buttonText: Color
    let surface: Color
    let elevatedSurface: Color
    let stroke: Color
    let accentSoft: Color
    let accentForeground: Color
    let floatingButton: Color
    let floatingButtonSecondary: Color
    let floatingButtonForeground: Color
    let shadow: Color
    let cardShadow: Color
    let weekActiveBackground: Color
    let weekActiveForeground: Color
    let digestStart: Color
    let digestEnd: Color
    let ambientGlowPrimary: Color
    let ambientGlowSecondary: Color

    init(
        background: Color,
        backgroundSecondary: Color,
        cardBackground: Color,
        primaryText: Color,
        secondaryText: Color,
        accent: Color,
        buttonBackground: Color,
        buttonText: Color,
        surface: Color,
        elevatedSurface: Color,
        stroke: Color,
        accentSoft: Color,
        accentForeground: Color,
        floatingButton: Color,
        floatingButtonSecondary: Color,
        floatingButtonForeground: Color,
        shadow: Color,
        cardShadow: Color,
        weekActiveBackground: Color,
        weekActiveForeground: Color,
        digestStart: Color,
        digestEnd: Color,
        ambientGlowPrimary: Color,
        ambientGlowSecondary: Color
    ) {
        self.background = background
        self.backgroundSecondary = backgroundSecondary
        self.cardBackground = cardBackground
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.accent = accent
        self.buttonBackground = buttonBackground
        self.buttonText = buttonText
        self.surface = surface
        self.elevatedSurface = elevatedSurface
        self.stroke = stroke
        self.accentSoft = accentSoft
        self.accentForeground = accentForeground
        self.floatingButton = floatingButton
        self.floatingButtonSecondary = floatingButtonSecondary
        self.floatingButtonForeground = floatingButtonForeground
        self.shadow = shadow
        self.cardShadow = cardShadow
        self.weekActiveBackground = weekActiveBackground
        self.weekActiveForeground = weekActiveForeground
        self.digestStart = digestStart
        self.digestEnd = digestEnd
        self.ambientGlowPrimary = ambientGlowPrimary
        self.ambientGlowSecondary = ambientGlowSecondary
    }

    init(theme: AppTheme, systemColorScheme: ColorScheme) {
        let resolvedColorScheme = theme.preferredColorScheme ?? systemColorScheme

        switch theme {
        case .system:
            self = ThemePalette.systemPalette(colorScheme: resolvedColorScheme)
        case .light:
            self = ThemePalette.lightPalette
        case .dark:
            self = ThemePalette.darkPalette
        case .green:
            self = ThemePalette.greenPalette
        case .pink:
            self = ThemePalette.pinkPalette
        case .orange:
            self = ThemePalette.orangePalette
        case .purple:
            self = ThemePalette.purplePalette
        }
    }

    init(colorScheme: ColorScheme, defaults: UserDefaults = .standard) {
        let theme = ThemePalette.cachedTheme
        self.init(theme: theme, systemColorScheme: colorScheme)
    }

    static func updateCachedTheme(_ theme: AppTheme) {
        cachedTheme = theme
    }

    private static func color(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red / 255, green: green / 255, blue: blue / 255)
    }

    private static func systemPalette(colorScheme: ColorScheme) -> ThemePalette {
        colorScheme == .dark ? darkPalette : lightPalette
    }

    private static var lightPalette: ThemePalette {
        makePalette(
            background: color(252, 249, 255),
            backgroundSecondary: color(241, 236, 248),
            cardBackground: Color.white.opacity(0.97),
            primaryText: color(33, 29, 39),
            secondaryText: color(108, 101, 125),
            accent: color(132, 116, 170),
            buttonBackground: color(201, 180, 232),
            buttonText: color(31, 27, 39),
            surface: Color.white.opacity(0.96),
            elevatedSurface: color(247, 242, 251).opacity(0.98),
            stroke: color(189, 173, 214).opacity(0.24),
            accentSoft: color(222, 209, 239).opacity(0.56),
            accentForeground: color(31, 27, 39),
            floatingButton: color(184, 157, 223),
            floatingButtonSecondary: color(234, 225, 246),
            floatingButtonForeground: color(28, 24, 35),
            shadow: Color.black.opacity(0.12),
            cardShadow: Color.black.opacity(0.08),
            weekActiveBackground: color(214, 197, 236).opacity(0.34),
            weekActiveForeground: color(30, 26, 38),
            digestStart: color(238, 229, 247),
            digestEnd: color(219, 204, 236),
            ambientGlowPrimary: color(210, 190, 234).opacity(0.24),
            ambientGlowSecondary: color(236, 225, 246).opacity(0.2)
        )
    }

    private static var darkPalette: ThemePalette {
        makePalette(
            background: color(11, 11, 15),
            backgroundSecondary: color(28, 23, 36),
            cardBackground: color(27, 22, 34).opacity(0.98),
            primaryText: Color.white.opacity(0.96),
            secondaryText: color(193, 185, 214).opacity(0.84),
            accent: color(214, 191, 229),
            buttonBackground: color(118, 82, 137),
            buttonText: Color.white,
            surface: color(22, 18, 28).opacity(0.97),
            elevatedSurface: color(32, 26, 42).opacity(0.98),
            stroke: Color.white.opacity(0.12),
            accentSoft: color(92, 67, 108).opacity(0.78),
            accentForeground: Color.white,
            floatingButton: color(126, 91, 145),
            floatingButtonSecondary: color(171, 143, 196),
            floatingButtonForeground: Color.white,
            shadow: Color.black.opacity(0.54),
            cardShadow: Color.black.opacity(0.24),
            weekActiveBackground: color(121, 92, 144).opacity(0.36),
            weekActiveForeground: Color.white,
            digestStart: color(52, 38, 66),
            digestEnd: color(22, 17, 28),
            ambientGlowPrimary: color(188, 151, 217).opacity(0.22),
            ambientGlowSecondary: color(121, 92, 144).opacity(0.18)
        )
    }

    private static var pinkPalette: ThemePalette {
        makePalette(
            background: color(255, 246, 250),
            backgroundSecondary: color(255, 232, 242),
            cardBackground: Color.white.opacity(0.98),
            primaryText: color(60, 35, 48),
            secondaryText: color(132, 92, 112),
            accent: color(225, 126, 181),
            buttonBackground: color(242, 162, 205),
            buttonText: Color.white,
            surface: Color.white.opacity(0.97),
            elevatedSurface: color(255, 240, 247).opacity(0.98),
            stroke: color(238, 185, 212).opacity(0.34),
            accentSoft: color(255, 214, 232).opacity(0.58),
            accentForeground: Color.white,
            floatingButton: color(231, 136, 187),
            floatingButtonSecondary: color(255, 223, 238),
            floatingButtonForeground: Color.white,
            shadow: color(142, 70, 113).opacity(0.16),
            cardShadow: color(142, 70, 113).opacity(0.08),
            weekActiveBackground: color(255, 214, 232).opacity(0.44),
            weekActiveForeground: color(72, 39, 56),
            digestStart: color(255, 232, 242),
            digestEnd: color(248, 207, 226),
            ambientGlowPrimary: color(255, 186, 218).opacity(0.26),
            ambientGlowSecondary: color(255, 221, 237).opacity(0.22)
        )
    }

    private static var greenPalette: ThemePalette {
        makePalette(
            background: color(246, 252, 246),
            backgroundSecondary: color(229, 243, 230),
            cardBackground: Color.white.opacity(0.98),
            primaryText: color(35, 58, 38),
            secondaryText: color(95, 125, 99),
            accent: color(113, 176, 120),
            buttonBackground: color(136, 194, 141),
            buttonText: Color.white,
            surface: Color.white.opacity(0.97),
            elevatedSurface: color(239, 248, 240).opacity(0.98),
            stroke: color(176, 213, 179).opacity(0.34),
            accentSoft: color(212, 236, 214).opacity(0.58),
            accentForeground: Color.white,
            floatingButton: color(118, 180, 125),
            floatingButtonSecondary: color(220, 241, 222),
            floatingButtonForeground: Color.white,
            shadow: color(66, 114, 73).opacity(0.14),
            cardShadow: color(66, 114, 73).opacity(0.08),
            weekActiveBackground: color(212, 236, 214).opacity(0.46),
            weekActiveForeground: color(40, 67, 43),
            digestStart: color(232, 245, 233),
            digestEnd: color(209, 233, 211),
            ambientGlowPrimary: color(176, 219, 180).opacity(0.24),
            ambientGlowSecondary: color(222, 242, 224).opacity(0.2)
        )
    }

    private static var orangePalette: ThemePalette {
        makePalette(
            background: color(255, 248, 240),
            backgroundSecondary: color(255, 235, 216),
            cardBackground: Color.white.opacity(0.98),
            primaryText: color(67, 42, 25),
            secondaryText: color(135, 98, 72),
            accent: color(242, 146, 74),
            buttonBackground: color(249, 165, 98),
            buttonText: Color.white,
            surface: Color.white.opacity(0.97),
            elevatedSurface: color(255, 242, 228).opacity(0.98),
            stroke: color(242, 187, 145).opacity(0.34),
            accentSoft: color(255, 223, 196).opacity(0.56),
            accentForeground: Color.white,
            floatingButton: color(240, 147, 79),
            floatingButtonSecondary: color(255, 227, 202),
            floatingButtonForeground: Color.white,
            shadow: color(144, 88, 40).opacity(0.14),
            cardShadow: color(144, 88, 40).opacity(0.08),
            weekActiveBackground: color(255, 223, 196).opacity(0.46),
            weekActiveForeground: color(74, 47, 28),
            digestStart: color(255, 237, 220),
            digestEnd: color(255, 215, 180),
            ambientGlowPrimary: color(255, 192, 137).opacity(0.24),
            ambientGlowSecondary: color(255, 224, 196).opacity(0.2)
        )
    }

    private static var purplePalette: ThemePalette {
        makePalette(
            background: color(249, 244, 255),
            backgroundSecondary: color(235, 225, 249),
            cardBackground: Color.white.opacity(0.97),
            primaryText: color(49, 35, 68),
            secondaryText: color(111, 92, 136),
            accent: color(173, 120, 212),
            buttonBackground: color(186, 136, 225),
            buttonText: Color.white,
            surface: Color.white.opacity(0.97),
            elevatedSurface: color(244, 236, 252).opacity(0.98),
            stroke: color(205, 180, 228).opacity(0.32),
            accentSoft: color(230, 213, 246).opacity(0.56),
            accentForeground: Color.white,
            floatingButton: color(172, 120, 212),
            floatingButtonSecondary: color(232, 220, 247),
            floatingButtonForeground: Color.white,
            shadow: color(93, 63, 128).opacity(0.14),
            cardShadow: color(93, 63, 128).opacity(0.08),
            weekActiveBackground: color(230, 213, 246).opacity(0.44),
            weekActiveForeground: color(56, 40, 76),
            digestStart: color(240, 230, 251),
            digestEnd: color(223, 203, 244),
            ambientGlowPrimary: color(203, 171, 232).opacity(0.24),
            ambientGlowSecondary: color(232, 220, 247).opacity(0.2)
        )
    }

    private static func makePalette(
        background: Color,
        backgroundSecondary: Color,
        cardBackground: Color,
        primaryText: Color,
        secondaryText: Color,
        accent: Color,
        buttonBackground: Color,
        buttonText: Color,
        surface: Color,
        elevatedSurface: Color,
        stroke: Color,
        accentSoft: Color,
        accentForeground: Color,
        floatingButton: Color,
        floatingButtonSecondary: Color,
        floatingButtonForeground: Color,
        shadow: Color,
        cardShadow: Color,
        weekActiveBackground: Color,
        weekActiveForeground: Color,
        digestStart: Color,
        digestEnd: Color,
        ambientGlowPrimary: Color,
        ambientGlowSecondary: Color
    ) -> ThemePalette {
        ThemePalette(
            background: background,
            backgroundSecondary: backgroundSecondary,
            cardBackground: cardBackground,
            primaryText: primaryText,
            secondaryText: secondaryText,
            accent: accent,
            buttonBackground: buttonBackground,
            buttonText: buttonText,
            surface: surface,
            elevatedSurface: elevatedSurface,
            stroke: stroke,
            accentSoft: accentSoft,
            accentForeground: accentForeground,
            floatingButton: floatingButton,
            floatingButtonSecondary: floatingButtonSecondary,
            floatingButtonForeground: floatingButtonForeground,
            shadow: shadow,
            cardShadow: cardShadow,
            weekActiveBackground: weekActiveBackground,
            weekActiveForeground: weekActiveForeground,
            digestStart: digestStart,
            digestEnd: digestEnd,
            ambientGlowPrimary: ambientGlowPrimary,
            ambientGlowSecondary: ambientGlowSecondary
        )
    }
}

struct AppBackgroundView: View {
    let palette: ThemePalette

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.background, palette.backgroundSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(palette.ambientGlowPrimary)
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: -130, y: -250)

            Circle()
                .fill(palette.ambientGlowSecondary)
                .frame(width: 260, height: 260)
                .blur(radius: 84)
                .offset(x: 150, y: 310)
        }
        .ignoresSafeArea()
    }
}
