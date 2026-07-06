//
//  AppLanguage.swift
//  felix228
//
//  Created by Codex on 19.05.2026.
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case russian = "ru"
    case ukrainian = "uk"
    case english = "en"

    static let storageKey = "selectedAppLanguage"

    var id: String { rawValue }

    static func storedOverride(defaults: UserDefaults = .standard) -> AppLanguage? {
        guard let rawValue = defaults.string(forKey: storageKey) else {
            return nil
        }

        return AppLanguage(rawValue: rawValue)
    }

    static func systemLanguage(localeIdentifiers: [String] = Locale.preferredLanguages) -> AppLanguage {
        let identifier = localeIdentifiers.first?.lowercased() ?? Locale.current.identifier.lowercased()
        if identifier.hasPrefix("uk") {
            return .ukrainian
        }

        if identifier.hasPrefix("ru") {
            return .russian
        }

        return .english
    }

    static func current(defaults: UserDefaults = .standard) -> AppLanguage {
        if let language = storedOverride(defaults: defaults) {
            return language
        }

        return systemLanguage()
    }

    var title: String {
        switch self {
        case .russian:
            return "Русский"
        case .ukrainian:
            return "Українська"
        case .english:
            return "English"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .russian:
            return "ru_RU"
        case .ukrainian:
            return "uk_UA"
        case .english:
            return "en_US"
        }
    }

    var isRussian: Bool {
        self == .russian
    }

    var isUkrainian: Bool {
        self == .ukrainian
    }

    var monthTitleFormat: String {
        switch self {
        case .russian:
            return "LLLL yyyy' г.'"
        case .ukrainian, .english:
            return "LLLL yyyy"
        }
    }

    var dayMonthFormat: String {
        switch self {
        case .russian, .ukrainian:
            return "d MMMM"
        case .english:
            return "MMMM d"
        }
    }

    var shortDayMonthFormat: String {
        switch self {
        case .russian, .ukrainian:
            return "d MMM"
        case .english:
            return "MMM d"
        }
    }

    var dayMonthTimeFormat: String {
        switch self {
        case .russian, .ukrainian:
            return "d MMMM, HH:mm"
        case .english:
            return "MMMM d, HH:mm"
        }
    }

    func localized(_ russian: String, _ ukrainian: String, _ english: String) -> String {
        switch self {
        case .russian:
            return russian
        case .ukrainian:
            return ukrainian
        case .english:
            return english
        }
    }
}
