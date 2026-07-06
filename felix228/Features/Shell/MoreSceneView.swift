//
//  MoreSceneView
//  felix228
//
//  Created by Codex on 13.05.2026.
//

import SwiftUI
import UIKit
import UserNotifications

struct MoreSceneView: View {
    @EnvironmentObject private var cloudAccount: CloudAccountManager
    @EnvironmentObject private var localization: LocalizationManager
    @EnvironmentObject private var moodCustomization: MoodCustomizationManager
    @EnvironmentObject private var premiumAccess: PremiumAccessManager
    @EnvironmentObject private var achievementManager: AchievementManager
    @EnvironmentObject private var themeManager: ThemeManager
    @AppStorage("dailyReminderEnabled") private var reminderEnabled = false
    @AppStorage("dailyReminderHour") private var reminderHour = 22
    @AppStorage("dailyReminderMinute") private var reminderMinute = 0
    @State private var isPresentingAccountSettings = false
    @State private var isPresentingAchievements = false
    @State private var isPresentingMoodEditor = false
    @State private var isPresentingReminderSettings = false
    @State private var isPresentingSubscription = false
    @State private var isPresentingLanguageSettings = false
    @State private var isPresentingThemeSettings = false
    @State private var presentedLegalDestination: LegalDestination?

    let topInset: CGFloat
    let palette: ThemePalette
    let totalEntries: Int
    let totalGoals: Int
    let completedGoalsTodayCount: Int
    let activityCount: Int
    let onCreateEntry: () -> Void
    let onManageActivities: () -> Void
    let onShowGoals: () -> Void
    let onShowStatistics: () -> Void
    let onShowCalendar: () -> Void

    private var reminderSummaryText: String {
        guard reminderEnabled else { return localization.pick("Выкл.", "Off") }
        return Self.timeFormatter.string(
            from: JournalReminderManager.date(hour: reminderHour, minute: reminderMinute)
        )
    }

    private var themeSummaryText: String {
        themeManager.currentTheme.localizedTitle(for: localization.selectedLanguage)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 12) {
                    Text(localization.pick("Больше", "More"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(palette.primaryText)

                    Text(localization.pick(
                        "Настройки, быстрые переходы и всё, что поддерживает твой дневник.",
                        "Settings, quick shortcuts, and everything that supports your journal."
                    ))
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, topInset + 16)
                .padding(.horizontal, 8)

                StatisticsSectionCard(
                    palette: palette,
                    title: localization.pick("Текущее состояние", "Current snapshot"),
                    subtitle: nil
                ) {
                    HStack(spacing: 12) {
                        MetricCapsuleCard(
                            palette: palette,
                            title: localization.pick("Записей", "Entries"),
                            value: "\(totalEntries)",
                            tint: palette.accent
                        )
                        MetricCapsuleCard(
                            palette: palette,
                            title: localization.pick("Целей", "Goals"),
                            value: "\(completedGoalsTodayCount)/\(max(totalGoals, 1))",
                            tint: palette.floatingButtonSecondary
                        )
                    }
                }

                StatisticsSectionCard(
                    palette: palette,
                    title: localization.pick("Достижения", "Achievements"),
                    subtitle: localization.pick(
                        "\(achievementManager.unlockedCount) из \(achievementManager.totalCount) наград уже открыто.",
                        "\(achievementManager.unlockedCount) of \(achievementManager.totalCount) rewards already unlocked."
                    )
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        if achievementManager.recentUnlockedBadges.isEmpty {
                            EmptyBadgeRow(
                                palette: palette,
                                text: localization.pick(
                                    "Сделай первую запись, отметь цель или открой premium, чтобы собрать первые награды.",
                                    "Create your first entry, complete a goal, or unlock premium to earn your first rewards."
                                )
                            )
                        } else {
                            ForEach(achievementManager.recentUnlockedBadges.prefix(2)) { badge in
                                AchievementPreviewRow(
                                    badge: badge,
                                    palette: palette
                                )
                            }
                        }

                        Button {
                            isPresentingAchievements = true
                        } label: {
                            Text(localization.pick("Открыть достижения", "Open achievements"))
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(palette.floatingButtonForeground)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(palette.floatingButton)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                MoreSectionCard(
                    palette: palette,
                    title: localization.pick("Быстрые переходы", "Quick shortcuts"),
                    rows: [
                        MoreRowModel(
                            title: localization.pick("Цели", "Goals"),
                            icon: "target",
                            tint: palette.floatingButtonSecondary,
                            trailingText: "\(totalGoals)",
                            action: onShowGoals
                        ),
                        MoreRowModel(
                            title: localization.pick("Недельные отчёты", "Monthly stats"),
                            icon: "chart.bar.fill",
                            tint: palette.accent,
                            trailingText: localization.pick("Открыть", "Open"),
                            action: onShowStatistics
                        ),
                        MoreRowModel(
                            title: localization.pick("Календарь месяца", "Monthly calendar"),
                            icon: "calendar",
                            tint: palette.floatingButton,
                            trailingText: localization.pick("Открыть", "Open"),
                            action: onShowCalendar
                        ),
                    ]
                )

                MoreSectionCard(
                    palette: palette,
                    title: localization.pick("Настройки", "Settings"),
                    rows: [
                        MoreRowModel(
                            title: localization.pick("Редактировать настроения", "Edit moods"),
                            icon: "face.smiling.inverse",
                            tint: palette.floatingButtonSecondary,
                            trailingText: moodCustomization
                                .effectiveTheme(hasPremiumAccess: premiumAccess.hasPremiumAccess)
                                .localizedTitle(for: localization.selectedLanguage),
                            action: {
                                isPresentingMoodEditor = true
                            }
                        ),
                        MoreRowModel(
                            title: localization.pick("Редактировать занятия", "Edit activities"),
                            icon: "figure.walk",
                            tint: palette.accent,
                            trailingText: "\(activityCount)",
                            action: onManageActivities
                        ),
                        MoreRowModel(
                            title: localization.pick("Язык приложения", "App language"),
                            icon: "globe",
                            tint: palette.floatingButtonSecondary,
                            trailingText: localization.isUsingSystemLanguage
                                ? localization.systemLanguageSummary()
                                : localization.selectedLanguage.title,
                            action: {
                                isPresentingLanguageSettings = true
                            }
                        ),
                        MoreRowModel(
                            title: localization.pick("Тема оформления", "Appearance theme"),
                            icon: "paintpalette.fill",
                            tint: palette.floatingButton,
                            trailingText: themeSummaryText,
                            action: {
                                isPresentingThemeSettings = true
                            }
                        ),
                    ]
                )

                MoreSectionCard(
                    palette: palette,
                    title: localization.pick("Данные и приложение", "Data and app"),
                    rows: [
                        MoreRowModel(
                            title: localization.pick("Аккаунт и синхронизация", "Account and sync"),
                            icon: "person.crop.circle.badge.checkmark",
                            tint: palette.floatingButton,
                            trailingText: cloudAccount.accountRowText,
                            action: {
                                isPresentingAccountSettings = true
                            }
                        ),
                        MoreRowModel(
                            title: localization.pick("Экспорт записей", "Export entries"),
                            icon: "square.and.arrow.up",
                            tint: palette.floatingButtonSecondary,
                            trailingText: "\(totalEntries)",
                            action: nil
                        ),
                        MoreRowModel(
                            title: localization.pick("Напоминания", "Reminders"),
                            icon: "bell.fill",
                            tint: palette.accent,
                            trailingText: reminderSummaryText,
                            action: {
                                isPresentingReminderSettings = true
                            }
                        ),
                        MoreRowModel(
                            title: localization.pick("Новая запись", "New entry"),
                            icon: "plus.circle.fill",
                            tint: palette.floatingButton,
                            trailingText: localization.pick("Создать", "Create"),
                            action: onCreateEntry
                        ),
                    ]
                )

                MoreSectionCard(
                    palette: palette,
                    title: localization.pick("Право и помощь", "Legal and support"),
                    rows: [
                        MoreRowModel(
                            title: localization.pick("Политика конфиденциальности", "Privacy policy"),
                            icon: "hand.raised.fill",
                            tint: palette.floatingButtonSecondary,
                            trailingText: localization.pick("Открыть", "Open"),
                            action: {
                                presentedLegalDestination = .privacyPolicy
                            }
                        ),
                        MoreRowModel(
                            title: localization.pick("Условия использования", "Terms of use"),
                            icon: "doc.text.fill",
                            tint: palette.accent,
                            trailingText: localization.pick("Открыть", "Open"),
                            action: {
                                presentedLegalDestination = .termsOfUse
                            }
                        ),
                        MoreRowModel(
                            title: localization.pick("Поддержка", "Support"),
                            icon: "lifepreserver.fill",
                            tint: palette.floatingButton,
                            trailingText: localization.pick("Открыть", "Open"),
                            action: {
                                presentedLegalDestination = .support
                            }
                        ),
                    ]
                )

                StatisticsSectionCard(
                    palette: palette,
                    title: premiumAccess.hasPremiumAccess
                        ? localization.pick("Felix Premium уже открыт", "Felix Premium is already unlocked")
                        : localization.pick("Подписка Felix Premium", "Felix Premium subscription"),
                    subtitle: premiumAccess.hasPremiumAccess
                        ? localization.pick(
                            "У тебя уже есть полный доступ ко всем темам и premium-обновлениям.",
                            "You already have full access to all themes and premium updates."
                        )
                        : localization.pick(
                            "Оформи подписку и открой всё приложение, закрытые темы стикеров и будущие premium-обновления.",
                            "Subscribe to unlock the full app, locked sticker themes, and future premium updates."
                        )
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(localization.pick(
                            "Каждая подписка на приложение — это вкусняшка коту Феликсу.",
                            "Every subscription is a little treat for Felix the cat."
                        ))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            isPresentingSubscription = true
                        } label: {
                            Text(localization.pick("Оформить подписку", "Subscribe"))
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(palette.floatingButtonForeground)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(palette.floatingButton)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 150)
        }
        .sheet(isPresented: $isPresentingAccountSettings) {
            AccountSettingsView()
        }
        .sheet(isPresented: $isPresentingAchievements) {
            AchievementsCenterView()
        }
        .sheet(isPresented: $isPresentingMoodEditor) {
            MoodEditorView()
        }
        .sheet(isPresented: $isPresentingLanguageSettings) {
            LanguageSettingsView()
        }
        .sheet(isPresented: $isPresentingThemeSettings) {
            ThemeSettingsView()
        }
        .sheet(isPresented: $isPresentingReminderSettings) {
            ReminderSettingsView()
        }
        .sheet(isPresented: $isPresentingSubscription) {
            PremiumSubscriptionView()
        }
        .sheet(item: $presentedLegalDestination) { destination in
            LegalAndSupportView(destination: destination)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

enum JournalReminderManager {
    static let notificationIdentifier = "felix228.dailyReminder"
    static var defaultMessage: String {
        AppLanguage.current().localized(
            "Напиши как прошел твой день",
            "Напиши, як пройшов твій день",
            "Write how your day went"
        )
    }

    private static var notificationTitle: String {
        AppLanguage.current().localized("Дневник эмоций", "Щоденник емоцій", "Mood journal")
    }

    static func normalizedMessage(_ message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultMessage : trimmed
    }

    static func date(hour: Int, minute: Int, calendar: Calendar = .current) -> Date {
        let normalizedHour = max(0, min(hour, 23))
        let normalizedMinute = max(0, min(minute, 59))
        let components = DateComponents(hour: normalizedHour, minute: normalizedMinute)
        return calendar.date(from: components) ?? .now
    }

    static func timeComponents(from date: Date, calendar: Calendar = .current) -> DateComponents {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return DateComponents(
            hour: components.hour ?? 22,
            minute: components.minute ?? 0
        )
    }

    static func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    static func requestAuthorizationIfNeeded() async throws -> Bool {
        switch await currentAuthorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return try await withCheckedThrowingContinuation { continuation in
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        @unknown default:
            return false
        }
    }

    static func scheduleDailyReminder(hour: Int, minute: Int, message: String) async throws {
        cancelReminder()

        let content = UNMutableNotificationContent()
        content.title = notificationTitle
        content.body = normalizedMessage(message)
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: hour, minute: minute),
            repeats: true
        )
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    static func cancelReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
    }
}

private struct ReminderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    @AppStorage("dailyReminderEnabled") private var storedReminderEnabled = false
    @AppStorage("dailyReminderHour") private var storedReminderHour = 22
    @AppStorage("dailyReminderMinute") private var storedReminderMinute = 0
    @AppStorage("dailyReminderMessage") private var storedReminderMessage = JournalReminderManager.defaultMessage

    @State private var draftEnabled = false
    @State private var draftTime = JournalReminderManager.date(hour: 22, minute: 0)
    @State private var draftMessage = JournalReminderManager.defaultMessage
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var hasLoadedDraft = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    private var normalizedDraftMessage: String {
        JournalReminderManager.normalizedMessage(draftMessage)
    }

    private var formattedDraftTime: String {
        Self.timeFormatter.string(from: draftTime)
    }

    private var statusTitle: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Уведомления разрешены"
        case .denied:
            return "Уведомления отключены"
        case .notDetermined:
            return "Разрешение спросим при сохранении"
        @unknown default:
            return "Статус недоступен"
        }
    }

    private var statusDetail: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Напоминание будет приходить ежедневно в выбранное время."
        case .denied:
            return "Чтобы баннеры приходили, нужно снова разрешить уведомления в настройках iPhone."
        case .notDetermined:
            return "Когда ты включишь напоминание и нажмёшь сохранить, iPhone попросит доступ."
        @unknown default:
            return "Если что-то пойдёт не так, можно заново сохранить настройки ниже."
        }
    }

    private var statusTint: Color {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return palette.accent
        case .denied:
            return .red.opacity(0.86)
        case .notDetermined:
            return palette.floatingButton
        @unknown default:
            return .secondary
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView(palette: palette)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        StatisticsSectionCard(
                            palette: palette,
                            title: "Ежедневное напоминание",
                            subtitle: "Выбери время, когда хочется мягко напомнить себе о заметке."
                        ) {
                            VStack(alignment: .leading, spacing: 18) {
                                HStack(alignment: .top, spacing: 14) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Включить напоминание")
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(.primary)

                                        Text(statusTitle)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(statusTint)

                                        Text(statusDetail)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer(minLength: 10)

                                    Toggle("", isOn: $draftEnabled)
                                        .labelsHidden()
                                        .tint(palette.accent)
                                }

                                Divider()
                                    .overlay(palette.stroke)

                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Время")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)

                                        Text(draftEnabled ? "Напоминание придёт в \(formattedDraftTime)." : "Можно выбрать время заранее, даже если напоминание пока выключено.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    DatePicker(
                                        "Время",
                                        selection: $draftTime,
                                        displayedComponents: .hourAndMinute
                                    )
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                }
                            }
                        }

                        StatisticsSectionCard(
                            palette: palette,
                            title: "Текст уведомления",
                            subtitle: "Пользователь увидит именно этот текст в напоминании."
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                TextEditor(text: $draftMessage)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .frame(minHeight: 120)
                                    .padding(12)
                                    .scrollContentBackground(.hidden)
                                    .background(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .fill(palette.surface)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .stroke(palette.stroke, lineWidth: 1)
                                    )

                                HStack {
                                    Button("Вернуть текст по умолчанию") {
                                        draftMessage = JournalReminderManager.defaultMessage
                                    }
                                    .buttonStyle(.plain)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(palette.accent)

                                    Spacer()

                                    Text("\(normalizedDraftMessage.count) символов")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        StatisticsSectionCard(
                            palette: palette,
                            title: "Предпросмотр",
                            subtitle: nil
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Дневник эмоций")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(normalizedDraftMessage)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(draftEnabled ? "Будет приходить ежедневно в \(formattedDraftTime)." : "Сейчас напоминание выключено, но текст уже можно подготовить.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if authorizationStatus == .denied {
                            StatisticsSectionCard(
                                palette: palette,
                                title: "Нужно разрешение iPhone",
                                subtitle: "Без доступа к уведомлениям приложение не сможет показать баннер в выбранное время."
                            ) {
                                Button {
                                    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                                    openURL(settingsURL)
                                } label: {
                                    Text("Открыть настройки iPhone")
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(palette.floatingButtonForeground)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(palette.floatingButton)
                                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 140)
                }
            }
            .navigationTitle("Напоминания")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                        .overlay(palette.stroke)

                    Button {
                        Task {
                            await saveReminder()
                        }
                    } label: {
                        Text(isSaving ? "Сохраняем..." : "Сохранить напоминание")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(isSaving ? palette.floatingButton.opacity(0.42) : palette.floatingButton)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial)
            }
            .task {
                await loadDraftIfNeeded()
            }
            .alert(
                "Не удалось сохранить напоминание",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { newValue in
                        if !newValue {
                            errorMessage = nil
                        }
                    }
                )
            ) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @MainActor
    private func loadDraftIfNeeded() async {
        guard !hasLoadedDraft else { return }

        draftEnabled = storedReminderEnabled
        draftTime = JournalReminderManager.date(hour: storedReminderHour, minute: storedReminderMinute)
        draftMessage = JournalReminderManager.normalizedMessage(storedReminderMessage)
        authorizationStatus = await JournalReminderManager.currentAuthorizationStatus()
        hasLoadedDraft = true
    }

    @MainActor
    private func saveReminder() async {
        guard !isSaving else { return }

        isSaving = true
        defer { isSaving = false }

        let timeComponents = JournalReminderManager.timeComponents(from: draftTime)
        let hour = timeComponents.hour ?? 22
        let minute = timeComponents.minute ?? 0
        let normalizedMessage = JournalReminderManager.normalizedMessage(draftMessage)

        storedReminderHour = hour
        storedReminderMinute = minute
        storedReminderMessage = normalizedMessage

        do {
            if draftEnabled {
                let granted = try await JournalReminderManager.requestAuthorizationIfNeeded()
                authorizationStatus = await JournalReminderManager.currentAuthorizationStatus()

                guard granted else {
                    storedReminderEnabled = false
                    errorMessage = "Разреши уведомления для этого приложения в настройках iPhone, и тогда напоминание будет приходить каждый день."
                    return
                }

                try await JournalReminderManager.scheduleDailyReminder(
                    hour: hour,
                    minute: minute,
                    message: normalizedMessage
                )

                storedReminderEnabled = true
            } else {
                JournalReminderManager.cancelReminder()
                storedReminderEnabled = false
                authorizationStatus = await JournalReminderManager.currentAuthorizationStatus()
            }

            dismiss()
        } catch {
            storedReminderEnabled = false
            authorizationStatus = await JournalReminderManager.currentAuthorizationStatus()
            errorMessage = "Напоминание не сохранилось. Попробуй ещё раз. Если ошибка повторится, проверь разрешение на уведомления в настройках iPhone."
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
