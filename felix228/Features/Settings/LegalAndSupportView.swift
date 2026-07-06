//
//  LegalAndSupportView.swift
//  felix228
//
//  Created by Codex on 18.05.2026.
//

import SwiftUI

enum LegalDestination: String, Identifiable {
    case privacyPolicy
    case termsOfUse
    case support

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacyPolicy:
            "Политика конфиденциальности"
        case .termsOfUse:
            "Условия использования"
        case .support:
            "Поддержка"
        }
    }

    var subtitle: String {
        switch self {
        case .privacyPolicy:
            "Коротко и понятно о том, какие данные хранит дневник и как они используются."
        case .termsOfUse:
            "Что входит в premium, как работает подписка и где ей управлять."
        case .support:
            "Куда писать, если что-то пошло не так или нужен ответ по приложению."
        }
    }

    var systemImageName: String {
        switch self {
        case .privacyPolicy:
            "hand.raised.fill"
        case .termsOfUse:
            "doc.text.fill"
        case .support:
            "lifepreserver.fill"
        }
    }

    var highlights: [String] {
        switch self {
        case .privacyPolicy:
            [
                "Записи, цели, занятия и достижения по умолчанию хранятся локально на iPhone через SwiftData.",
                "Если пользователь подключает аккаунт, данные могут синхронизироваться с Firebase и храниться в облаке.",
                "Для входа в аккаунт используются Google Sign-In и Sign in with Apple, а напоминания отправляются через локальные уведомления iOS."
            ]
        case .termsOfUse:
            [
                "Felix Premium открывает premium-темы стикеров, Felix в Dynamic Island и будущие расширенные функции.",
                "Подписка оплачивается через App Store, может автоматически продлеваться и управляется в настройках Apple ID.",
                "Кнопка `Восстановить покупки` доступна прямо на экране подписки, если доступ уже был куплен раньше."
            ]
        case .support:
            [
                "Для быстрого разбора проблемы приложи версию iOS, модель iPhone и короткое описание того, что произошло.",
                "Если вопрос касается покупок, сначала попробуй `Восстановить покупки`, а потом уже пиши в поддержку.",
                "Скриншот экрана ошибки почти всегда помогает ответить быстрее."
            ]
        }
    }
}

enum AppLegalConfiguration {
    static let privacyPolicyURLString = ""
    static let termsOfUseURLString = ""
    static let supportWebsiteURLString = ""
    static let supportEmailAddress = ""

    static var appName: String {
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return displayName
        }

        return "MoodCat"
    }

    static var privacyPolicyURL: URL? {
        normalizedURL(from: privacyPolicyURLString)
    }

    static var termsOfUseURL: URL? {
        normalizedURL(from: termsOfUseURLString)
    }

    static var supportWebsiteURL: URL? {
        normalizedURL(from: supportWebsiteURLString)
    }

    static var supportMailURL: URL? {
        let trimmed = supportEmailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "mailto:\(trimmed)")
    }

    private static func normalizedURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}

struct LegalAndSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    let destination: LegalDestination

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView(palette: palette)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        heroCard
                        detailsCard
                        actionCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(destination.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
        .textSelection(.enabled)
    }

    private var heroCard: some View {
        StatisticsSectionCard(
            palette: palette,
            title: destination.title,
            subtitle: destination.subtitle
        ) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.accentSoft)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: destination.systemImageName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.accentForeground)
                    )

                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var detailsCard: some View {
        StatisticsSectionCard(
            palette: palette,
            title: detailsTitle,
            subtitle: nil
        ) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(destination.highlights, id: \.self) { item in
                    LegalBulletRow(
                        text: item,
                        palette: palette
                    )
                }
            }
        }
    }

    private var actionCard: some View {
        StatisticsSectionCard(
            palette: palette,
            title: actionTitle,
            subtitle: actionSubtitle
        ) {
            VStack(alignment: .leading, spacing: 14) {
                switch destination {
                case .privacyPolicy:
                    if let privacyPolicyURL = AppLegalConfiguration.privacyPolicyURL {
                        SupportActionButton(
                            title: "Открыть полную политику",
                            icon: "safari.fill",
                            palette: palette
                        ) {
                            openURL(privacyPolicyURL)
                        }
                    } else {
                        MissingLegalLinkNotice(
                            text: "Сейчас внутри приложения показана краткая версия. Перед релизом добавь реальный URL политики конфиденциальности в `AppLegalConfiguration`.",
                            palette: palette
                        )
                    }
                case .termsOfUse:
                    if let termsOfUseURL = AppLegalConfiguration.termsOfUseURL {
                        SupportActionButton(
                            title: "Открыть полные условия",
                            icon: "safari.fill",
                            palette: palette
                        ) {
                            openURL(termsOfUseURL)
                        }
                    } else {
                        MissingLegalLinkNotice(
                            text: "Сейчас внутри приложения показана краткая версия. Перед релизом добавь реальный URL условий использования или EULA в `AppLegalConfiguration`.",
                            palette: palette
                        )
                    }
                case .support:
                    if let supportMailURL = AppLegalConfiguration.supportMailURL {
                        SupportActionButton(
                            title: "Написать в поддержку",
                            icon: "envelope.fill",
                            palette: palette
                        ) {
                            openURL(supportMailURL)
                        }
                    }

                    if let supportWebsiteURL = AppLegalConfiguration.supportWebsiteURL {
                        SupportActionButton(
                            title: "Открыть сайт поддержки",
                            icon: "globe",
                            palette: palette
                        ) {
                            openURL(supportWebsiteURL)
                        }
                    }

                    if AppLegalConfiguration.supportMailURL == nil && AppLegalConfiguration.supportWebsiteURL == nil {
                        MissingLegalLinkNotice(
                            text: "Перед релизом добавь рабочую почту или сайт поддержки в `AppLegalConfiguration`, чтобы пользователь мог связаться с тобой из приложения.",
                            palette: palette
                        )
                    }
                }
            }
        }
    }

    private var summaryText: String {
        switch destination {
        case .privacyPolicy:
            return "\(AppLegalConfiguration.appName) бережно хранит дневник локально на устройстве и отправляет данные в облако только если пользователь сам подключает аккаунт."
        case .termsOfUse:
            return "Подписка нужна для расширенной версии \(AppLegalConfiguration.appName): она открывает premium-темы, Felix в Dynamic Island и будущие premium-обновления."
        case .support:
            return "Если в \(AppLegalConfiguration.appName) что-то сломалось, появились вопросы по подписке или синхронизации, этот раздел поможет быстро дойти до ответа."
        }
    }

    private var detailsTitle: String {
        switch destination {
        case .privacyPolicy:
            "Что происходит с данными"
        case .termsOfUse:
            "Как работает подписка"
        case .support:
            "Как получить помощь быстрее"
        }
    }

    private var actionTitle: String {
        switch destination {
        case .privacyPolicy:
            "Полная версия документа"
        case .termsOfUse:
            "Полные условия"
        case .support:
            "Связаться и открыть ссылки"
        }
    }

    private var actionSubtitle: String {
        switch destination {
        case .privacyPolicy:
            "Если уже есть опубликованная политика, сюда можно вывести прямую ссылку."
        case .termsOfUse:
            "Если у приложения есть отдельные условия или опубликованная EULA, открой её отсюда."
        case .support:
            "Почта и сайт поддержки настраиваются прямо в `AppLegalConfiguration`."
        }
    }
}

private struct LegalBulletRow: View {
    let text: String
    let palette: ThemePalette

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "pawprint.fill")
                .foregroundStyle(palette.accent)
                .padding(.top, 2)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct MissingLegalLinkNotice: View {
    let text: String
    let palette: ThemePalette

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.bubble.fill")
                .foregroundStyle(.orange)
                .padding(.top, 2)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
    }
}

private struct SupportActionButton: View {
    let title: String
    let icon: String
    let palette: ThemePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline.weight(.semibold))

                Text(title)
                    .font(.headline.weight(.semibold))

                Spacer()
            }
            .foregroundStyle(palette.floatingButtonForeground)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(palette.floatingButton)
            )
        }
        .buttonStyle(.plain)
    }
}
