//
//  LocalizationManager.swift
//  felix228
//
//  Created by Codex on 19.05.2026.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class LocalizationManager: ObservableObject {
    @Published private(set) var selectedLanguage: AppLanguage
    @Published private(set) var isUsingSystemLanguage: Bool

    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    private static let ukrainianTranslations: [String: String] = [
        "Как на iPhone": "Як на iPhone",
        "Записи": "Записи",
        "Статистика": "Статистика",
        "Календарь": "Календар",
        "Больше": "Більше",
        "Эмоции": "Емоції",
        "Занятия": "Заняття",
        "Цели": "Цілі",
        "Язык приложения": "Мова застосунку",
        "Язык": "Мова",
        "Готово": "Готово",
        "Закрыть": "Закрити",
        "Тема": "Тема",
        "Тема оформления": "Тема оформлення",
        "Редактор настроения": "Редактор настрою",
        "Тема смайлов": "Тема смайлів",
        "Названия настроений": "Назви настроїв",
        "Вернуть стандартные названия": "Повернути стандартні назви",
        "Текущее состояние": "Поточний стан",
        "Достижения": "Досягнення",
        "Открыть достижения": "Відкрити досягнення",
        "Настройки": "Налаштування",
        "Редактировать настроения": "Редагувати настрої",
        "Редактировать занятия": "Редагувати заняття",
        "Феликс в Dynamic Island": "Фелікс у Dynamic Island",
        "Данные и приложение": "Дані та застосунок",
        "Аккаунт и синхронизация": "Акаунт і синхронізація",
        "Экспорт записей": "Експорт записів",
        "Напоминания": "Нагадування",
        "Новая запись": "Новий запис",
        "Создать": "Створити",
        "Право и помощь": "Право та допомога",
        "Политика конфиденциальности": "Політика конфіденційності",
        "Условия использования": "Умови використання",
        "Поддержка": "Підтримка",
        "Открыть": "Відкрити",
        "Подписка Felix Premium": "Підписка Felix Premium",
        "Оформить подписку": "Оформити підписку",
        "Счётчик настроения": "Лічильник настрою",
        "График настроения": "Графік настрою",
        "Популярные занятия": "Популярні заняття",
        "Пока без занятий": "Поки без занять",
        "Сегодня": "Сьогодні",
        "Вчера": "Учора",
        "Дней": "Днів",
        "Серия": "Серія",
        "Выбери день": "Обери день",
        "Выбери занятие": "Обери заняття",
        "Выбери цель": "Обери ціль",
        "Нет": "Ні",
        "Да": "Так",
        "Пока пусто": "Поки порожньо",
        "Без оценок": "Без оцінок",
        "Без эмоции": "Без емоції",
        "Записей нет": "Записів немає",
        "Пока нет записей за этот месяц": "Поки немає записів за цей місяць",
        "Без заметки": "Без нотатки",
        "Удалить": "Видалити",
        "Ок": "Гаразд",
        "Не удалось сохранить": "Не вдалося зберегти",
        "Попробуй ещё раз.": "Спробуй ще раз.",
        "Не удалось обновить цель.": "Не вдалося оновити ціль.",
        "Не удалось удалить цель.": "Не вдалося видалити ціль.",
        "Не удалось создать цель.": "Не вдалося створити ціль.",
        "Дней подряд": "Днів поспіль",
        "Показать всё": "Показати все",
        "Открыто": "Відкрито",
        "Закрыто": "Закрито",
        "Получено": "Отримано",
        "Награда": "Нагорода",
        "Понятно": "Зрозуміло",
        "Продолжай вести дневник": "Продовжуй вести щоденник"
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let override = AppLanguage.storedOverride(defaults: defaults)
        self.selectedLanguage = override ?? AppLanguage.systemLanguage()
        self.isUsingSystemLanguage = override == nil

        NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshFromPreferences()
            }
            .store(in: &cancellables)
    }

    var locale: Locale {
        Locale(identifier: selectedLanguage.localeIdentifier)
    }

    func setLanguage(_ language: AppLanguage) {
        defaults.set(language.rawValue, forKey: AppLanguage.storageKey)
        selectedLanguage = language
        isUsingSystemLanguage = false
    }

    func followSystemLanguage() {
        defaults.removeObject(forKey: AppLanguage.storageKey)
        selectedLanguage = AppLanguage.systemLanguage()
        isUsingSystemLanguage = true
    }

    func systemLanguageSummary() -> String {
        pick("Как на iPhone", "Як на iPhone", "Same as iPhone") + " • " + selectedLanguage.title
    }

    private func refreshFromPreferences() {
        if let override = AppLanguage.storedOverride(defaults: defaults) {
            selectedLanguage = override
            isUsingSystemLanguage = false
            return
        }

        selectedLanguage = AppLanguage.systemLanguage()
        isUsingSystemLanguage = true
    }

    func setLanguageIfNeeded(_ language: AppLanguage) {
        guard selectedLanguage != language || isUsingSystemLanguage else { return }
        defaults.set(language.rawValue, forKey: AppLanguage.storageKey)
        selectedLanguage = language
        isUsingSystemLanguage = false
    }

    func pick(_ russian: String, _ english: String) -> String {
        switch selectedLanguage {
        case .russian:
            return russian
        case .ukrainian:
            return Self.ukrainianTranslations[russian] ?? russian
        case .english:
            return english
        }
    }

    func pick(_ russian: String, _ ukrainian: String, _ english: String) -> String {
        selectedLanguage.localized(russian, ukrainian, english)
    }

    func format(_ russian: String, _ english: String, _ arguments: CVarArg...) -> String {
        let template = pick(russian, english)
        return String(format: template, locale: locale, arguments: arguments)
    }

    func monthTitle(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = selectedLanguage.monthTitleFormat
        return formatter.string(from: date).capitalized
    }

    func dayMonthTitle(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = selectedLanguage.dayMonthFormat
        return formatter.string(from: date)
    }

    func shortWeekdayTitle(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "EE"
        return formatter.string(from: date).capitalized
    }

    func title(for tab: JournalTab) -> String {
        switch tab {
        case .records:
            return pick("Записи", "Records")
        case .statistics:
            return pick("Статистика", "Stats")
        case .calendar:
            return pick("Календарь", "Calendar")
        case .more:
            return pick("Больше", "More")
        }
    }

    func title(for mode: CalendarOverviewMode) -> String {
        switch mode {
        case .moods:
            return pick("Эмоции", "Moods")
        case .activities:
            return pick("Занятия", "Activities")
        case .goals:
            return pick("Цели", "Goals")
        }
    }
}
