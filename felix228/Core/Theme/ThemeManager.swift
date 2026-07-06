//
//  ThemeManager.swift
//  felix228
//
//  Created by Codex on 19.05.2026.
//

import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    @AppStorage(AppTheme.storageKey) private var storedThemeRaw = AppTheme.system.rawValue
    @Published private(set) var currentTheme: AppTheme

    init() {
        currentTheme = AppTheme.current()
        ThemePalette.updateCachedTheme(currentTheme)
    }

    var selectedTheme: AppTheme {
        AppTheme(storageValue: storedThemeRaw)
    }

    func setTheme(_ theme: AppTheme, hasPremiumAccess: Bool? = nil) {
        storedThemeRaw = theme.rawValue
        let resolvedTheme = theme.resolvedTheme(hasPremiumAccess: hasPremiumAccess ?? false)
        guard currentTheme != resolvedTheme else {
            ThemePalette.updateCachedTheme(resolvedTheme)
            return
        }
        currentTheme = resolvedTheme
        ThemePalette.updateCachedTheme(resolvedTheme)
    }

    func refreshCurrentTheme(hasPremiumAccess: Bool) {
        let resolvedTheme = selectedTheme.resolvedTheme(hasPremiumAccess: hasPremiumAccess)
        guard currentTheme != resolvedTheme else {
            ThemePalette.updateCachedTheme(resolvedTheme)
            return
        }
        currentTheme = resolvedTheme
        ThemePalette.updateCachedTheme(resolvedTheme)
    }

    func palette(for systemColorScheme: ColorScheme) -> ThemePalette {
        ThemePalette(theme: currentTheme, systemColorScheme: systemColorScheme)
    }

    var preferredColorScheme: ColorScheme? {
        currentTheme.preferredColorScheme
    }
}
