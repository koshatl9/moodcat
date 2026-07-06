//
//  ActivityOption.swift
//  felix228
//
//  Created by Codex on 12.05.2026.
//

import Foundation
import SwiftData
import SwiftUI

struct EntryActivitySnapshot: Codable, Hashable, Identifiable {
    let title: String
    let symbolName: String

    var id: String {
        "\(symbolName)-\(title)"
    }
}

@Model
final class ActivityOption {
    var syncID: String?
    var createdAt: Date
    var title: String
    var symbolName: String
    var lookupKey: String

    init(
        syncID: String? = UUID().uuidString,
        createdAt: Date = .now,
        title: String,
        symbolName: String
    ) {
        self.syncID = syncID
        self.createdAt = createdAt
        self.title = title
        self.symbolName = symbolName
        self.lookupKey = ActivityOption.makeLookupKey(title)
    }

    static func makeLookupKey(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

struct ActivityTemplate: Identifiable, Hashable {
    let title: String
    let symbolName: String

    var id: String {
        ActivityOption.makeLookupKey(title)
    }

    static let defaultCustomSymbol = customIconChoices.first?.symbolName ?? "sparkles"

    static let customIconChoices: [ActivityIconChoice] = ActivityIconCatalog.customChoices

    static let defaults: [ActivityTemplate] = [
        ActivityTemplate(title: "Уборка", symbolName: "broom.fill"),
        ActivityTemplate(title: "Игры", symbolName: "gamecontroller.fill"),
        ActivityTemplate(title: "Учёба", symbolName: "book.fill"),
        ActivityTemplate(title: "Работа", symbolName: "briefcase.fill"),
        ActivityTemplate(title: "Прогулка", symbolName: "figure.walk"),
        ActivityTemplate(title: "Спорт", symbolName: "dumbbell.fill"),
        ActivityTemplate(title: "Готовка", symbolName: "fork.knife"),
        ActivityTemplate(title: "Музыка", symbolName: "music.note"),
        ActivityTemplate(title: "Фильмы", symbolName: "tv.fill"),
        ActivityTemplate(title: "Отдых", symbolName: "moon.stars.fill"),
        ActivityTemplate(title: "Общение", symbolName: "person.2.fill"),
        ActivityTemplate(title: "Дом", symbolName: "house.fill")
    ]
}

struct ActivityIconChoice: Identifiable, Hashable {
    let title: String
    let symbolName: String

    var id: String {
        symbolName
    }
}

enum ActivityIconSource: Hashable {
    case system(String)
    case asset(String)
}

private enum ActivityIconCatalog {
    static let assetPrefix = "asset:"
    static let cleaningAssetName = "CleaningActivityIcon"
    static let bookmarkAssetName = "BookmarkActivityIcon"
    static let documentAssetName = "DocumentActivityIcon"
    static let folderAssetName = "FolderActivityIcon"
    static let homeAssetName = "HomeActivityIcon"
    static let ideaAssetName = "IdeaActivityIcon"
    static let lockAssetName = "LockActivityIcon"
    static let padlockAssetName = "PadlockActivityIcon"
    static let searchAssetName = "SearchActivityIcon"
    static let sunAssetName = "SunActivityIcon"
    static let sunAltAssetName = "SunAltActivityIcon"
    static let trashAssetName = "TrashActivityIcon"
    private static let cleaningLookupKey = ActivityOption.makeLookupKey("Уборка")

    static let customChoices: [ActivityIconChoice] = [
        ActivityIconChoice(title: "Закладка", symbolName: assetSymbolName(bookmarkAssetName)),
        ActivityIconChoice(title: "Документ", symbolName: assetSymbolName(documentAssetName)),
        ActivityIconChoice(title: "Папка", symbolName: assetSymbolName(folderAssetName)),
        ActivityIconChoice(title: "Дом", symbolName: assetSymbolName(homeAssetName)),
        ActivityIconChoice(title: "Идея", symbolName: assetSymbolName(ideaAssetName)),
        ActivityIconChoice(title: "Замок", symbolName: assetSymbolName(lockAssetName)),
        ActivityIconChoice(title: "Замочек", symbolName: assetSymbolName(padlockAssetName)),
        ActivityIconChoice(title: "Поиск", symbolName: assetSymbolName(searchAssetName)),
        ActivityIconChoice(title: "Солнце", symbolName: assetSymbolName(sunAssetName)),
        ActivityIconChoice(title: "Тепло", symbolName: assetSymbolName(sunAltAssetName)),
        ActivityIconChoice(title: "Корзина", symbolName: assetSymbolName(trashAssetName)),
        ActivityIconChoice(title: "Сердце", symbolName: "heart.fill"),
        ActivityIconChoice(title: "Звезда", symbolName: "star.fill"),
        ActivityIconChoice(title: "Огонь", symbolName: "flame.fill"),
        ActivityIconChoice(title: "Кофе", symbolName: "cup.and.saucer.fill"),
        ActivityIconChoice(title: "Покупки", symbolName: "cart.fill"),
        ActivityIconChoice(title: "Сумка", symbolName: "bag.fill"),
        ActivityIconChoice(title: "Подарок", symbolName: "gift.fill"),
        ActivityIconChoice(title: "Камера", symbolName: "camera.fill"),
        ActivityIconChoice(title: "Фото", symbolName: "photo.fill"),
        ActivityIconChoice(title: "Музыка", symbolName: "music.note"),
        ActivityIconChoice(title: "Кино", symbolName: "film.fill"),
        ActivityIconChoice(title: "Чат", symbolName: "message.fill"),
        ActivityIconChoice(title: "Люди", symbolName: "person.2.fill"),
        ActivityIconChoice(title: "Машина", symbolName: "car.fill"),
        ActivityIconChoice(title: "Путешествие", symbolName: "airplane"),
        ActivityIconChoice(title: "Велосипед", symbolName: "bicycle"),
        ActivityIconChoice(title: "Прогулка", symbolName: "figure.walk"),
        ActivityIconChoice(title: "Бег", symbolName: "figure.run"),
        ActivityIconChoice(title: "Спорт", symbolName: "dumbbell.fill"),
        ActivityIconChoice(title: "Книга", symbolName: "book.fill"),
        ActivityIconChoice(title: "Учёба", symbolName: "graduationcap.fill"),
        ActivityIconChoice(title: "Работа", symbolName: "briefcase.fill"),
        ActivityIconChoice(title: "Лампочка", symbolName: "lightbulb.fill"),
        ActivityIconChoice(title: "Рисование", symbolName: "paintbrush.fill"),
        ActivityIconChoice(title: "Письмо", symbolName: "pencil.and.outline"),
        ActivityIconChoice(title: "Телефон", symbolName: "iphone"),
        ActivityIconChoice(title: "Ноутбук", symbolName: "laptopcomputer"),
        ActivityIconChoice(title: "Игры", symbolName: "gamecontroller.fill"),
        ActivityIconChoice(title: "Отдых", symbolName: "moon.stars.fill"),
        ActivityIconChoice(title: "Еда", symbolName: "fork.knife"),
        ActivityIconChoice(title: "Лист", symbolName: "leaf.fill"),
        ActivityIconChoice(title: "Лапка", symbolName: "pawprint.fill"),
        ActivityIconChoice(title: "Искры", symbolName: "sparkles"),
    ]

    static func assetSymbolName(_ assetName: String) -> String {
        "\(assetPrefix)\(assetName)"
    }

    static func assetName(from symbolName: String) -> String? {
        guard symbolName.hasPrefix(assetPrefix) else {
            return nil
        }

        let assetName = String(symbolName.dropFirst(assetPrefix.count))
        return assetName.isEmpty ? nil : assetName
    }

    static func source(title: String?, symbolName: String) -> ActivityIconSource {
        if let assetName = assetName(from: symbolName) {
            return .asset(assetName)
        }

        let lookupKey = title.map(ActivityOption.makeLookupKey)
        if lookupKey == cleaningLookupKey || symbolName == "broom.fill" {
            return .asset(cleaningAssetName)
        }

        return .system(symbolName)
    }
}

extension ActivityOption {
    var iconSource: ActivityIconSource {
        ActivityIconCatalog.source(title: title, symbolName: symbolName)
    }
}

extension EntryActivitySnapshot {
    var iconSource: ActivityIconSource {
        ActivityIconCatalog.source(title: title, symbolName: symbolName)
    }
}

extension ActivityTemplate {
    var iconSource: ActivityIconSource {
        ActivityIconCatalog.source(title: title, symbolName: symbolName)
    }
}

struct ActivityVisualView: View {
    let iconSource: ActivityIconSource
    var size: CGFloat
    var tint: Color = .primary

    init(symbolName: String, title: String? = nil, size: CGFloat, tint: Color = .primary) {
        self.iconSource = ActivityIconCatalog.source(title: title, symbolName: symbolName)
        self.size = size
        self.tint = tint
    }

    init(activity: ActivityOption, size: CGFloat, tint: Color = .primary) {
        self.iconSource = activity.iconSource
        self.size = size
        self.tint = tint
    }

    init(snapshot: EntryActivitySnapshot, size: CGFloat, tint: Color = .primary) {
        self.iconSource = snapshot.iconSource
        self.size = size
        self.tint = tint
    }

    init(template: ActivityTemplate, size: CGFloat, tint: Color = .primary) {
        self.iconSource = template.iconSource
        self.size = size
        self.tint = tint
    }

    var body: some View {
        Group {
            switch iconSource {
            case .system(let symbolName):
                Image(systemName: symbolName)
                    .resizable()
                    .scaledToFit()
            case .asset(let assetName):
                Image(assetName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            }
        }
        .foregroundStyle(tint)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
